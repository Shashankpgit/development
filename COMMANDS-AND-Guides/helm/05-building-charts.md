# Helm — Part 05: Building Your Own Charts

**20-minute read. Write a complete, production-ready Helm chart from scratch. Lint it. Test it. Package and publish it.**

---

## Starting a Chart

```bash
helm create vault-app
cd vault-app
```

The generated chart targets nginx. Replace it for your app:

```bash
# Key files to edit:
# Chart.yaml       — update name, description, version, appVersion
# values.yaml      — replace nginx-specific values with your app's config
# templates/       — replace nginx references with your app
```

---

## A Complete Real-World Chart

Let's build a chart for the vault-app (Node.js API + PostgreSQL).

### Chart.yaml

```yaml
apiVersion: v2
name: vault-app
description: Vault password manager — Node.js API
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: postgresql
    version: "13.4.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
    alias: postgres
```

### values.yaml

```yaml
replicaCount: 1

image:
  repository: ghcr.io/sanketika/vault-app
  tag: ""              # defaults to Chart.appVersion
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: vault.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

# App-specific config
config:
  logLevel: info
  jwtExpiryHours: 24

# Reference to a pre-existing Kubernetes Secret
existingSecret: ""      # set to name of a Secret containing DATABASE_URL and JWT_SECRET

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}

nodeSelector: {}
tolerations: []
affinity: {}

# PostgreSQL sub-chart
postgres:
  enabled: true
  auth:
    username: vaultadmin
    database: vault
    existingSecret: ""
  primary:
    persistence:
      size: 10Gi
```

### templates/_helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "vault-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
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
Chart label — includes version for tracking which chart version deployed this.
*/}}
{{- define "vault-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for every resource.
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
Selector labels — must be stable! Never change these.
*/}}
{{- define "vault-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vault-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "vault-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vault-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database host — uses postgresql sub-chart or external host.
*/}}
{{- define "vault-app.dbHost" -}}
{{- if .Values.postgres.enabled }}
{{- printf "%s-postgres" .Release.Name }}
{{- else }}
{{- required "database.host is required when postgres.enabled is false" .Values.database.host }}
{{- end }}
{{- end }}
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
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "vault-app.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "vault-app.serviceAccountName" . }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: vault-api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          env:
            - name: PORT
              value: {{ .Values.service.targetPort | quote }}
            - name: LOG_LEVEL
              value: {{ .Values.config.logLevel | quote }}
            - name: JWT_EXPIRY_HOURS
              value: {{ .Values.config.jwtExpiryHours | quote }}
            - name: DB_HOST
              value: {{ include "vault-app.dbHost" . }}
            {{- if .Values.existingSecret }}
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: database-url
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: jwt-secret
            {{- end }}
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### templates/ingress.yaml

```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "vault-app.fullname" . }}
  labels:
    {{- include "vault-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- toYaml .Values.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "vault-app.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
```

---

## Linting and Validating

```bash
# Basic lint
helm lint ./vault-app/

# Lint with override values (catches conditional template issues)
helm lint ./vault-app/ --values values.production.yaml

# Strict mode (warnings become errors — recommended for CI)
helm lint ./vault-app/ --strict

# Render and validate against live cluster API
helm template vault-app ./vault-app/ \
  --validate \
  --values values.production.yaml

# Dry-run against the actual cluster
helm install vault-app ./vault-app/ \
  --namespace production \
  --dry-run \
  --debug \
  --values values.production.yaml
```

---

## CI Values for Lint and Testing

When linting in CI, provide a test values file that enables all optional features:

```yaml
# ci/values.ci.yaml — enables everything so all code paths are linted
ingress:
  enabled: true
  hosts:
    - host: vault.ci.example.com
      paths:
        - path: /
          pathType: Prefix

autoscaling:
  enabled: true

existingSecret: vault-app-secrets
```

```bash
# In CI pipeline:
helm lint ./vault-app/ --strict --values ci/values.ci.yaml
```

---

## Packaging and Publishing

```bash
# Package chart into a .tgz
helm package ./vault-app/
# Creates: vault-app-1.0.0.tgz

# Package with specific output directory
helm package ./vault-app/ --destination ./dist/

# Verify the package
helm show chart ./dist/vault-app-1.0.0.tgz
helm template test ./dist/vault-app-1.0.0.tgz

# Push to OCI registry (GHCR)
helm push ./dist/vault-app-1.0.0.tgz oci://ghcr.io/sanketika/charts/

# Push to ECR
helm push ./dist/vault-app-1.0.0.tgz oci://123456789.dkr.ecr.ap-south-1.amazonaws.com/charts/

# For traditional HTTP repos — generate index.yaml for self-hosted repo
helm repo index ./dist/ --url https://charts.example.com
# Generates index.yaml from all .tgz files in ./dist/
# Upload index.yaml and .tgz files to your web server
```

---

## GitHub Actions: Publish Chart on Tag

```yaml
# .github/workflows/publish-chart.yml
name: Publish Helm Chart

on:
  push:
    tags: ['chart/v*']    # tag: chart/v1.2.3

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Helm
        uses: azure/setup-helm@v4

      - name: Lint chart
        run: helm lint ./vault-app/ --strict

      - name: Package chart
        run: helm package ./vault-app/ --destination ./dist/

      - name: Login to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | helm registry login ghcr.io \
            --username ${{ github.actor }} \
            --password-stdin

      - name: Push to GHCR
        run: helm push ./dist/vault-app-*.tgz oci://ghcr.io/${{ github.repository_owner }}/charts/
```

---

## Real-World Scenario: Versioning Strategy

```bash
# Development:
# Chart.yaml: version: 0.1.0-dev (pre-release versions)
# values.yaml: image.tag: "" (uses appVersion = branch SHA)

# Releasing app v2.0.0 with chart updates:
# 1. Update appVersion in Chart.yaml:  "2.0.0"
# 2. If chart templates changed: bump version: 0.2.0
# 3. If only appVersion changed: bump version: 0.1.1 (patch)

# Chart changelog approach: use annotations in Chart.yaml
annotations:
  artifacthub.io/changes: |
    - kind: added
      description: Added HPA support
    - kind: changed
      description: Updated default resources
    - kind: fixed
      description: Fixed ingress TLS configuration

# version: when changed             appVersion: when changed
# 0.1.0 → 0.2.0 (new feature)     1.0.0 → 2.0.0 (app major release)
# 0.2.0 → 0.2.1 (bug in template) 2.0.0 → 2.0.1 (app patch)
# 0.2.1 → 0.3.0 (new value added) (same app version)
```

---

## Common Misunderstanding: "Linting a chart means it'll work on the cluster"

**The misunderstanding:** "helm lint passed — my chart is correct."

**The reality:** `helm lint` catches:
- YAML syntax errors
- Missing required Chart.yaml fields
- Obvious template rendering errors
- Best practice violations (no resources, no probes)

`helm lint` does NOT catch:
- Wrong API versions (`apps/v1beta1` removed in Kubernetes 1.16)
- References to non-existent Secrets or ConfigMaps
- Port mismatches between service and container
- Resource requests higher than node capacity
- Ingress class names that don't exist in your cluster

For deeper validation, always use:
```bash
# Validate rendered templates against the cluster's API schemas
helm template vault-app ./vault-app/ --validate

# Or dry-run against actual cluster (most thorough)
helm install vault-app ./vault-app/ --dry-run --debug
```

`--validate` checks against the OpenAPI schema cached locally. `--dry-run` sends the manifests to the cluster API server which validates against the actual installed CRDs and admission webhooks.

→ Continue to: `06-real-world-patterns.md`
