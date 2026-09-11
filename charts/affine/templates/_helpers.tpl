{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "affine.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "affine.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "affine.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "affine.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "affine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "affine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "affine.labels" -}}
helm.sh/chart: {{ include "affine.chart" . }}
{{ include "affine.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "affine.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "affine.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "affine.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}




{{- define "affine.claimName" -}}{{- default (include "affine.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "affine.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "affine.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "affine.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "affine.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "bootstrap") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "affine.httpRouteName" -}}{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "affine.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "affine.fullname" .root }}{{- end -}}{{- end -}}
{{- define "affine.publicUrl" -}}{{- default (printf "http://%s.%s.svc:%v" (include "affine.fullname" .) .Release.Namespace .Values.service.port) .Values.server.publicUrl -}}{{- end -}}
{{- define "affine.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "affine.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "affine.cacheHost" -}}{{- if .Values.redis.enabled -}}{{ include "redis.clientServiceName" .Subcharts.redis }}{{- else -}}{{ .Values.cache.host }}{{- end -}}{{- end -}}
{{- define "affine.cachePasswordSecret" -}}{{- if .Values.redis.enabled -}}{{ include "redis.secretName" .Subcharts.redis }}{{- else -}}{{ .Values.cache.passwordSecret }}{{- end -}}{{- end -}}
{{- define "affine.validate" -}}
{{- range $key, $_ := .Values.podLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail "podLabels cannot override workload selectors" }}{{- end -}}{{- end -}}
{{- if and .Values.database.tls.caSecret (not .Values.database.tls.enabled) -}}{{ fail "A PostgreSQL CA requires database.tls.enabled" }}{{- end -}}
{{- if and .Values.cache.tls.caSecret (not .Values.cache.tls.enabled) -}}{{ fail "A Redis CA requires cache.tls.enabled" }}{{- end -}}
{{- if and .Values.postgresql.enabled (get (.Values.postgresql.tls | default dict) "enabled") -}}{{ fail "Use the validated external PostgreSQL TLS mode for encrypted database connections" }}{{- end -}}
{{- if and .Values.redis.enabled (get (.Values.redis.tls | default dict) "enabled") -}}{{ fail "Use the validated external Redis TLS mode for encrypted cache connections" }}{{- end -}}
{{- if not .Values.persistence.enabled -}}{{ fail "AFFiNE requires persistent native identity keys alongside its database" }}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "AFFiNE local storage requires one replica" }}{{- end -}}
{{- if not .Values.postgresql.enabled -}}
{{- if not (and .Values.database.host .Values.database.passwordSecret .Values.database.username .Values.database.name) -}}{{ fail "External PostgreSQL requires host, database name, username and passwordSecret" }}{{- end -}}
{{- else if or .Values.database.host .Values.database.passwordSecret .Values.database.tls.caSecret -}}{{ fail "Bundled PostgreSQL and external database settings are mutually exclusive" }}{{- end -}}
{{- if not .Values.redis.enabled -}}
{{- if not (and .Values.cache.host .Values.cache.passwordSecret) -}}{{ fail "External Redis requires host and passwordSecret" }}{{- end -}}
{{- else if or .Values.cache.host .Values.cache.passwordSecret .Values.cache.tls.caSecret -}}{{ fail "Bundled Redis and external cache settings are mutually exclusive" }}{{- end -}}
{{- if and (not .Values.metrics.enabled) (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) -}}{{ fail "ServiceMonitor and PrometheusRule require metrics.enabled" }}{{- end -}}
{{- if and .Values.metrics.enabled (eq (int .Values.metrics.port) (int .Values.server.port)) -}}{{ fail "Metrics must use a separate private port" }}{{- end -}}
{{- if and .Values.redis.enabled (not .Values.redis.auth.enabled) -}}{{ fail "AFFiNE Redis requires authentication" }}{{- end -}}
{{- if and .Values.redis.enabled (ne .Values.redis.architecture "standalone") -}}{{ fail "AFFiNE requires a validated standalone Redis logical-database contract" }}{{- end -}}

