# Helm — Part 03: Values and Go Templating

**20-minute read. Master the template language — this is where Helm gets powerful and also where most bugs come from.**

---

## How Values Are Merged

Helm merges values from multiple sources. Later sources override earlier ones:

```
1. chart/values.yaml          (defaults — lowest priority)
2. parent chart values.yaml   (if this is a sub-chart)
3. -f values.staging.yaml     (your override file)
4. -f values.extra.yaml       (second override file, if provided)
5. --set key=value            (CLI overrides — highest priority)
```

```bash
# Multiple -f files: later files override earlier ones
helm install vault-app ./vault-app/ \
  -f values.yaml \          # base: replicaCount: 1, image.tag: latest
  -f values.staging.yaml \  # staging: replicaCount: 2
  -f values.hotfix.yaml \   # hotfix: image.tag: v1.2.4-hotfix
  --set debug=true          # CLI: highest priority

# Result:
# replicaCount: 2     (from staging)
# image.tag: v1.2.4-hotfix  (from hotfix)
# debug: true         (from --set)
```

---

## `--set` Syntax — All Forms

```bash
# Simple string
--set image.tag=v1.2.3

# Nested key (use dots)
--set ingress.hosts[0].host=vault.example.com

# Array value
--set env.FEATURE_FLAGS="{flag1,flag2,flag3}"
# Becomes: env.FEATURE_FLAGS: [flag1, flag2, flag3]

# Integer (no quotes = number)
--set replicaCount=3

# Boolean
--set autoscaling.enabled=true

# Null (remove a key)
--set resources=null

# Value with commas: use \,
--set ingress.annotations."nginx\.ingress\.kubernetes\.io/proxy-body-size"=100m
# Dots in key names must be escaped with \.

# Set multiple values in one flag
--set image.tag=v1.2.3,replicaCount=3

# String that looks like a number: add quotes
--set "service.port=8080"    # with quotes: string "8080"
--set service.port=8080      # without quotes: integer 8080
# Note: for Kubernetes YAML both work, but if your template uses {{ if eq .Values.port "8080" }}, type matters
```

`--set-string` forces string type regardless of value:
```bash
--set-string image.tag=1.0    # ensures "1.0" string, not 1.0 float
```

`--set-file` reads value from a file:
```bash
--set-file "config=./config.json"   # reads config.json contents as the value
```

---

## Go Template Syntax Basics

Helm uses Go's `text/template` package. All template expressions are wrapped in `{{ }}`.

```yaml
# Basic value reference
image: {{ .Values.image.repository }}

# With default fallback (if value is empty/nil, use the default)
image: {{ .Values.image.tag | default .Chart.AppVersion }}

# Quote: always quote strings that could be numeric
tag: {{ .Values.image.tag | quote }}
# Produces: tag: "v1.2.3"   (with quotes — needed for strings in YAML)

# Integer (no quotes needed)
replicas: {{ .Values.replicaCount }}
```

### Whitespace Control

The `-` inside `{{- }}` trims whitespace (including newlines) before the expression. `{{- }}` trims before, `{{ -}}` trims after, `{{- -}}` trims both.

```yaml
# Without trimming (extra blank line):
spec:
  
  replicas: 3

# With trimming:
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
# Produces (no blank line):
spec:
  replicas: 3
```

---

## Conditionals

```yaml
# if / else if / else
{{- if .Values.ingress.enabled }}
# ingress is enabled
{{- else if .Values.service.nodePort }}
# use nodePort instead
{{- else }}
# default case
{{- end }}

# Check for non-empty string
{{- if .Values.serviceAccount.name }}
serviceAccountName: {{ .Values.serviceAccount.name }}
{{- else }}
serviceAccountName: {{ include "vault-app.fullname" . }}
{{- end }}

# Shorthand using default
serviceAccountName: {{ .Values.serviceAccount.name | default (include "vault-app.fullname" .) }}

# Check if a key exists (not nil AND not empty)
{{- if .Values.resources }}
resources:
  {{- toYaml .Values.resources | nindent 12 }}
{{- end }}
```

Falsy values in Go templates: `false`, `0`, `nil`, empty string `""`, empty slice `[]`, empty map `{}`

---

## Loops — range

```yaml
# Loop over a map (key-value pairs)
env:
  {{- range $key, $value := .Values.env }}
  - name: {{ $key }}
    value: {{ $value | quote }}
  {{- end }}

# Loop over a list
volumes:
  {{- range .Values.extraVolumes }}
  - name: {{ .name }}
    configMap:
      name: {{ .configMapName }}
  {{- end }}

# Loop with index
args:
  {{- range $i, $arg := .Values.args }}
  - {{ $arg | quote }}
  {{- end }}
```

Example values that feed the loops:
```yaml
# values.yaml
env:
  LOG_LEVEL: info
  PORT: "3000"
  NODE_ENV: production

extraVolumes:
  - name: config
    configMapName: vault-config
  - name: tls
    configMapName: vault-tls
```

---

## Essential Template Functions

### toYaml — Convert a Values Map to YAML

```yaml
# values.yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# template:
resources:
  {{- toYaml .Values.resources | nindent 12 }}
# Result:
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

`nindent N` adds N spaces of indentation to every line — critical when embedding YAML into YAML.

### include — Call a Named Template

```yaml
# Call a helper template defined in _helpers.tpl
name: {{ include "vault-app.fullname" . }}

# include returns a string, so pipe it through nindent for multi-line:
labels:
  {{- include "vault-app.labels" . | nindent 4 }}
