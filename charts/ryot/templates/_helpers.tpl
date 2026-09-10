{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ryot.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "ryot.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "ryot.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "ryot.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "ryot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ryot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "ryot.labels" -}}
helm.sh/chart: {{ include "ryot.chart" . }}
{{ include "ryot.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "ryot.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "ryot.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "ryot.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "ryot.authSecretName" -}}{{- default (printf "%s-auth" (include "ryot.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "ryot.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "ryot.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "ryot.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "ryot.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "ryot.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "ryot.databasePort" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.service.port }}{{- else -}}{{ .Values.database.port }}{{- end -}}{{- end -}}
{{- define "ryot.databaseName" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.database.name }}{{- end -}}{{- end -}}
{{- define "ryot.databaseUser" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.database.username }}{{- end -}}{{- end -}}
{{- define "ryot.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "ryot.databasePasswordKey" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{- else -}}{{ .Values.database.passwordKey }}{{- end -}}{{- end -}}
{{- define "ryot.sslMode" -}}{{- .Values.database.sslMode | default (ternary "disable" "verify-full" .Values.postgresql.enabled) -}}{{- end -}}
{{- define "ryot.validate" -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Ryot requires one scheduler and Recreate upgrades" }}{{- end -}}
{{- if and .Values.postgresql.enabled (or .Values.database.host .Values.database.passwordSecret) -}}{{ fail "Bundled PostgreSQL and external components are mutually exclusive" }}{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not (and .Values.database.host .Values.database.passwordSecret)) -}}{{ fail "External PostgreSQL requires database.host and database.passwordSecret" }}{{- end -}}
{{- if and .Values.auth.adminAccessToken .Values.auth.existingSecret -}}{{ fail "auth.adminAccessToken and auth.existingSecret are mutually exclusive" }}{{- end -}}
{{- if and .Values.bootstrap.password .Values.bootstrap.existingSecret -}}{{ fail "bootstrap.password and bootstrap.existingSecret are mutually exclusive" }}{{- end -}}
{{- if and .Values.auth.adminAccessToken (lt (len .Values.auth.adminAccessToken) 32) -}}{{ fail "auth.adminAccessToken requires at least 32 characters" }}{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail "podLabels cannot override workload selectors" }}{{- end -}}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (hasPrefix "SERVER_OIDC_" .name) (hasPrefix "FILE_STORAGE_" .name) (has .name (list "DATABASE_URL" "SERVER_ADMIN_ACCESS_TOKEN" "USERS_ALLOW_REGISTRATION" "USERS_DISABLE_LOCAL_AUTH" "SERVER_BACKEND_HOST" "SERVER_BACKEND_PORT" "PORT" "FRONTEND_URL" "DISABLE_TELEMETRY" "FRONTEND_UMAMI_SCRIPT_URL" "FRONTEND_UMAMI_WEBSITE_ID")) -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "ryot.databaseEnvironment" -}}
- {name: PGHOST, value: {{ include "ryot.databaseHost" . | quote }}}
- {name: PGPORT, value: {{ include "ryot.databasePort" . | quote }}}
- {name: PGDATABASE, value: {{ include "ryot.databaseName" . | quote }}}
- {name: PGUSER, value: {{ include "ryot.databaseUser" . | quote }}}
- {name: PGSSLMODE, value: {{ include "ryot.sslMode" . | quote }}}
- {name: PGCONNECT_TIMEOUT, value: "5"}
- {name: DATABASE_CONNECTION_TIMEOUT, value: {{ .Values.database.connectionTimeout | quote }}}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef: {name: {{ include "ryot.databasePasswordSecret" . }}, key: {{ include "ryot.databasePasswordKey" . }}}
{{- if .Values.database.caSecret }}
- {name: PGSSLROOTCERT, value: /database-ca/ca.crt}
{{- end }}
{{- end -}}
{{- define "ryot.nativeEnvironment" -}}
- {name: PORT, value: {{ .Values.server.port | quote }}}
- {name: FRONTEND_URL, value: {{ .Values.server.publicUrl | quote }}}
- {name: SERVER_BACKEND_HOST, value: "127.0.0.1"}
- {name: SERVER_BACKEND_PORT, value: "5000"}
- {name: USERS_ALLOW_REGISTRATION, value: "false"}
- {name: USERS_DISABLE_LOCAL_AUTH, value: "false"}
- {name: DISABLE_TELEMETRY, value: "true"}
- {name: FRONTEND_UMAMI_SCRIPT_URL, value: ""}
- {name: FRONTEND_UMAMI_WEBSITE_ID, value: ""}
- {name: SERVER_GRAPHQL_PLAYGROUND_ENABLED, value: "false"}
- {name: FILE_STORAGE_S3_URL, value: ""}
- {name: FILE_STORAGE_S3_BUCKET_NAME, value: ""}
- {name: FILE_STORAGE_S3_ACCESS_KEY_ID, value: ""}
- {name: FILE_STORAGE_S3_SECRET_ACCESS_KEY, value: ""}
- {name: HOME, value: /runtime-home}
- {name: XDG_CONFIG_HOME, value: /runtime-home/config}
- {name: XDG_DATA_HOME, value: /runtime-home/data}
- name: SERVER_ADMIN_ACCESS_TOKEN
  valueFrom:
    secretKeyRef: {name: {{ include "ryot.authSecretName" . }}, key: {{ .Values.auth.adminAccessTokenKey }}}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "ryot.mounts" -}}
- {name: tmp, mountPath: /tmp}
- {name: backend-tmp, mountPath: /home/ryot/tmp}
- {name: home, mountPath: /runtime-home}
- {name: database-runtime, mountPath: /database-runtime, readOnly: true}
{{- if .Values.database.caSecret }}
- {name: database-ca, mountPath: /database-ca, readOnly: true}
{{- end }}
{{- end -}}