{{- if and .Values.bootstrap.password .Values.bootstrap.existingSecret -}}{{ fail "Bootstrap password and existing Secret are mutually exclusive" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (regexMatch "^(PG|REDIS_|AFFINE_|HF_|OTEL_|NODE_|SERVER_|DEPLOYMENT_)" .name) (has .name (list "HOME" "DATABASE_URL" "LISTEN_ADDR")) -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "affine.environment" -}}
- {name: HOME, value: /home/node}
- {name: HF_POSTGRES_TLS, value: {{ and (not .Values.postgresql.enabled) .Values.database.tls.enabled | quote }}}
- {name: HF_REDIS_TLS, value: {{ and (not .Values.redis.enabled) .Values.cache.tls.enabled | quote }}}
- {name: HF_METRICS_ENABLED, value: {{ .Values.metrics.enabled | quote }}}
- {name: OTEL_EXPORTER_PROMETHEUS_HOST, value: "0.0.0.0"}
- {name: OTEL_EXPORTER_PROMETHEUS_PORT, value: {{ .Values.metrics.port | quote }}}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: HF_POSTGRES_CA, value: /postgres-tls/ca.crt}
{{- end }}
{{- if and (not .Values.redis.enabled) .Values.cache.tls.caSecret }}
- {name: HF_REDIS_CA, value: /redis-tls/ca.crt}
{{- end }}
- {name: XDG_CACHE_HOME, value: /tmp/cache}
- {name: AFFINE_SERVER_PORT, value: {{ .Values.server.port | quote }}}
- {name: AFFINE_SERVER_EXTERNAL_URL, value: {{ include "affine.publicUrl" . | quote }}}
- {name: PGHOST, value: {{ include "affine.databaseHost" . | quote }}}
- {name: PGPORT, value: {{ ternary (get (.Values.postgresql.service | default dict) "port" | default 5432) .Values.database.port .Values.postgresql.enabled | quote }}}
- {name: PGDATABASE, value: {{ ternary .Values.postgresql.auth.database .Values.database.name .Values.postgresql.enabled | quote }}}
- {name: PGUSER, value: {{ ternary .Values.postgresql.auth.username .Values.database.username .Values.postgresql.enabled | quote }}}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "affine.databasePasswordSecret" . }}, key: {{ ternary .Values.postgresql.auth.existingSecretUserPasswordKey .Values.database.passwordKey .Values.postgresql.enabled }}}
- {name: REDIS_SERVER_HOST, value: {{ include "affine.cacheHost" . | quote }}}
- {name: REDIS_SERVER_PORT, value: {{ ternary (get (get (.Values.redis.service | default dict) "ports" | default dict) "redis" | default 6379) .Values.cache.port .Values.redis.enabled | quote }}}
- {name: REDIS_SERVER_DATABASE, value: {{ .Values.cache.database | quote }}}
- {name: REDIS_SERVER_USERNAME, value: {{ .Values.cache.username | quote }}}
- name: REDIS_SERVER_PASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "affine.cachePasswordSecret" . }}, key: {{ ternary .Values.redis.auth.existingSecretPasswordKey .Values.cache.passwordKey .Values.redis.enabled }}}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "affine.mounts" -}}
- {name: workspace, mountPath: /home/node/.affine}
- {name: tmp, mountPath: /tmp}
- {name: generated-schema, mountPath: /app/src}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: postgres-ca, mountPath: /postgres-tls, readOnly: true}
{{- end }}
{{- if and (not .Values.redis.enabled) .Values.cache.tls.caSecret }}
- {name: redis-ca, mountPath: /redis-tls, readOnly: true}
{{- end }}
- {name: bootstrap-script, mountPath: /helmforge, readOnly: true}
{{- end -}}