```

`include` vs `template`:
- `include` returns the result as a string — can be piped (e.g., `| nindent 4`)
- `template` renders in-place — cannot be piped
- Always use `include` in practice

### required — Fail if Value Is Missing

```yaml
# Fail helm install/upgrade with a clear message if the user forgot to set the value
host: {{ required "ingress.hosts[0].host is required when ingress is enabled" .Values.ingress.hosts }}

# Better: only require when ingress is enabled
{{- if .Values.ingress.enabled }}
{{- if not .Values.ingress.hosts }}
{{- fail "ingress.hosts must be set when ingress.enabled is true" }}
{{- end }}
{{- end }}
```

### tpl — Render Strings as Templates

```yaml
# values.yaml
fullnameOverride: ""
namePrefix: ""
annotations:
  my-annotation: "{{ .Release.Name }}-suffix"    # this is a template string in values

# template:
annotations:
  {{- tpl (toYaml .Values.annotations) . | nindent 4 }}
# The annotation value is evaluated as a template, not a literal string
```

Use `tpl` when you want users to be able to use template syntax in their values. Use carefully — it opens up arbitrary template execution.

### Other Useful Functions

```yaml
# String operations
{{ .Values.name | upper }}            # VAULT-APP
{{ .Values.name | lower }}            # vault-app
{{ .Values.name | title }}            # Vault-App
{{ .Values.name | trimSuffix "-v2" }} # vault-app
{{ .Values.name | replace "." "-" }}  # vault-app (dots to dashes)
{{ printf "%s-%s" .Release.Name .Chart.Name }}  # vault-app-vault-app

# Truncate (Kubernetes name limit is 63 chars)
{{ .Release.Name | trunc 63 | trimSuffix "-" }}

# Type conversion
{{ .Values.port | toString }}   # integer → string
{{ .Values.port | int }}        # string → integer
{{ .Values.enabled | toString | lower }}  # bool → "true"/"false"

# Encode/decode
{{ .Values.password | b64enc }}    # base64 encode (for Secrets)
{{ .Values.encoded | b64dec }}     # base64 decode

# Indentation
{{ toYaml .Values.obj | indent 4 }}    # add 4 spaces to each line
{{ toYaml .Values.obj | nindent 4 }}   # same but adds newline at start
```

---

## with — Simplify Nested Value Access

```yaml
# Without with (verbose):
{{- if .Values.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.nodeSelector | nindent 8 }}
{{- end }}
{{- if .Values.tolerations }}
tolerations:
  {{- toYaml .Values.tolerations | nindent 8 }}
{{- end }}

# With 'with' (cleaner):
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}   # '.' inside with = .Values.nodeSelector
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

Inside a `with` block, `.` is reassigned to the value being tested. If the value is empty/nil, the block is skipped entirely.

---

## Managing Secrets in Templates

```yaml
# templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "vault-app.fullname" . }}
type: Opaque
data:
  # User provides the password in values.yaml — we base64 encode it here
  db-password: {{ .Values.database.password | b64enc | quote }}
  api-key: {{ .Values.apiKey | b64enc | quote }}
```

```yaml
# values.yaml (user sets these)
database:
  password: ""     # user must override this — set via --set or sealed-secrets

apiKey: ""
```

Better: don't put secrets in values at all. Reference an existing Kubernetes Secret:

```yaml
# values.yaml
externalSecret:
  name: vault-app-secrets      # user creates this Secret separately

# templates/deployment.yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ .Values.externalSecret.name }}
        key: db-password
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: {{ .Values.externalSecret.name }}
        key: api-key
```

---

## Real-World Scenario: Making a Chart Work for Both Staging and Production

```yaml
# values.yaml (defaults — suitable for staging)
replicaCount: 1
image:
  tag: ""
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
ingress:
  enabled: true
  hosts:
    - host: vault.staging.example.com
postgresql:
  primary:
    persistence:
      size: 10Gi

# values.production.yaml (production overrides — stored in git)
replicaCount: 3
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2
    memory: 2Gi
ingress:
  hosts:
    - host: vault.example.com
postgresql:
  primary:
    persistence:
      size: 100Gi
```

```bash
# Deploy staging:
helm upgrade --install vault-app ./vault-app/ \
  --namespace staging \
  --set image.tag=$IMAGE_TAG

# Deploy production (uses production overrides):
helm upgrade --install vault-app ./vault-app/ \
  --namespace production \
  -f values.production.yaml \
  --set image.tag=$IMAGE_TAG \
  --atomic
```

One chart, two releases, different values. The chart templates don't change between environments.

---

## Common Misunderstanding: "`--set` values survive upgrades"

**The misunderstanding:** "I set `--set image.tag=v1.2.3` on install. When I upgrade, it still uses that tag."

**The reality:** `--set` values are stored with the release, but by default, `helm upgrade` does NOT reuse them. If you run:

```bash
helm install vault-app . --set image.tag=v1.2.3
helm upgrade vault-app .          # No --set — image.tag falls back to values.yaml default!
```

The upgrade uses `values.yaml` defaults unless you explicitly:
1. Pass `--set image.tag=v1.2.3` again
2. Or pass `--reuse-values` to inherit all previous values

In CI/CD, always pass all required values explicitly on every `helm upgrade`. Never rely on `--reuse-values` in automated pipelines — it hides what the deploy actually used and makes runs non-reproducible.

→ Continue to: `04-repositories-and-oci.md`
