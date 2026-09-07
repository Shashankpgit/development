# 003 — Deploying to minikube, and the two bugs it found

## What we are doing

Running the full stack on minikube as three separate Helm releases, and — more
usefully — recording the two real bugs that only appeared once it ran on
Kubernetes against PostgreSQL.

### Result

```
NAME                        READY   STATUS      RESTARTS
shop-api-795f647fd8-7k2f5   1/1     Running     0
shop-api-795f647fd8-k5tmp   1/1     Running     0
shop-api-seed-w7xk8         0/1     Completed   0
shop-db-postgresql-0        1/1     Running     0
shop-web-77fdb99cdc-8v7p8   1/1     Running     0
shop-web-77fdb99cdc-dlvqq   1/1     Running     0
```

`automation/test/smoke-test.sh` — **53 checks, 0 failures**, run through the
frontend's nginx so it exercises the whole chain (nginx → API Service →
Postgres) rather than the API alone.

---

## Bug 1 — `CrashLoopBackOff`: `ModuleNotFoundError: No module named 'pydantic_settings'`

### The debugging path

The install timed out with `Error: context deadline exceeded` — which says
nothing about the cause. Three questions, in order:

**1. What does Kubernetes think the state is?**

```bash
kubectl get pods -n shop
# shop-api-75f5978458-4dxjw   0/1   CrashLoopBackOff   5 (92s ago)
```

`CrashLoopBackOff` only means "the container keeps exiting". It is a symptom,
never a cause. It does tell you the container *started*, so the image was
pulled and the node is fine.

**2. What does the process itself say?**

```bash
kubectl logs -n shop -l app.kubernetes.io/name=shop-api --tail=30
# ...
# File "/app/app/config.py", line 10, in <module>
#     from pydantic_settings import BaseSettings, SettingsConfigDict
# ModuleNotFoundError: No module named 'pydantic_settings'
```

**3. Which layer is this?** A Python *import* error, at module load, before any
socket was opened. So:

- not Kubernetes — the pod scheduled and the image ran
- not Postgres — nothing had tried to connect yet
- not the probes — there was no server to probe

It is the **image**. Nothing else can be.

### Root cause

`psycopg` and `pydantic-settings` had been installed into the local virtualenv
with `pip install`, but never added to `requirements.txt`. The venv worked; the
image — which knows only `requirements.txt` — did not.

### The lesson

**A dependency is not installed until the manifest says so.** `pip install`
changes one machine. Editing `requirements.txt` changes every machine, every
image and every teammate. The venv and the image had silently diverged.

The general rule this is an instance of: **anything not committed does not
exist.** The same failure shape appears with an env var exported in your shell
but absent from the ConfigMap, or a `/etc/hosts` entry on your laptop only.

### The fix

```diff
  fastapi==0.115.6
  uvicorn[standard]==0.34.0
  sqlalchemy==2.0.36
  pydantic[email]==2.10.4
+ pydantic-settings==2.7.0
+ psycopg[binary]==3.2.3
```

Then verify **inside the image**, before redeploying — this is the step people
skip, and it turns a 5-minute loop into a 30-second one:

```bash
docker run --rm --entrypoint python shop-api:1.0.0 \
  -c "import pydantic_settings, psycopg; from app.main import app; print('OK')"
```

### The follow-on trap

Rebuilding `shop-api:1.0.0` with the fix and running `helm upgrade` changed
nothing: the pod template was identical, so Helm correctly saw no diff and
never rolled the pods. Two ways out:

```bash
kubectl rollout restart deploy/shop-api -n shop   # force it
```

or, better, bump the tag to `1.0.1` — which is what the chart does now. **With
immutable tags this problem cannot happen.** With `latest` it happens
constantly.

---

## Bug 2 — `500` on `DELETE /api/products/{id}`: `ForeignKeyViolation`

Found by the smoke test, not by a user. This is the more interesting bug of the
two, because **SQLite would never have revealed it.**

