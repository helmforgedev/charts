{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "twenty.cacheHost" -}}{{- if .Values.redis.enabled -}}{{ include "redis.clientServiceName" .Subcharts.redis }}{{- else -}}{{ .Values.cache.host }}{{- end -}}{{- end -}}
{{- define "twenty.cachePasswordSecret" -}}{{- if .Values.redis.enabled -}}{{ include "redis.secretName" .Subcharts.redis }}{{- else -}}{{ .Values.cache.passwordSecret }}{{- end -}}{{- end -}}
{{- define "twenty.environment" -}}
- {name: NODE_ENV, value: production}
- {name: HOME, value: /tmp}
- {name: SERVER_URL, value: {{ include "twenty.publicUrl" . | quote }}}
- {name: FRONTEND_URL, value: {{ include "twenty.publicUrl" . | quote }}}
- {name: HF_DATABASE_HOST, value: {{ include "twenty.databaseHost" . | quote }}}
- {name: HF_DATABASE_PORT, value: {{ ternary (get (.Values.postgresql.service | default dict) "port" | default 5432) .Values.database.port .Values.postgresql.enabled | quote }}}
- {name: HF_DATABASE_NAME, value: {{ ternary .Values.postgresql.auth.database .Values.database.name .Values.postgresql.enabled | quote }}}
- {name: HF_DATABASE_USERNAME, value: {{ ternary .Values.postgresql.auth.username .Values.database.username .Values.postgresql.enabled | quote }}}
- {name: HF_DATABASE_TLS, value: {{ and (not .Values.postgresql.enabled) .Values.database.tls.enabled | quote }}}
- name: HF_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "twenty.databasePasswordSecret" . }}
      key: {{ ternary .Values.postgresql.auth.existingSecretUserPasswordKey .Values.database.passwordKey .Values.postgresql.enabled }}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: HF_DATABASE_CA, value: /postgres-ca/ca.crt}
{{- end }}
- {name: HF_REDIS_HOST, value: {{ include "twenty.cacheHost" . | quote }}}
- {name: HF_REDIS_PORT, value: {{ ternary (get (get (.Values.redis.service | default dict) "ports" | default dict) "redis" | default 6379) .Values.cache.port .Values.redis.enabled | quote }}}
- {name: HF_REDIS_USERNAME, value: {{ ternary "" .Values.cache.username .Values.redis.enabled | quote }}}
- {name: HF_REDIS_DATABASE, value: {{ .Values.cache.database | quote }}}
- {name: HF_REDIS_TLS, value: {{ and (not .Values.redis.enabled) .Values.cache.tls.enabled | quote }}}
- name: HF_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "twenty.cachePasswordSecret" . }}
      key: {{ ternary .Values.redis.auth.existingSecretPasswordKey .Values.cache.passwordKey .Values.redis.enabled }}
{{- range $key := list "ENCRYPTION_KEY" "SERVER_ID" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef: {name: {{ include "twenty.identitySecretName" $ }}, key: {{ $key }}}
{{- end }}

- {name: HF_STORAGE_DRIVER, value: {{ .Values.storage.driver | quote }}}
- {name: HF_METRICS_ENABLED, value: {{ .Values.metrics.enabled | quote }}}
- {name: HF_SMTP_ENABLED, value: {{ .Values.smtp.enabled | quote }}}
{{- if and (not .Values.redis.enabled) .Values.cache.tls.caSecret }}
- {name: HF_REDIS_CA, value: /redis-ca/ca.crt}
{{- end }}
{{- if eq .Values.storage.driver "s3" }}
- {name: STORAGE_S3_NAME, value: {{ .Values.storage.s3.bucket | quote }}}
- {name: STORAGE_S3_REGION, value: {{ .Values.storage.s3.region | quote }}}
{{- if .Values.storage.s3.endpoint }}
- {name: STORAGE_S3_ENDPOINT, value: {{ .Values.storage.s3.endpoint | quote }}}
{{- end }}
- name: STORAGE_S3_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret }}, key: {{ .Values.storage.s3.accessKeyIdKey }}}
- name: STORAGE_S3_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret }}, key: {{ .Values.storage.s3.secretAccessKeyKey }}}
{{- if .Values.storage.s3.caSecret }}
- {name: HF_S3_CA, value: /s3-ca/ca.crt}
{{- end }}
{{- end }}
{{- if .Values.smtp.enabled }}
- {name: HF_SMTP_HOST, value: {{ .Values.smtp.host | quote }}}
- {name: EMAIL_FROM_ADDRESS, value: {{ .Values.smtp.from | quote }}}
- {name: EMAIL_FROM_NAME, value: Twenty}
- {name: EMAIL_SMTP_USER, value: {{ .Values.smtp.username | quote }}}
- name: EMAIL_SMTP_PASSWORD
  valueFrom:
    secretKeyRef: {name: {{ .Values.smtp.existingSecret }}, key: {{ .Values.smtp.passwordKey }}}
{{- if .Values.smtp.tls.caSecret }}
- {name: HF_SMTP_CA, value: /smtp-ca/ca.crt}
{{- end }}
{{- end }}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "twenty.mounts" -}}
{{- if and (not .Values.redis.enabled) .Values.cache.tls.caSecret }}
- {name: redis-ca, mountPath: /redis-ca, readOnly: true}
{{- end }}
{{- if and (eq .Values.storage.driver "s3") .Values.storage.s3.caSecret }}
- {name: s3-ca, mountPath: /s3-ca, readOnly: true}
{{- end }}
{{- if and .Values.smtp.enabled .Values.smtp.tls.caSecret }}
- {name: smtp-ca, mountPath: /smtp-ca, readOnly: true}
{{- end }}

