{{- define "listmonk.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "listmonk.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "listmonk.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "listmonk.labels" -}}
helm.sh/chart: {{ include "listmonk.chart" . }}
{{ include "listmonk.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "listmonk.selectorLabels" -}}
app.kubernetes.io/name: {{ include "listmonk.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "listmonk.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "listmonk.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* ======== Database helpers ======== */}}

{{- define "listmonk.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "postgresql")) -}}
{{- fail (printf "database.mode must be one of: auto, external, postgresql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasPostgresql -}}
    {{- fail "listmonk database selection is ambiguous: configure only one of database.external.* or postgresql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else -}}{{- fail "listmonk requires PostgreSQL: enable postgresql.enabled or configure database.external.host" -}}
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}
  {{- end -}}
  {{- if and (eq $mode "external") $hasPostgresql -}}
    {{- fail "database.mode=external cannot be combined with postgresql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") (not $hasPostgresql) -}}
    {{- fail "database.mode=postgresql requires postgresql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") $hasExternal -}}
    {{- fail "database.mode=postgresql cannot be combined with database.external.*" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.databaseHost" -}}
{{- if eq (include "listmonk.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.databasePort" -}}
{{- if eq (include "listmonk.databaseMode" .) "external" -}}
{{- .Values.database.external.port | default 5432 | toString -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{- define "listmonk.databaseName" -}}
{{- if eq (include "listmonk.databaseMode" .) "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.databaseUsername" -}}
{{- if eq (include "listmonk.databaseMode" .) "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.databaseSslMode" -}}
{{- if eq (include "listmonk.databaseMode" .) "external" -}}
{{- .Values.database.external.sslMode | default "disable" -}}
{{- else -}}
disable
{{- end -}}
{{- end -}}

{{- define "listmonk.databaseSecretName" -}}
{{- if and (eq (include "listmonk.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "listmonk.databaseMode" .) "external" -}}
{{- printf "%s-database" (include "listmonk.fullname" .) -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "listmonk.databaseSecretKey" -}}
{{- if and (eq (include "listmonk.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else if eq (include "listmonk.databaseMode" .) "external" -}}
database-password
{{- else -}}
user-password
{{- end -}}
{{- end -}}

{{/* ======== Backup helpers ======== */}}

{{- define "listmonk.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "listmonk.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "listmonk.fullname" .) -}}
{{- end -}}
{{- end -}}