### The debugging path

```bash
kubectl logs -n shop -l app.kubernetes.io/name=shop-api --tail=200 \
  | grep -iE 'error|violat|DETAIL'
```

```
psycopg.errors.ForeignKeyViolation: update or delete on table "products"
  violates foreign key constraint "order_items_product_id_fkey" on table "order_items"
DETAIL:  Key (id)=(10) is still referenced from table "order_items".
```

The error names the constraint, the table and the exact key. Postgres error
messages are unusually good — read them literally before theorising.

### Root cause

`delete_product` removed the product's `cart_items` but not its `order_items`
references. `order_items.product_id` was `NOT NULL` with a plain foreign key, so
Postgres refused the delete.

**Why this had passed before:** SQLite **does not enforce foreign keys unless
you explicitly turn them on** (`PRAGMA foreign_keys = ON`, off by default). The
same code against SQLite deletes the product and leaves `order_items` rows
pointing at a row that no longer exists — silent data corruption instead of a
loud 500.

### The lesson

**Develop against the engine you deploy on.** "It works on my machine" is
frequently "my machine enforces fewer rules than production does". A 500 in a
smoke test is a far better outcome than orphaned rows nobody notices for a
month.

### The fix

The documented design intent (`docs/api/orders.md`) is that order history
survives product deletion — which is exactly why `order_items` copies
`product_name` and `unit_price` at purchase time. So the reference should be
allowed to go null rather than block the delete:

```python
product_id: Mapped[int | None] = mapped_column(
    ForeignKey("products.id", ondelete="SET NULL"), nullable=True
)
```

### And here is where `create_all()` betrayed us

Changing the model was not enough. `Base.metadata.create_all()` only ever
issues `CREATE TABLE IF NOT EXISTS` — the table already existed, so **nothing
happened**. `create_all` adds tables; it never alters one.

The change had to be applied as a migration would:

```sql
ALTER TABLE order_items ALTER COLUMN product_id DROP NOT NULL;
ALTER TABLE order_items DROP CONSTRAINT order_items_product_id_fkey;
ALTER TABLE order_items ADD CONSTRAINT order_items_product_id_fkey
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL;
```

```bash
kubectl exec -i -n shop shop-db-postgresql-0 -- \
  env PGPASSWORD=shop_pass psql -U shop_user -d shop_db < migrate.sql
```

Confirm it took (`confdeltype` = `n` means SET NULL, `a` means NO ACTION):

```bash
kubectl exec -i -n shop shop-db-postgresql-0 -- env PGPASSWORD=shop_pass \
  psql -U shop_user -d shop_db -Atc \
  "SELECT conname, confdeltype FROM pg_constraint WHERE conname='order_items_product_id_fkey';"
# order_items_product_id_fkey|n
```

**This is the concrete argument for Alembic**, and why the production checklist
sets `database.autoCreateTables=false`. Hand-written `ALTER` against a live
database is fine once, on a laptop, with demo data. It does not survive
contact with three environments and a rollback.

Verified afterwards — history intact, reference cleared:

```
 id | product_id |      product_name       | unit_price | quantity
----+------------+-------------------------+------------+----------
  1 |            | Smoke Widget            |      24.99 |        2
```

---

## Bug 3 (in the test, not the app) — a test that only passed once

The second run of the smoke test failed 25 checks. Not a regression: the first
run's cleanup had failed (because of bug 2), so `Smoke Test Gear` still existed
and `POST /api/categories` returned `409`. Every later check that needed that
id then requested `/api/categories/` with an empty id — hence a wave of
misleading `307` redirects.

**The lesson: a test that only passes on an empty database is not a test you can
trust.** Fixed by stamping every created record with `$(date +%s)`, so each run
uses fresh names. The script now passes repeatedly with no manual cleanup.

Also worth noting: the `307`s were a *symptom* of empty variables, not a routing
bug. When a wave of tests fails at once, look for the first failure and the
shared input — not for a wave of causes.

