{{/*
Named templates for shop-api. Names and labels appear in many places; defining
them once removes the possibility of two of them disagreeing (a Service whose
selector no longer matches its pods has zero endpoints and fails silently).
*/}}

{{- define "shop-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shop-api.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "shop-api.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "shop-api.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: api
{{- end -}}

{{/*
SELECTOR labels -- deliberately a SMALL, STABLE subset.
A Deployment's selector is IMMUTABLE after creation. If the chart version were
in here, every chart bump would change the selector and the upgrade would fail
with "field is immutable".
*/}}
{{- define "shop-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shop-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "shop-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "shop-api.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "shop-api.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{/* Fail fast with a readable message instead of deploying pods that crash-loop. */}}
{{- define "shop-api.validate" -}}
{{- if not (or .Values.database.existingSecret .Values.database.url) -}}
{{- fail "\n\nshop-api: no database configured.\nSet EITHER database.existingSecret (recommended) OR database.url.\nSee values.yaml for both forms.\n" -}}
{{- end -}}
{{- end -}}
