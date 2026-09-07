{{/*
The container environment, shared by the Deployment and the seed Job so the
two can never drift apart.

The interesting part is how the password is handled when using an existing
Secret. We do NOT interpolate it in the template -- that would put it in the
rendered manifest, readable via `helm get manifest`. Instead:

  1. DB_PASSWORD is pulled from the Secret by reference
  2. DATABASE_URL uses $(DB_PASSWORD), which KUBELET expands at container start

Kubernetes expands $(VAR) in an env value if VAR is defined EARLIER in the same
list -- so the order of these two entries is load-bearing. The password only
ever exists inside the running container.
*/}}
{{- define "shop-api.env" -}}
{{- if .Values.database.existingSecret }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.existingSecret }}
      key: {{ .Values.database.existingSecretKey }}
- name: DATABASE_URL
  value: {{ printf "postgresql+psycopg://%s:$(DB_PASSWORD)@%s:%v/%s" .Values.database.user .Values.database.host .Values.database.port .Values.database.name | quote }}
{{- else }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-db" (include "shop-api.fullname" .) }}
      key: DATABASE_URL
{{- end }}
- name: AUTO_CREATE_TABLES
  value: {{ .Values.database.autoCreateTables | quote }}
- name: CORS_ORIGINS
  value: {{ .Values.corsOrigins | quote }}
{{- range $k, $v := .Values.env }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- end -}}
