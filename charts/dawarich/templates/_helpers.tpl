{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "dawarich.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "dawarich.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "dawarich.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "dawarich.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "dawarich.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dawarich.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "dawarich.labels" -}}
helm.sh/chart: {{ include "dawarich.chart" . }}
{{ include "dawarich.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "dawarich.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "dawarich.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "dawarich.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}




{{- define "dawarich.claimName" -}}{{- default (include "dawarich.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "dawarich.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "dawarich.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "dawarich.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "dawarich.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "bootstrap") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "dawarich.httpRouteName" -}}{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "dawarich.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "dawarich.fullname" .root }}{{- end -}}{{- end -}}
{{- define "dawarich.publicUrl" -}}{{- default (printf "http://%s.%s.svc:%v" (include "dawarich.fullname" .) .Release.Namespace .Values.service.port) .Values.server.publicUrl -}}{{- end -}}
{{- define "dawarich.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "dawarich.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "dawarich.cacheHost" -}}{{- if .Values.redis.enabled -}}{{ include "redis.clientServiceName" .Subcharts.redis }}{{- else -}}{{ .Values.cache.host }}{{- end -}}{{- end -}}
{{- define "dawarich.cachePasswordSecret" -}}{{- if .Values.redis.enabled -}}{{ include "redis.secretName" .Subcharts.redis }}{{- else -}}{{ .Values.cache.passwordSecret }}{{- end -}}{{- end -}}
{{- define "dawarich.identitySecretName" -}}{{ default (printf "%s-identity" (include "dawarich.fullname" . | trunc 53 | trimSuffix "-")) .Values.identity.existingSecret }}{{- end -}}
{{- define "dawarich.validate" -}}
{{- if lt (int .Values.runtime.threads) (int .Values.worker.concurrency) -}}{{ fail "runtime.threads must cover worker.concurrency for the native database pool" }}{{- end -}}
{{- if eq .Values.storage.s3.accessKeyIdKey .Values.storage.s3.secretAccessKeyKey -}}{{ fail "S3 access and secret keys must use distinct Secret keys" }}{{- end -}}
{{- if and (eq .Values.storage.driver "s3") (not (and .Values.storage.s3.bucket .Values.storage.s3.existingSecret)) -}}{{ fail "Native S3 requires a bucket and credential Secret" }}{{- end -}}
{{- if and (eq .Values.storage.driver "local") (or .Values.storage.s3.bucket .Values.storage.s3.endpoint .Values.storage.s3.existingSecret .Values.storage.s3.caSecret) -}}{{ fail "S3 settings require storage.driver=s3" }}{{- end -}}
{{- if and (not .Values.metrics.enabled) (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) -}}{{ fail "Native monitors require metrics.enabled" }}{{- end -}}
{{- if or (eq (int .Values.metrics.port) 3010) (eq (int .Values.metrics.port) 9394) (eq (int .Values.metrics.port) (int .Values.server.port)) -}}{{ fail "Metrics proxy port must differ from public, native web and worker ports" }}{{- end -}}
{{- if eq .Values.metrics.auth.usernameKey .Values.metrics.auth.passwordKey -}}{{ fail "Metrics username and password require distinct Secret keys" }}{{- end -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.tls.enabled -}}{{ fail "Bundled PostGIS TLS is not supported; use external PostGIS with verified TLS" }}{{- end -}}
{{- if and .Values.redis.enabled .Values.redis.tls.enabled -}}{{ fail "Bundled Redis TLS is not supported; use external Redis with verified TLS" }}{{- end -}}
{{- if and .Values.database.tls.caSecret (not .Values.database.tls.enabled) -}}{{ fail "PostGIS CA configuration requires TLS enabled" }}{{- end -}}
{{- if and .Values.cache.tls.caSecret (not .Values.cache.tls.enabled) -}}{{ fail "Redis CA configuration requires TLS enabled" }}{{- end -}}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.enabled (not .Values.database.tls.caSecret) -}}{{ fail "External PostGIS TLS requires an explicit CA Secret for libpq verify-full" }}{{- end -}}
{{- if and .Values.postgresql.enabled (or .Values.database.host .Values.database.passwordSecret .Values.database.tls.caSecret) -}}{{ fail "Bundled and external PostGIS settings are mutually exclusive" }}{{- end -}}
{{- if and .Values.redis.enabled (or .Values.cache.host .Values.cache.passwordSecret .Values.cache.tls.caSecret) -}}{{ fail "Bundled and external Redis settings are mutually exclusive" }}{{- end -}}
{{- if and .Values.bootstrap.password .Values.bootstrap.existingSecret -}}{{ fail "Bootstrap password and existing Secret are mutually exclusive" }}{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail "Pod labels cannot replace chart workload selectors" }}{{- end -}}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (regexMatch "^PG[A-Z_]" .name) (has .name (list "HOME" "TMPDIR" "SCHEMA" "DATA_SCHEMA" "SSL_CERT_FILE" "SSL_CERT_DIR" "STORAGE_BACKEND" "NODE_OPTIONS" "GEM_HOME")) -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Dawarich local shared storage requires one co-located web/worker replica" }}{{- end -}}
{{- if not .Values.persistence.enabled -}}{{ fail "Dawarich requires persistent imports and attachment storage" }}{{- end -}}
{{- if and .Values.postgresql.enabled (ne .Values.postgresql.architecture "standalone") -}}{{ fail "Bundled PostGIS currently requires standalone topology" }}{{- end -}}
{{- if and .Values.redis.enabled (or (not .Values.redis.auth.enabled) (ne .Values.redis.architecture "standalone")) -}}{{ fail "Dawarich requires authenticated standalone Redis with logical databases" }}{{- end -}}
{{- if eq (int .Values.cache.database) (int .Values.cache.queueDatabase) -}}{{ fail "Dawarich cache and job queues require distinct logical databases" }}{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not (and .Values.database.host .Values.database.passwordSecret)) -}}{{ fail "External PostGIS requires host and passwordSecret" }}{{- end -}}
{{- if and (not .Values.redis.enabled) (not (and .Values.cache.host .Values.cache.passwordSecret)) -}}{{ fail "External Redis requires host and passwordSecret" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if regexMatch "^(AWS_|DATABASE_|REDIS_|RAILS_|SECRET_|OTP_|APPLICATION_|HF_|BUNDLE_|SELF_HOSTED|SIDEKIQ_METRICS_URL|ALLOW_|OIDC_|PROMETHEUS_|METRICS_)" .name -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "dawarich.environment" -}}
- {name: RAILS_ENV, value: production}
- {name: HOME, value: /tmp}
- {name: TMPDIR, value: /tmp/dawarich}
- {name: RAILS_LOG_TO_STDOUT, value: "true"}
- {name: SCHEMA, value: /tmp/schema.rb}
- {name: DATA_SCHEMA, value: /tmp/data_schema.rb}
- {name: SELF_HOSTED, value: "true"}
- {name: STORAGE_BACKEND, value: {{ .Values.storage.driver | quote }}}
{{- if eq .Values.storage.driver "s3" }}
- {name: AWS_REGION, value: {{ .Values.storage.s3.region | quote }}}
- {name: AWS_BUCKET, value: {{ .Values.storage.s3.bucket | quote }}}
- {name: AWS_EC2_METADATA_DISABLED, value: "true"}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret }}, key: {{ .Values.storage.s3.accessKeyIdKey }}}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret }}, key: {{ .Values.storage.s3.secretAccessKeyKey }}}
{{- if .Values.storage.s3.endpoint }}
- {name: AWS_ENDPOINT_URL, value: {{ .Values.storage.s3.endpoint | quote }}}
{{- end }}
{{- if .Values.storage.s3.caSecret }}
- {name: AWS_CA_BUNDLE, value: /s3-ca/ca.crt}
{{- end }}
{{- end }}
- {name: PROMETHEUS_EXPORTER_ENABLED, value: {{ .Values.metrics.enabled | quote }}}
{{- if .Values.metrics.enabled }}
- {name: SIDEKIQ_METRICS_URL, value: "http://127.0.0.1:9394/metrics"}
- {name: PROMETHEUS_EXPORTER_PORT, value: "9394"}
- name: METRICS_USERNAME
  valueFrom:
    secretKeyRef: {name: {{ include "dawarich.metricsSecretName" . }}, key: {{ .Values.metrics.auth.usernameKey }}}