- {name: data, mountPath: /app/data}
- {name: tmp, mountPath: /tmp}
- {name: runtime, mountPath: /helmforge, readOnly: true}
- {name: front, mountPath: /app/packages/twenty-server/dist/front/index.html, subPath: index.html}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: postgres-ca, mountPath: /postgres-ca, readOnly: true}
{{- end }}
{{- end -}}
{{- define "twenty.validate" -}}
{{- if and .Values.smtp.enabled (ne (int .Values.smtp.port) 465) -}}{{ fail "Native SMTP requires implicit TLS on port 465" }}{{- end -}}
{{- if and .Values.metrics.enabled (or (ne (int .Values.metrics.port) 9464) (not .Values.metrics.ingressFrom)) -}}{{ fail "Native server metrics require port 9464 and explicit scrape peers" }}{{- end -}}
{{- if ne (int .Values.server.port) 3000 -}}{{ fail "The public proxy uses fixed port 3000; configure service.port for exposure" }}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Twenty requires one replica with serialized migrations and shared local storage" }}{{- end -}}
{{- if not (and .Values.networkPolicy.enabled .Values.networkPolicy.egressIsolation) -}}{{ fail "Private native enrollment requires enforcing network isolation" }}{{- end -}}
{{- if not .Values.persistence.enabled -}}{{ fail "Twenty requires retained local storage and identity" }}{{- end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled -}}{{ fail "Select Ingress or Gateway API exposure" }}{{- end -}}
{{- if and .Values.postgresql.enabled (or .Values.database.host .Values.database.passwordSecret .Values.database.tls.caSecret) -}}{{ fail "Bundled and external PostgreSQL settings conflict" }}{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not (and .Values.database.host .Values.database.passwordSecret)) -}}{{ fail "External PostgreSQL requires host and password Secret" }}{{- end -}}
{{- if and .Values.postgresql.enabled (or (ne .Values.postgresql.architecture "standalone") .Values.postgresql.tls.enabled) -}}{{ fail "Bundled PostgreSQL requires standalone topology; use external mode for TLS" }}{{- end -}}
{{- if and .Values.redis.enabled (or (not .Values.redis.auth.enabled) (ne .Values.redis.architecture "standalone") .Values.cache.host .Values.cache.passwordSecret) -}}{{ fail "Bundled Redis requires authenticated standalone topology without external settings" }}{{- end -}}
{{- if and (not .Values.redis.enabled) (not (and .Values.cache.host .Values.cache.passwordSecret)) -}}{{ fail "External Redis requires hostname and password Secret" }}{{- end -}}
{{- if and .Values.redis.enabled .Values.redis.tls.enabled -}}{{ fail "Use external Redis mode for native TLS connections" }}{{- end -}}
{{- if and .Values.redis.enabled (ne (int (get (get (.Values.redis.service | default dict) "ports" | default dict) "redis" | default 6379)) 6379) -}}{{ fail "Bundled Redis 2.0.1 requires port 6379 for its native probes; use external Redis for custom ports" }}{{- end -}}
{{- if and .Values.cache.tls.caSecret (not .Values.cache.tls.enabled) -}}{{ fail "Redis CA requires TLS enabled" }}{{- end -}}
{{- if and .Values.database.tls.caSecret (not .Values.database.tls.enabled) -}}{{ fail "PostgreSQL CA requires TLS enabled" }}{{- end -}}
{{- if and .Values.smtp.enabled (not (and .Values.smtp.host .Values.smtp.from .Values.smtp.username .Values.smtp.existingSecret)) -}}{{ fail "SMTP requires hostname, sender address, username and password Secret" }}{{- end -}}
{{- if and (not .Values.smtp.enabled) (or .Values.smtp.host .Values.smtp.existingSecret .Values.smtp.tls.caSecret) -}}{{ fail "SMTP settings require smtp.enabled" }}{{- end -}}
{{- if and (eq .Values.storage.driver "s3") (not (and .Values.storage.s3.bucket .Values.storage.s3.existingSecret)) -}}{{ fail "S3 requires a bucket and credentials Secret" }}{{- end -}}
{{- if and (eq .Values.storage.driver "local") (or .Values.storage.s3.bucket .Values.storage.s3.endpoint .Values.storage.s3.existingSecret .Values.storage.s3.caSecret) -}}{{ fail "S3 settings require storage.driver=s3" }}{{- end -}}
{{- if and (not .Values.metrics.enabled) (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) -}}{{ fail "Prometheus resources require metrics.enabled" }}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/managed-by" "helm.sh/chart" -}}{{- if hasKey $labels $key -}}{{ fail (printf "Label %s cannot replace chart ownership" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- range .Values.extraEnv -}}{{- if regexMatch "^(EMAIL_|SMTP_|METER_|METRICS_|OTEL_|OTLP_|AWS_|TELEMETRY_|PG_|REDIS_|ENCRYPTION_|FALLBACK_|SERVER_|FRONTEND_|NODE_|HF_|AUTH_|IS_|SIGN_IN_|STORAGE_|DISABLE_|APP_SECRET|HOME$)" .name -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "twenty.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "twenty.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "twenty.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "twenty.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "twenty.selectorLabels" -}}
app.kubernetes.io/name: {{ include "twenty.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "twenty.labels" -}}
helm.sh/chart: {{ include "twenty.chart" . }}
{{ include "twenty.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "twenty.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "twenty.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "twenty.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}




{{- define "twenty.claimName" -}}{{- default (include "twenty.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "twenty.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "twenty.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "twenty.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "twenty.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "bootstrap") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "twenty.httpRouteName" -}}{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "twenty.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "twenty.fullname" .root }}{{- end -}}{{- end -}}
{{- define "twenty.publicUrl" -}}{{- default (printf "http://%s.%s.svc:%v" (include "twenty.fullname" .) .Release.Namespace .Values.service.port) .Values.server.publicUrl -}}{{- end -}}
{{- define "twenty.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "twenty.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "twenty.identitySecretName" -}}{{ default (printf "%s-identity" (include "twenty.fullname" . | trunc 53 | trimSuffix "-")) .Values.identity.existingSecret }}{{- end -}}
