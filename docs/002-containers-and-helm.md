# 002 — Containers, Postgres and the Helm chart

## What we are doing

Packaging both halves of the app into container images and writing one Helm
chart that deploys them to EKS.

### Artifacts

| Path | What it is |
|---|---|
| `development/back-end/Dockerfile` | `python:3.12-slim`, non-root uid 10001, uvicorn on `0.0.0.0:8000` |
| `development/front-end/Dockerfile` | 2 stages: `node:22-alpine` builds → `nginx-unprivileged` serves |
| `development/front-end/nginx.conf.template` | SPA fallback + reverse proxy of `/api` to the backend |
| `automation/helmcharts/postgresql/` | **Vendored** Bitnami chart 18.9.0 (PostgreSQL 18.6) |
| `automation/helmcharts/shop-api/` | Backend chart: Deployment, Service, HPA, PDB, seed Job |
| `automation/helmcharts/shop-web/` | Frontend chart: Deployment, Service, Ingress |
| `automation/helmcharts/values/*.yaml` | Per-environment values (minikube today, EKS next) |
| `automation/deploy-minikube.sh` | Builds images + installs all three releases in order |
| `automation/test/smoke-test.sh` | Exercises all 24 endpoints through nginx |

### Three charts, not one

Each of the three pieces is its own Helm release:

```
shop-db    ->  automation/helmcharts/postgresql   (vendored, third-party)
shop-api   ->  automation/helmcharts/shop-api     (ours)
shop-web   ->  automation/helmcharts/shop-web     (ours)
```

**Why separate rather than one umbrella chart:** with a single chart, shipping a
CSS fix means a `helm upgrade` that also re-evaluates the API's Deployment and
the database's StatefulSet. Separate releases mean independent version numbers,
independent rollbacks (`helm rollback shop-web` touches nothing else), and a
database whose lifecycle is not tied to an application deploy at all.

**What separation costs:** the coupling becomes explicit and must be configured
rather than inferred.

| Consumer | Needs to know | Set via |
|---|---|---|
| `shop-api` | the DB host + the Secret holding its password | `database.host`, `database.existingSecret` |
| `shop-web` | the API's Service address | `backend.url` |

Get `backend.url` wrong and the failure is distinctive: the UI loads perfectly
and then every request returns **502**, because the HTML comes from nginx but
the data does not.

**Why the Postgres chart is vendored** (`helm pull bitnami/postgresql --untar`)
rather than declared as a dependency: the chart is committed, so the exact
templates that were tested are the ones that deploy — a repo re-tagged
upstream cannot change your deployment. This matters more than usual here,
because in August 2025 Bitnami moved every *versioned* image tag to a
`bitnamilegacy/` repository, leaving only `latest` freely pullable. Vendoring
does not protect you from that (the image still comes from Docker Hub) but it
does mean the chart itself is yours.

### Deployment order, and why it is not arbitrary

```
1. shop-db   -- creates Secret/shop-db-postgresql (key: password)
2. shop-api  -- reads that Secret; its readiness probe checks the DB
3. shop-web  -- proxies to the shop-api Service
```

The API *would* eventually recover if started first — that is exactly what the
readiness probe is for — but starting Postgres first means it comes up Ready
immediately instead of flapping.

### How the pieces talk

```
browser ──▶ port-forward / Ingress ──▶ shop-web (nginx :8080)
                                          │  location /api/  proxy_pass ${BACKEND_URL}
                                          ▼
                                      shop-api (uvicorn :8000)
                                          │  DATABASE_URL
                                          ▼
                                      shop-db-postgresql:5432
```

The frontend calls `/api/products` — a **relative** URL. Consequences:

1. No backend hostname is baked into the frontend image, so the *same* image
   runs on minikube, in staging and in production.
2. The browser only ever sees one origin, so CORS never applies to normal
   traffic.

`BACKEND_URL` reaches nginx from `shop-web`'s values and `envsubst` substitutes
it into the config at container start.

### Keeping the password out of the manifest

`shop-api` never receives the password as a template value. Instead
(`templates/_env.tpl`):

