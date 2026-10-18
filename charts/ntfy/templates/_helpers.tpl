{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ntfy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Validate chart values before rendering resources. */}}
{{- define "ntfy.validate" -}}
{{- if include "ntfy.databaseEnabled" . -}}
  {{- if and (not .Values.postgresql.enabled) (not .Values.ntfy.database.existingSecret) (not .Values.ntfy.database.external.host) -}}
    {{- fail "PostgreSQL is enabled but neither postgresql.enabled, ntfy.database.existingSecret, nor ntfy.database.external.host is configured" -}}
  {{- end -}}
  {{- if and .Values.postgresql.enabled (empty .Values.postgresql.auth.password) (empty .Values.postgresql.auth.existingSecret) -}}
    {{- fail "postgresql.enabled=true requires postgresql.auth.password or postgresql.auth.existingSecret so ntfy can construct the database connection" -}}
  {{- end -}}
  {{- if and (eq .Values.ntfy.database.mode "postgresql") (not .Values.postgresql.enabled) (not .Values.ntfy.database.existingSecret) (empty .Values.ntfy.database.external.password) (empty .Values.ntfy.database.external.existingSecret) -}}
    {{- fail "External PostgreSQL requires ntfy.database.external.password or ntfy.database.external.existingSecret" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.ntfy.admin.enabled .Values.ntfy.admin.existingSecret (empty .Values.ntfy.admin.existingSecretPasswordKey) -}}
{{- fail "ntfy.admin.existingSecretPasswordKey must not be empty when ntfy.admin.existingSecret is configured" -}}
{{- end -}}
{{- if .Values.ntfy.metricsListenHttp -}}
{{- $port := mustRegexFind "[0-9]+$" .Values.ntfy.metricsListenHttp | int -}}
{{- if or (lt $port 1) (gt $port 65535) -}}
{{- fail (printf "ntfy.metricsListenHttp must end with a valid port number (1-65535), got: %s" .Values.ntfy.metricsListenHttp) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ntfy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ntfy.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ntfy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ntfy.labels" -}}
helm.sh/chart: {{ include "ntfy.chart" . }}
{{ include "ntfy.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ntfy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ntfy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ntfy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ntfy.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ntfy.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "ntfy.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Metrics port number parsed from metricsListenHttp (e.g. :9090 -> 9090) */}}
{{- define "ntfy.metricsPort" -}}
{{- if .Values.ntfy.metricsListenHttp -}}
{{- mustRegexFind "[0-9]+$" .Values.ntfy.metricsListenHttp | int -}}
{{- end -}}
{{- end -}}

{{/* Whether PostgreSQL database backend is enabled */}}
{{- define "ntfy.databaseEnabled" -}}
{{- if or .Values.postgresql.enabled (eq .Values.ntfy.database.mode "postgresql") .Values.ntfy.database.enabled -}}
true
{{- end -}}
{{- end -}}

{{/* Database host */}}
{{- define "ntfy.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.ntfy.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "ntfy.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.ntfy.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "ntfy.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "ntfy" -}}
{{- else -}}
{{- .Values.ntfy.database.external.name | default "ntfy" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "ntfy.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "ntfy" -}}
{{- else -}}
{{- .Values.ntfy.database.external.username | default "ntfy" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name containing database-url */}}
{{- define "ntfy.dbSecretName" -}}
{{- if .Values.ntfy.database.existingSecret -}}
{{- .Values.ntfy.database.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret key */}}
{{- define "ntfy.dbSecretKey" -}}
{{- if .Values.ntfy.database.existingSecret -}}
{{- .Values.ntfy.database.existingSecretKey | default "database-url" -}}
{{- else -}}
{{- "database-url" -}}
{{- end -}}
{{- end -}}

{{/* Database password */}}
{{- define "ntfy.dbPassword" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.password -}}
{{- else -}}
{{- .Values.ntfy.database.external.password -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL connection string */}}
{{- define "ntfy.databaseUrl" -}}
{{- $user := include "ntfy.dbUsername" . -}}
{{- $password := include "ntfy.dbPassword" . -}}
{{- $host := include "ntfy.dbHost" . -}}
{{- $port := include "ntfy.dbPort" . -}}
{{- $db := include "ntfy.dbName" . -}}
{{- printf "postgres://%s:%s@%s:%s/%s?sslmode=disable" (urlquery $user) (urlquery $password) $host $port $db -}}
{{- end -}}

{{/* Whether initial admin bootstrap is enabled */}}
{{- define "ntfy.adminEnabled" -}}
{{- if and .Values.ntfy.admin .Values.ntfy.admin.enabled -}}
true
{{- end -}}
{{- end -}}

{{/* Admin username */}}
{{- define "ntfy.adminUsername" -}}
{{- default "admin" .Values.ntfy.admin.username -}}
{{- end -}}

{{/* Admin Secret Name */}}
{{- define "ntfy.adminSecretName" -}}
{{- if .Values.ntfy.admin.existingSecret -}}
{{- .Values.ntfy.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Admin Secret Password Key */}}
{{- define "ntfy.adminSecretPasswordKey" -}}
{{- if .Values.ntfy.admin.existingSecret -}}
{{- .Values.ntfy.admin.existingSecretPasswordKey -}}
{{- else -}}
password
{{- end -}}
{{- end -}}