---

## Verifying the things we claimed

Two design decisions were asserted in `docs/002`. Both were tested rather than
assumed.

### The PVC really persists

```bash
kubectl exec ... -Atc "SELECT count(*) FROM products;"   # 9
kubectl delete pod shop-db-postgresql-0 -n shop
kubectl wait --for=condition=ready pod/shop-db-postgresql-0 -n shop
kubectl exec ... -Atc "SELECT count(*) FROM products;"   # 9
```

The StatefulSet recreated the pod with the same name and reattached the same
PersistentVolumeClaim.

### Liveness vs readiness really matters

After destroying the database pod:

```
NAME                        READY   RESTARTS
shop-api-795f647fd8-7k2f5   true    0
shop-api-795f647fd8-k5tmp   true    0
```

**Zero restarts.** The API pods went *unready* while Postgres was gone — so the
Service stopped sending them traffic — and recovered by themselves when it came
back. Had `livenessProbe` pointed at `/health/ready` (the endpoint that checks
the database) instead of `/health`, both pods would have been killed and
restarted repeatedly, turning a 40-second database restart into a much longer
application outage.

This is the payoff for a distinction that looks like pedantry on paper.

---

## Concepts / KT

**`CrashLoopBackOff`** — the container keeps exiting, so Kubernetes restarts it
with growing delays (10s, 20s, 40s…). It is a *symptom*. The cause is always in
`kubectl logs`. If the container never started at all you would see
`ImagePullBackOff` or `CreateContainerError` instead — a useful distinction,
because it tells you whether to look at your image or at your code.

**`--previous`** — a crashed container's logs are gone once it restarts. Use
`kubectl logs <pod> --previous` to read the *last dead* container. Essential
when a pod is restarting faster than you can type.

**`Error: context deadline exceeded`** — Helm's `--wait` gave up. It says only
that something did not become Ready in time; it never says what. Always follow
it with `kubectl get pods`.

**`kubectl exec -i`** — without `-i`, stdin is not forwarded, so a heredoc
piped into `psql` silently does nothing and exits 0. (This cost one confusing
round trip during the migration above.)

**`eval $(minikube docker-env)`** — repoints your local `docker` CLI at the
Docker daemon *inside* the minikube node. Images you build then already exist
where kubelet looks, so no registry, no push, no pull. Only works with the
`docker` driver, and only in the shell where you ran it.

**`imagePullPolicy: IfNotPresent`** — mandatory for minikube-local images. The
image exists in the node's daemon but in no registry, so `Always` fails with
`ErrImagePull`. Inverted for `latest` against a real registry, where `Always`
is the only safe choice.

**`ondelete="SET NULL"` vs `CASCADE` vs the default** — three answers to "what
happens to rows that reference this one?" The default (`NO ACTION`) refuses the
delete. `CASCADE` deletes them too — dangerous when they are invoices.
`SET NULL` keeps the row and clears the pointer, which is what a snapshot-style
history table wants.

**Foreign key enforcement is not universal** — Postgres always enforces;
MySQL/InnoDB enforces; SQLite does **not** by default. A schema is only as
strong as the engine running it.

**`create_all()` is not a migration tool** — it emits `CREATE TABLE IF NOT
EXISTS` and nothing else. It cannot add a column, change nullability, or alter
a constraint on an existing table. It is fine for a first run on an empty
database and actively misleading after that.

**Idempotent tests** — a test must pass on the second run, and while another
run is in progress. Unique names per run (a timestamp, a UUID) is the cheapest
way to get there; a full teardown that runs even on failure is the thorough way.

**Testing through the proxy, not around it** — the smoke test talks to
`svc/shop-web`, not `svc/shop-api`. A test against the API directly would have
passed even with `backend.url` misconfigured, i.e. while the actual application
was completely broken for every user. **Test the path the user takes.**