```yaml
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: shop-db-postgresql, key: password }
- name: DATABASE_URL
  value: "postgresql+psycopg://shop_user:$(DB_PASSWORD)@shop-db-postgresql:5432/shop_db"
```

Kubernetes expands `$(VAR)` in an env value if `VAR` is defined **earlier in
the same list** — so the order of those two entries is load-bearing. The
password exists only inside the running container, never in `helm get manifest`.

### Local database setup

Postgres runs on the host, so create a dedicated role and database rather than
using the `postgres` superuser:

```bash
sudo -u postgres psql <<'SQL'
CREATE USER shop_user WITH PASSWORD 'shop_pass';
CREATE DATABASE shop_db OWNER shop_user;
GRANT ALL PRIVILEGES ON DATABASE shop_db TO shop_user;
SQL
```

Then in `development/back-end/.env`:

```
DATABASE_URL=postgresql+psycopg://shop_user:shop_pass@localhost:5432/shop_db
```

### Deploy to minikube

One command:

```bash
./automation/deploy-minikube.sh
```

Or step by step, which is worth doing once to see what the script does:

```bash
# Build the images INSIDE minikube's own Docker daemon. This removes the need
# for a registry entirely -- the image is already where kubelet looks for it.
# Only works with the docker driver: check `minikube profile list`.
eval $(minikube docker-env)
docker build -t shop-api:1.0.1 development/back-end
docker build -t shop-web:1.0.0 development/front-end

kubectl create namespace shop

helm upgrade --install shop-db  automation/helmcharts/postgresql -n shop \
  -f automation/helmcharts/values/postgresql-minikube.yaml --wait
helm upgrade --install shop-api automation/helmcharts/shop-api   -n shop \
  -f automation/helmcharts/values/shop-api-minikube.yaml --wait
helm upgrade --install shop-web automation/helmcharts/shop-web   -n shop \
  -f automation/helmcharts/values/shop-web-minikube.yaml --wait

kubectl port-forward -n shop svc/shop-web 8080:80   # http://localhost:8080
./automation/test/smoke-test.sh shop                # all 24 endpoints
```

Note `pullPolicy: IfNotPresent` in the minikube values files. The images exist
in the node's daemon but in **no registry**, so `Always` would fail with
`ErrImagePull`.

### Build and push (for EKS)

```bash
export REGISTRY=docker.io/<your-username>   # or the ECR registry URL
export TAG=1.0.1

docker build -t $REGISTRY/shop-api:$TAG development/back-end
docker build -t $REGISTRY/shop-web:$TAG development/front-end

docker login                                 # Docker Hub
# or, for ECR:
# aws ecr get-login-password --region ap-south-1 \
#   | docker login --username AWS --password-stdin $REGISTRY

docker push $REGISTRY/shop-api:$TAG
docker push $REGISTRY/shop-web:$TAG
```

Then set `image.repository=$REGISTRY/shop-api` in an EKS values file.

**Architecture gotcha:** if you build on an Apple Silicon Mac and deploy to
`amd64` EKS nodes, the pods fail with `exec format error`. Build explicitly:
`docker buildx build --platform linux/amd64 -t ... --push .`

### Deploy to EKS

```bash
# Do NOT deploy the postgresql chart. Use RDS.
kubectl create namespace shop
kubectl create secret generic shop-db -n shop \
  --from-literal=password='<the RDS password>'

helm upgrade --install shop-api automation/helmcharts/shop-api -n shop \
  --set image.repository=$REGISTRY/shop-api --set image.tag=$TAG \
  --set database.existingSecret=shop-db \
  --set database.host=shop.xxxx.ap-south-1.rds.amazonaws.com \
  --set database.autoCreateTables=false \
  --set ingress.enabled=true --set ingress.className=alb \
  --set ingress.host=shop.yourdomain.com

helm upgrade --install shop-web automation/helmcharts/shop-web -n shop \
  --set image.repository=$REGISTRY/shop-web --set image.tag=$TAG \
  --set backend.url=http://shop-api:8000 \
  --set ingress.enabled=true --set ingress.className=alb \
  --set ingress.host=shop.yourdomain.com
```

