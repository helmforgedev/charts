{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "pocket-id.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "pocket-id.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "pocket-id.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "pocket-id.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "pocket-id.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pocket-id.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "pocket-id.labels" -}}
helm.sh/chart: {{ include "pocket-id.chart" . }}
{{ include "pocket-id.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "pocket-id.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "pocket-id.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "pocket-id.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}


{{- define "pocket-id.encryptionSecretName" -}}{{- default (printf "%s-encryption" (include "pocket-id.fullname" . | trunc 52 | trimSuffix "-")) .Values.encryption.existingSecret -}}{{- end -}}
{{- define "pocket-id.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "pocket-id.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "encryption") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "pocket-id.validate" -}}
{{- if and .Values.metrics.enabled (eq (int .Values.metrics.port) (int .Values.server.port)) -}}{{ fail "Native metrics and HTTP require separate ports" }}{{- end -}}
{{- if and (not .Values.metrics.enabled) (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) -}}{{ fail "Monitoring resources require metrics.enabled" }}{{- end -}}
{{- if and .Values.postgresql.enabled (ne .Values.database.type "postgresql") -}}{{ fail "Bundled PostgreSQL requires database.type=postgresql" }}{{- end -}}
{{- if and .Values.postgresql.enabled (or .Values.database.host .Values.database.passwordSecret) -}}{{ fail "Bundled PostgreSQL and external database components are mutually exclusive" }}{{- end -}}
{{- if and (eq .Values.database.type "postgresql") (not .Values.postgresql.enabled) (not (and .Values.database.host .Values.database.passwordSecret)) -}}{{ fail "External PostgreSQL requires database.host and database.passwordSecret" }}{{- end -}}
{{- if and (eq .Values.database.type "sqlite") (or .Values.database.host .Values.database.passwordSecret .Values.database.caSecret .Values.database.sslMode) -}}{{ fail "SQLite cannot use external PostgreSQL connection settings" }}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Pocket ID requires exactly one replica even with PostgreSQL" }}{{- end -}}
{{- if and .Values.encryption.key .Values.encryption.existingSecret -}}{{ fail "encryption.key and encryption.existingSecret are mutually exclusive" }}{{- end -}}
{{- if not (hasPrefix "https://" .Values.server.publicUrl) -}}{{ fail "Pocket ID public URL must use HTTPS for passkeys" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if has .name (list "APP_ENV" "APP_URL" "HOST" "PORT" "ACTORS_HOST" "ENCRYPTION_KEY" "ENCRYPTION_KEY_FILE" "DB_CONNECTION_STRING" "DB_CONNECTION_STRING_FILE" "ALLOW_INSECURE_CALLBACK_URLS" "DISABLE_RATE_LIMITING" "ALLOW_DOWNGRADE" "ANALYTICS_DISABLED" "VERSION_CHECK_DISABLED" "LOG_JSON" "LOG_QUERY_ARGS" "FILE_BACKEND" "UPLOAD_PATH" "GEOLITE_DB_PATH" "TRUST_PROXY" "OTEL_LOGS_EXPORTER" "OTEL_TRACES_EXPORTER" "OTEL_METRICS_EXPORTER" "OTEL_EXPORTER_PROMETHEUS_HOST" "OTEL_EXPORTER_PROMETHEUS_PORT") -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key, $value := $labels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail (printf "Labels cannot override selector %s" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}
{{- define "pocket-id.nativeEnvironment" -}}
- {name: APP_ENV, value: production}
- {name: APP_URL, value: {{ .Values.server.publicUrl | quote }}}
- {name: HOST, value: "0.0.0.0"}
- {name: PORT, value: {{ .Values.server.port | quote }}}
- {name: ACTORS_HOST, value: "127.0.0.1"}
- {name: ENCRYPTION_KEY_FILE, value: /encryption/encryption-key}
{{- if eq .Values.database.type "postgresql" }}
- {name: DB_CONNECTION_STRING_FILE, value: /database-runtime/url}
{{- else }}
- {name: DB_CONNECTION_STRING, value: 'file:/app/data/pocket-id.db'}
{{- end }}
- {name: FILE_BACKEND, value: filesystem}
- {name: UPLOAD_PATH, value: /app/data/uploads}
- {name: GEOLITE_DB_PATH, value: /app/data/GeoLite2-City.mmdb}
- {name: ALLOW_INSECURE_CALLBACK_URLS, value: 'false'}
- {name: DISABLE_RATE_LIMITING, value: 'false'}
- {name: ALLOW_DOWNGRADE, value: 'false'}
- {name: ANALYTICS_DISABLED, value: 'true'}
- {name: VERSION_CHECK_DISABLED, value: 'true'}
- {name: LOG_JSON, value: 'true'}
- {name: LOG_QUERY_ARGS, value: 'false'}
- {name: TRUST_PROXY, value: {{ .Values.server.trustedProxies | quote }}}
- {name: OTEL_LOGS_EXPORTER, value: none}
- {name: OTEL_TRACES_EXPORTER, value: none}
- {name: OTEL_METRICS_EXPORTER, value: {{ ternary "prometheus" "none" .Values.metrics.enabled | quote }}}
{{- if .Values.metrics.enabled }}
- {name: OTEL_EXPORTER_PROMETHEUS_HOST, value: '0.0.0.0'}
- {name: OTEL_EXPORTER_PROMETHEUS_PORT, value: {{ .Values.metrics.port | quote }}}
{{- end }}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "pocket-id.mounts" -}}
- {name: workspace, mountPath: /app/data}
- {name: tmp, mountPath: /tmp}
- {name: encryption, mountPath: /encryption, readOnly: true}
{{- if eq .Values.database.type "postgresql" }}
- {name: database-runtime, mountPath: /database-runtime, readOnly: true}
{{- if .Values.database.caSecret }}
- {name: database-ca, mountPath: /database-ca, readOnly: true}
{{- end }}{{- end }}
{{- end -}}

{{- define "pocket-id.claimName" -}}{{- default (include "pocket-id.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}

{{- define "pocket-id.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "pocket-id.databasePort" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.service.port }}{{- else -}}{{ .Values.database.port }}{{- end -}}{{- end -}}
{{- define "pocket-id.databaseName" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.database.name }}{{- end -}}{{- end -}}
{{- define "pocket-id.databaseUser" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.database.username }}{{- end -}}{{- end -}}
{{- define "pocket-id.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "pocket-id.databasePasswordKey" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{- else -}}{{ .Values.database.passwordKey }}{{- end -}}{{- end -}}
{{- define "pocket-id.sslMode" -}}{{- .Values.database.sslMode | default (ternary "disable" "verify-full" .Values.postgresql.enabled) -}}{{- end -}}
{{- define "pocket-id.databaseEnvironment" -}}
- {name: PGHOST, value: {{ include "pocket-id.databaseHost" . | quote }}}
- {name: PGPORT, value: {{ include "pocket-id.databasePort" . | quote }}}
- {name: PGDATABASE, value: {{ include "pocket-id.databaseName" . | quote }}}
- {name: PGUSER, value: {{ include "pocket-id.databaseUser" . | quote }}}
- {name: PGSSLMODE, value: {{ include "pocket-id.sslMode" . | quote }}}
- {name: PGCONNECT_TIMEOUT, value: "5"}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "pocket-id.databasePasswordSecret" . }}, key: {{ include "pocket-id.databasePasswordKey" . }}}
{{- if .Values.database.caSecret }}
- {name: PGSSLROOTCERT, value: /database-ca/ca.crt}
{{- end }}
{{- end -}}

{{- define "pocket-id.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "pocket-id.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "pocket-id.fullname" .root }}{{- end -}}
{{- end -}}