- name: METRICS_PASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "dawarich.metricsSecretName" . }}, key: {{ .Values.metrics.auth.passwordKey }}}
{{- end }}
- {name: ALLOW_EMAIL_PASSWORD_REGISTRATION, value: "false"}
- {name: OIDC_AUTO_REGISTER, value: "false"}
- {name: APPLICATION_HOSTS, value: {{ (urlParse (include "dawarich.publicUrl" .)).host | quote }}}
- {name: APPLICATION_PROTOCOL, value: {{ (urlParse (include "dawarich.publicUrl" .)).scheme | quote }}}
- {name: TIME_ZONE, value: {{ .Values.server.timeZone | quote }}}
- {name: WEB_CONCURRENCY, value: "0"}
- {name: RAILS_MAX_THREADS, value: {{ .Values.runtime.threads | quote }}}
- {name: BACKGROUND_PROCESSING_CONCURRENCY, value: {{ .Values.worker.concurrency | quote }}}
- {name: RAILS_CACHE_DB, value: {{ .Values.cache.database | quote }}}
- {name: RAILS_JOB_QUEUE_DB, value: {{ .Values.cache.queueDatabase | quote }}}
- {name: DATABASE_HOST, value: {{ include "dawarich.databaseHost" . | quote }}}
- {name: DATABASE_PORT, value: {{ ternary (get (.Values.postgresql.service | default dict) "port" | default 5432) .Values.database.port .Values.postgresql.enabled | quote }}}
- {name: DATABASE_NAME, value: {{ ternary .Values.postgresql.auth.database .Values.database.name .Values.postgresql.enabled | quote }}}
- {name: DATABASE_USERNAME, value: {{ ternary .Values.postgresql.auth.username .Values.database.username .Values.postgresql.enabled | quote }}}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "dawarich.databasePasswordSecret" . }}, key: {{ ternary .Values.postgresql.auth.existingSecretUserPasswordKey .Values.database.passwordKey .Values.postgresql.enabled }}}
- {name: PGSSLMODE, value: {{ ternary "verify-full" "disable" (and (not .Values.postgresql.enabled) .Values.database.tls.enabled) | quote }}}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: PGSSLROOTCERT, value: /postgres-ca/ca.crt}
{{- end }}
- {name: HF_REDIS_HOST, value: {{ include "dawarich.cacheHost" . | quote }}}
- {name: HF_REDIS_PORT, value: {{ ternary (get (get (.Values.redis.service | default dict) "ports" | default dict) "redis" | default 6379) .Values.cache.port .Values.redis.enabled | quote }}}
- {name: HF_REDIS_USERNAME, value: {{ .Values.cache.username | quote }}}
- {name: HF_REDIS_TLS, value: {{ and (not .Values.redis.enabled) .Values.cache.tls.enabled | quote }}}
- name: HF_REDIS_PASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "dawarich.cachePasswordSecret" . }}, key: {{ ternary .Values.redis.auth.existingSecretPasswordKey .Values.cache.passwordKey .Values.redis.enabled }}}
{{- if and (not .Values.redis.enabled) .Values.cache.tls.caSecret }}
- {name: HF_REDIS_CA, value: /redis-ca/ca.crt}
- {name: SSL_CERT_FILE, value: /tmp/helmforge-ca-bundle.pem}
{{- end }}
{{- range $key := list "SECRET_KEY_BASE" "OTP_ENCRYPTION_PRIMARY_KEY" "OTP_ENCRYPTION_DETERMINISTIC_KEY" "OTP_ENCRYPTION_KEY_DERIVATION_SALT" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef: {name: {{ include "dawarich.identitySecretName" $ }}, key: {{ $key }}}
{{- end }}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "dawarich.mounts" -}}
{{- if and (eq .Values.storage.driver "s3") .Values.storage.s3.caSecret }}
- {name: s3-ca, mountPath: /s3-ca, readOnly: true}
{{- end }}
- {name: workspace, mountPath: /workspace}
- {name: workspace, mountPath: /var/app/storage, subPath: storage}
- {name: workspace, mountPath: /var/app/public, subPath: public}
- {name: app-tmp, mountPath: /var/app/tmp}
- {name: workspace, mountPath: /var/app/tmp/imports, subPath: imports}
- {name: tmp, mountPath: /tmp}
- {name: log, mountPath: /var/app/log}
- {name: runtime, mountPath: /helmforge, readOnly: true}
- {name: runtime, mountPath: /var/app/config/initializers/helmforge-registration.rb, subPath: registration-policy.rb, readOnly: true}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: postgres-ca, mountPath: /postgres-ca, readOnly: true}
{{- end }}
{{- if and (not .Values.redis.enabled) .Values.cache.tls.caSecret }}
- {name: redis-ca, mountPath: /redis-ca, readOnly: true}
{{- end }}
{{- end -}}

{{- define "dawarich.metricsSecretName" -}}{{ default (printf "%s-metrics-auth" (include "dawarich.fullname" . | trunc 50 | trimSuffix "-")) .Values.metrics.auth.existingSecret }}{{- end -}}