Both charts can define an Ingress for the **same host** with different paths
(`/api` and `/`); the controller merges them and matches the most specific
first.

Always render and read the YAML before installing — five seconds, catches most
mistakes:

```bash
helm lint automation/helmcharts/shop-api
helm template shop-api automation/helmcharts/shop-api --set database.existingSecret=shop-db
```

### Production checklist

- [ ] Postgres on **RDS**, not in a pod. A database in a pod loses its data
      when the pod is rescheduled.
- [ ] `database.autoCreateTables=false` and run Alembic migrations as a Job.
      `create_all()` only ever *adds* tables — it will never apply a column
      change, and N pods racing to `CREATE TABLE` is a real deploy failure.
- [ ] `database.existingSecret` from AWS Secrets Manager (Secrets Store CSI
      driver or External Secrets), never `database.url` in a values file.
- [ ] Immutable image tags (`1.0.3`, or the git SHA). Never `latest`.
- [ ] TLS via ACM certificate ARN in the Ingress annotations.
- [ ] `api.autoscaling.enabled=true` (needs metrics-server installed).

---

## Concepts / KT

**Image vs container** — an image is a read-only filesystem snapshot plus a
default command. A container is one running instance of it. Images are built
once and run anywhere; containers are disposable.

**Layers and the build cache** — every `COPY` and `RUN` creates a layer. Docker
reuses cached layers until the first one whose inputs changed, then rebuilds
everything after it. That is the whole reason both Dockerfiles copy the
dependency manifest and install *before* copying source code: editing a line of
Python must not re-run `pip install`.

**Multi-stage build** — `FROM ... AS build` then a second `FROM`. Only what you
explicitly `COPY --from=build` survives. The frontend needs Node and ~200MB of
`node_modules` to compile, and none of it to serve — the final image is 74MB of
nginx and static files, with no Node and no source code.

**`-slim` / `-alpine` tags** — minimal base images. Smaller means faster pod
starts (less to pull) and fewer installed packages that could carry a CVE.

**`PYTHONUNBUFFERED=1`** — without it, Python buffers stdout and `kubectl logs`
shows nothing until the buffer flushes or the pod dies. One line, hours saved.

**`--host 0.0.0.0`** — inside a container, `127.0.0.1` means "reachable from
this container only". Bind to `0.0.0.0` or Kubernetes can never reach your app
and every request times out. The single most common containerisation mistake.

**Non-root containers** — by default a container's root *is* root on the host
kernel. Running as uid 10001 with `capabilities: drop [ALL]` and
`readOnlyRootFilesystem` limits what a compromised process can do. EKS Pod
Security Standards ("restricted") will reject root containers outright.

**`npm ci` vs `npm install`** — `ci` installs exactly what `package-lock.json`
pins and fails if the lock file disagrees with `package.json`. `install` may
quietly upgrade, which is how a build that passed yesterday breaks today.

**Pod** — one or more containers scheduled together, sharing a network
namespace. The smallest thing Kubernetes runs.

**Deployment** — declares "I want N pods of this image" and reconciles reality
towards it. It also owns the rolling-update behaviour.

**Rolling update with `maxUnavailable: 0, maxSurge: 1`** — add one new pod,
wait for it to pass readiness, then retire one old pod. Capacity never dips, so
the deploy has no downtime.

**Service** — a stable DNS name and virtual IP in front of a changing set of
pods. Pods come and go with new IPs; the Service name does not. It finds its
pods by **label**, not by name — if the selector stops matching the pod labels,
the Service has zero endpoints and every request fails with nothing in the logs
to explain why.

**Ingress** — HTTP routing from outside the cluster. The object is generic; the
annotations are provider-specific. On EKS the AWS Load Balancer Controller
reads it and provisions a real ALB.

**ClusterIP** — internal-only Service. Both Services here are ClusterIP: the
Ingress is the single public door.

**Probes** — `startupProbe` ("has it booted?", pauses liveness meanwhile),
`livenessProbe` ("is it wedged?", failure **restarts** the pod),
`readinessProbe` ("send traffic?", failure only removes it from the Service).
Getting these backwards — checking the DB in liveness — turns a recoverable
database blip into a cluster-wide crash loop.

