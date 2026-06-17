# Helm — Part 02: Chart Structure — What Every File Does

**20-minute read. Understand the anatomy of a Helm chart so you can read and modify any chart you encounter.**

---

## Creating a Chart Skeleton

```bash
helm create vault-app
```

This generates:
```
vault-app/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests/
│       └── test-connection.yaml
└── .helmignore
```

The generated chart deploys nginx by default — it's a working example you edit for your app.

---

## Chart.yaml — Chart Metadata

```yaml
# Chart.yaml
apiVersion: v2

name: vault-app
description: A Helm chart for the Vault password manager application

type: application     # or "library" (library charts contain only helper templates, not deployable)

# Version of THIS CHART (increment when templates or defaults change)
version: 1.4.2

# Version of the APPLICATION being deployed (informational, shown in helm list)
appVersion: "2.1.0"

# Optional metadata
home: https://github.com/sanketika/vault-app
sources:
  - https://github.com/sanketika/vault-app
keywords:
  - vault
  - passwords
  - security

maintainers:
  - name: Shashank
    email: shashank@sanketika.in

annotations:
  # Custom key-value pairs (used by some tooling)
  category: Application

# Chart dependencies (sub-charts)
dependencies:
  - name: postgresql
    version: "13.4.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled    # values.yaml: postgresql: enabled: true/false
    alias: postgres                  # use 'postgres' instead of 'postgresql' in values

  - name: common
    version: "2.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    tags:
      - vault-common                 # enable/disable by tag in values
```

### Versioning Rules

- Increment `version` whenever you change the chart (templates, defaults, structure)
- Increment `appVersion` when the application you're packaging releases a new version
- Use semver: MAJOR.MINOR.PATCH
  - PATCH: bug fixes, typo corrections in templates
  - MINOR: new optional features, new values with defaults
  - MAJOR: breaking changes to values (removes or renames existing values)

---

## values.yaml — The Default Configuration

`values.yaml` is the contract between the chart maintainer and the user. Every configurable aspect of the chart should have a default here.

```yaml
# values.yaml

# Number of replicas
replicaCount: 1

# Container image
image:
  repository: ghcr.io/sanketika/vault-app
  tag: ""                        # empty = use appVersion from Chart.yaml
  pullPolicy: IfNotPresent       # IfNotPresent | Always | Never

imagePullSecrets: []

# Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 3000               # port the container listens on

# Ingress
ingress:
  enabled: false                 # disabled by default — user opts in
  className: "nginx"
  annotations: {}
  hosts:
    - host: vault.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Resource requests and limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Horizontal Pod Autoscaler
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

# Pod scheduling
nodeSelector: {}
tolerations: []
affinity: {}

# Environment variables for the app
env:
  LOG_LEVEL: info
  PORT: "3000"

# External secrets reference
externalSecret:
  enabled: false
  secretName: vault-app-secrets    # existing K8s Secret to mount

# Liveness and readiness probes
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

# ServiceAccount
serviceAccount:
  create: true
  annotations: {}
  name: ""

# PostgreSQL dependency configuration
postgresql:
  enabled: true
  auth:
    username: vaultadmin
    database: vault
    existingSecret: ""           # use existing secret instead of auto-generated
  primary:
    persistence:
      size: 10Gi
```

**Best practices for values.yaml:**
- Always provide sensible defaults — the chart should work with `helm install vault-app .` with no overrides
- Nest related values (image.repository, image.tag) not flat (imageRepository, imageTag)
- Use `enabled: false` for optional components rather than leaving them out
- Document non-obvious values with comments

---

## templates/ — Kubernetes Manifest Templates

### _helpers.tpl — Reusable Template Snippets

Files starting with `_` are not rendered as Kubernetes resources — they define named template functions:

```yaml
# templates/_helpers.tpl

{{/*
Expand the name of the chart.
*/}}
{{- define "vault-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncate to 63 chars (Kubernetes label limit).
*/}}
{{- define "vault-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels — applied to every resource for consistency
*/}}
{{- define "vault-app.labels" -}}
helm.sh/chart: {{ include "vault-app.chart" . }}
{{ include "vault-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used in spec.selector.matchLabels and pod template labels
These MUST be stable across upgrades (changing breaks deployments)
*/}}
{{- define "vault-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vault-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Usage in templates:
```yaml
# In deployment.yaml:
metadata:
  name: {{ include "vault-app.fullname" . }}
  labels:
    {{- include "vault-app.labels" . | nindent 4 }}
