{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ntfy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Validate chart values before rendering resources. */}}
{{- define "ntfy.validate" -}}
{{- if .Values.oidc.enabled -}}
  {{- if and (not .Values.oidc.existingSecret) (not .Values.oidc.clientSecret) -}}
    {{- fail "ntfy: oidc.clientSecret or oidc.existingSecret must be provided when oidc.enabled is true" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.smtp.enabled -}}
  {{- if not .Values.smtp.senderAddr -}}
    {{- fail "ntfy: smtp.senderAddr is required when smtp.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.smtp.senderFrom -}}
    {{- fail "ntfy: smtp.senderFrom is required when smtp.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.ntfy.baseUrl -}}
    {{- fail "ntfy: ntfy.baseUrl is required when smtp.enabled is true" -}}
  {{- end -}}
{{- end -}}
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
{{- range .Values.ntfy.extraEnv -}}
  {{- if eq (upper (default "" .name)) "NTFY_LISTEN_HTTP" -}}
    {{- fail "ntfy: ntfy.extraEnv must not override NTFY_LISTEN_HTTP; use containerPorts.http" -}}
  {{- end -}}
{{- end -}}
{{- if regexMatch "(?m)^[[:space:]]*listen-http[[:space:]]*:" .Values.ntfy.extraConfig -}}
  {{- fail "ntfy: ntfy.extraConfig must not override listen-http; use containerPorts.http" -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
  {{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") (eq $key "app.kubernetes.io/component") -}}
    {{- fail (printf "ntfy: podLabels must not override reserved selector label %s" $key) -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.podDisruptionBudget.enabled (ne .Values.podDisruptionBudget.minAvailable nil) (ne .Values.podDisruptionBudget.maxUnavailable nil) -}}
  {{- fail "ntfy: podDisruptionBudget.minAvailable and maxUnavailable are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.networkPolicy.enabled .Values.networkPolicy.egress.enabled (include "ntfy.databaseEnabled" .) (not .Values.postgresql.enabled) (empty .Values.networkPolicy.egress.externalDatabaseCIDR) -}}
  {{- fail "ntfy: networkPolicy.egress.externalDatabaseCIDR is required for isolated external PostgreSQL mode" -}}
{{- end -}}
{{- if and .Values.backup.enabled (not .Values.persistence.enabled) -}}
  {{- fail "ntfy: backup.enabled requires persistence.enabled=true because the backup Job mounts the ntfy data PVC" -}}
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

{{- define "ntfy.appSelectorLabels" -}}
{{ include "ntfy.selectorLabels" . }}
app.kubernetes.io/component: server
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

{{/* S3 backup secret name */}}
{{- define "ntfy.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup-s3" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* OIDC Secret Name */}}
{{- define "ntfy.oidcSecretName" -}}
{{- if .Values.oidc.existingSecret -}}
{{- .Values.oidc.existingSecret -}}
{{- else -}}
{{- printf "%s-oidc" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* OIDC Secret Key */}}
{{- define "ntfy.oidcSecretKey" -}}
{{- .Values.oidc.existingSecretKey | default "client-secret" -}}
{{- end -}}

{{/* SMTP Secret Name */}}
{{- define "ntfy.smtpSecretName" -}}
{{- if .Values.smtp.existingSecret -}}
{{- .Values.smtp.existingSecret -}}
{{- else -}}
{{- printf "%s-smtp" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* SMTP Secret Password Key */}}
{{- define "ntfy.smtpSecretPasswordKey" -}}
{{- .Values.smtp.existingSecretPasswordKey | default "smtp-password" -}}
{{- end -}}