**Requests vs limits** — *requests* are what the scheduler reserves and uses to
pick a node; *limits* are the hard ceiling. Exceeding a CPU limit throttles the
process; exceeding a **memory** limit OOM-kills it. Pods with no requests are
"BestEffort" and are the first evicted when a node runs short.

**HPA** — the Horizontal Pod Autoscaler adds and removes pods based on metrics.
Note it targets a percentage of the CPU *request*, not the limit, and needs
metrics-server installed or it reports `<unknown>` and never acts.

**PodDisruptionBudget** — protects against *voluntary* disruption: node drains,
cluster upgrades, the autoscaler consolidating nodes. `minAvailable: 1` makes
Kubernetes wait rather than evicting your last pod during routine maintenance.

**Secret** — base64-**encoded**, not encrypted. Anyone with
`kubectl get secret -o yaml` in the namespace reads the password instantly. For
real environments, source it from AWS Secrets Manager.

**Why a Secret change does not restart pods** — it does not, and that is the
point of the `checksum/db-secret` annotation on the pod template: it changes
when the Secret changes, which changes the template, which triggers a normal
rolling restart. Standard Helm idiom.

**Helm chart / values / release** — the *chart* is the templates (the shape),
*values* are what differs per environment, and a *release* is one installed
instance. `helm template` renders locally so you can read the YAML before it
reaches the cluster.

**Named templates (`_helpers.tpl`)** — names and labels appear in dozens of
places across the templates. Defining them once removes the possibility of two
of them disagreeing.

**Immutable selectors** — a Deployment's `selector` cannot be changed after
creation. That is why `shop.selectorLabels` is a small stable subset and the
chart version lives only in `shop.labels`: otherwise every chart bump would
fail the upgrade with "field is immutable".

**Helm hooks** — the seed Job is annotated `post-install,post-upgrade`, so Helm
runs it after the app is up and waits for it to succeed. A failed seed fails the
release loudly, instead of leaving you an empty database and a green checkmark.

**`envsubst` at container start** — the nginx image expands `${BACKEND_URL}` in
`/etc/nginx/templates/*.template` when it boots. This is how one image adapts
to any environment without a rebuild.

**SPA fallback (`try_files $uri /index.html`)** — React Router handles `/orders`
in the browser, but a page *refresh* asks nginx for a file called `/orders`,
which does not exist. Without this line you get a 404 on every refresh of every
route but `/`. It is the most commonly missed line when deploying an SPA.

**StatefulSet vs Deployment** — the Postgres chart uses a StatefulSet because a
database pod must come back with the *same* identity (`shop-db-postgresql-0`)
and the *same* volume. A Deployment gives you interchangeable pods, which is
right for the API and wrong for the database.

**PersistentVolumeClaim** — a request for storage that outlives the pod. On
minikube the default `standard` StorageClass writes into a directory inside the
minikube VM: it survives `kubectl delete pod` and `minikube stop`, but **not**
`minikube delete`. Verified in `docs/003`.

**Vendoring a chart** — `helm pull <chart> --untar` commits the chart into your
repo, so the exact templates you tested are the ones that deploy. The
alternative (a `dependencies:` entry in `Chart.yaml`) re-downloads at build
time, which means an upstream change can alter your deployment without a commit
on your side.

**`$(VAR)` expansion in env** — Kubernetes substitutes `$(OTHER_VAR)` inside an
env value, provided `OTHER_VAR` appears *earlier in the same list*. That is how
`shop-api` assembles `DATABASE_URL` around a password it only ever holds by
Secret reference. Order matters; get it wrong and the literal string
`$(DB_PASSWORD)` ends up in the connection URL.

**Mutable vs immutable tags** — rebuilding `shop-api:1.0.0` with new code does
**not** redeploy anything: the pod template is unchanged, so Helm correctly
sees no diff. Either bump the tag (`1.0.1` — what we did) or force it with
`kubectl rollout restart`. This is the single most confusing part of a first
Kubernetes deploy: your fix is built, the release says "deployed", and the old
code is still running.