```

### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "vault-app.fullname" . }}
  labels:
    {{- include "vault-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "vault-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "vault-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "vault-app.serviceAccountName" . }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### templates/NOTES.txt

Printed to the terminal after `helm install` / `helm upgrade`. Write useful post-install instructions:

```
# templates/NOTES.txt
Thank you for installing {{ .Chart.Name }} v{{ .Chart.AppVersion }}.

Release name: {{ .Release.Name }}
Namespace: {{ .Release.Namespace }}

{{- if .Values.ingress.enabled }}
Access the application at:
{{- range .Values.ingress.hosts }}
  https://{{ .host }}
{{- end }}
{{- else }}
To access the application, run:
  kubectl port-forward svc/{{ include "vault-app.fullname" . }} 8080:{{ .Values.service.port }} -n {{ .Release.Namespace }}
  Then open: http://localhost:8080
{{- end }}

To check the deployment status:
  helm status {{ .Release.Name }} -n {{ .Release.Namespace }}
  kubectl get pods -n {{ .Release.Namespace }} -l app.kubernetes.io/instance={{ .Release.Name }}
```

---

## Hooks — Run Jobs at Lifecycle Points

Hooks run Jobs (or other resources) at specific points in the Helm lifecycle.

```yaml
# templates/db-migrate-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "vault-app.fullname" . }}-db-migrate
  annotations:
    "helm.sh/hook": pre-upgrade,pre-install     # run BEFORE install/upgrade
    "helm.sh/hook-weight": "-5"                 # lower weight = runs first
    "helm.sh/hook-delete-policy": hook-succeeded  # delete job after it succeeds
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          command: ["npm", "run", "db:migrate"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: vault-app-secrets
                  key: database-url
```

Hook types:
- `pre-install` — before any resources are created on first install
- `post-install` — after all resources are created on first install
- `pre-upgrade` — before upgrade resources are applied
- `post-upgrade` — after upgrade is complete
- `pre-rollback` — before rollback
- `post-rollback` — after rollback
- `pre-delete` — before uninstall
- `post-delete` — after uninstall

Hook delete policies (`helm.sh/hook-delete-policy`):
- `hook-succeeded` — delete when hook succeeds
- `hook-failed` — delete when hook fails
- `before-hook-creation` — delete old hook before running new one (default)

---

## tests/ — Chart Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "vault-app.fullname" . }}-test-connection"
  annotations:
    "helm.sh/hook": test                         # this is a test hook
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['--spider', 'http://{{ include "vault-app.fullname" . }}:{{ .Values.service.port }}/health']
```

```bash
# Run the tests
helm test vault-app --namespace production

# Output:
# NAME: vault-app
# LAST DEPLOYED: Mon Jun 15 10:30:00 2026
# NAMESPACE: production
# STATUS: deployed
# REVISION: 5
# TEST SUITE:   vault-app-test-connection
# Last Started: Mon Jun 15 10:31:00 2026
# Last Completed: Mon Jun 15 10:31:05 2026
# Phase: Succeeded
```

Tests run inside the cluster — they test the actual running release, not template rendering.

---

## .helmignore

Like `.gitignore` but for chart packaging:

```
# .helmignore
.git/
.gitignore
*.md
values.*.yaml          # don't bundle environment-specific values in the chart
tests/
ci/
```

---

## Real-World Scenario: Reading a Third-Party Chart

When using `bitnami/postgresql` or `ingress-nginx`, you need to understand the chart structure to configure it properly.

```bash
# 1. Pull the chart to inspect it
helm pull bitnami/postgresql --untar
ls postgresql/
# Chart.yaml  values.yaml  templates/  charts/  README.md

# 2. Read values.yaml to understand all options
less postgresql/values.yaml
# Search for: auth, persistence, primary, replication

# 3. Look at a specific section
grep -A 20 "^auth:" postgresql/values.yaml

# 4. Override only what you need in your values:
# values.production.yaml
postgresql:
  auth:
    username: vaultadmin
    database: vault
    existingSecret: vault-postgres-secret   # use your own K8s Secret
  primary:
    persistence:
      size: 50Gi
      storageClass: "gp3"
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2
      memory: 2Gi
```

---

## Common Misunderstanding: "Changing values.yaml changes the deployed release"

**The misunderstanding:** "I edited `values.yaml` in the chart directory — the cluster is now updated."

**The reality:** Editing a file on disk has zero effect on the cluster until you run `helm upgrade`. Helm doesn't watch the filesystem.

The workflow is always:
1. Edit values.yaml (or your override file)
2. `helm upgrade vault-app ./vault-app/ --values values.yaml`

This trips up teams who edit the chart repo expecting it to auto-sync. That's ArgoCD's job — it watches a git repo and runs `helm upgrade` when changes are detected. Raw Helm is purely imperative.

→ Continue to: `03-values-and-templating.md`
