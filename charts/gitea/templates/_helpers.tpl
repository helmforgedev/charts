{{/*
Expand the name of the chart.
*/}}
{{- define "gitea.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "gitea.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gitea.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gitea.labels" -}}
helm.sh/chart: {{ include "gitea.chart" . }}
{{ include "gitea.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gitea.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gitea.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "gitea.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gitea.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image reference with tag defaulting to appVersion-rootless
*/}}
{{- define "gitea.image" -}}
{{- $tag := .Values.image.tag | default (printf "%s-rootless" .Chart.AppVersion) -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/* ======================================================================== */}}
{{/* Database helpers                                                          */}}
{{/* ======================================================================== */}}

{{/*
Resolve the effective database mode.
Auto-detection priority: external → postgresql → mysql → sqlite
*/}}
{{- define "gitea.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "sqlite" "external" "postgresql" "mysql")) -}}
{{- fail (printf "database.mode must be one of: auto, sqlite, external, postgresql, mysql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- $vendor := .Values.database.external.vendor | default "postgres" -}}
{{- if not (has $vendor (list "postgres" "mysql")) -}}
{{- fail (printf "database.external.vendor must be one of: postgres, mysql (got %s)" $vendor) -}}
{{- end -}}
{{- if eq $mode "auto" -}}
  {{- $count := 0 -}}
  {{- if $hasExternal -}}{{- $count = add1 $count -}}{{- end -}}
  {{- if $hasPostgresql -}}{{- $count = add1 $count -}}{{- end -}}
  {{- if $hasMysql -}}{{- $count = add1 $count -}}{{- end -}}
  {{- if gt $count 1 -}}
    {{- fail "gitea database selection is ambiguous: configure only one of database.external.host, postgresql.enabled, or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else if $hasMysql -}}mysql
  {{- else -}}sqlite
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "sqlite") (or $hasExternal $hasPostgresql $hasMysql) -}}
    {{- fail "database.mode=sqlite cannot be combined with database.external, postgresql.enabled, or mysql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}
  {{- end -}}
  {{- if and (eq $mode "external") (or $hasPostgresql $hasMysql) -}}
    {{- fail "database.mode=external cannot be combined with postgresql.enabled or mysql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") (not $hasPostgresql) -}}
    {{- fail "database.mode=postgresql requires postgresql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") (or $hasExternal $hasMysql) -}}
    {{- fail "database.mode=postgresql cannot be combined with database.external or mysql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}
    {{- fail "database.mode=mysql requires mysql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") (or $hasExternal $hasPostgresql) -}}
    {{- fail "database.mode=mysql cannot be combined with database.external or postgresql.enabled" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{/*
Database vendor string for Gitea DB_TYPE env var
*/}}
{{- define "gitea.databaseVendor" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.vendor | default "postgres" -}}
{{- else if eq $mode "postgresql" -}}
postgres
{{- else if eq $mode "mysql" -}}
mysql
{{- else -}}
sqlite3
{{- end -}}
{{- end -}}

{{/*
Gitea DB_TYPE value
*/}}
{{- define "gitea.dbType" -}}
{{- $vendor := include "gitea.databaseVendor" . -}}
{{- if eq $vendor "sqlite3" -}}sqlite3
{{- else if eq $vendor "mysql" -}}mysql
{{- else -}}postgres
{{- end -}}
{{- end -}}

{{/*
Database host
*/}}
{{- define "gitea.databaseHost" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.host -}}
{{- else if eq $mode "postgresql" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if eq $mode "mysql" -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Database port
*/}}
{{- define "gitea.databasePort" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- if .Values.database.external.port -}}
{{- .Values.database.external.port | toString -}}
{{- else if eq (.Values.database.external.vendor | default "postgres") "mysql" -}}
3306
{{- else -}}
5432
{{- end -}}
{{- else if eq $mode "postgresql" -}}
5432
{{- else if eq $mode "mysql" -}}
3306
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Database name
*/}}
{{- define "gitea.databaseName" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.name -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.database -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.database -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Database username
*/}}
{{- define "gitea.databaseUsername" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.username -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.username -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.username -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Database password (plain text, used for secret generation)
*/}}
{{- define "gitea.databasePasswordValue" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.password -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.password -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.password -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Database host:port combined
*/}}
{{- define "gitea.dbHostPort" -}}
{{- $host := include "gitea.databaseHost" . -}}
{{- $port := include "gitea.databasePort" . -}}
{{- if and $host $port -}}
{{- printf "%s:%s" $host $port -}}
{{- else -}}
{{- $host -}}
{{- end -}}
{{- end -}}

{{/*
Database secret name (for password)
*/}}
{{- define "gitea.databaseSecretName" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
  {{- .Values.database.external.existingSecret -}}
{{- else -}}
  {{- printf "%s-database" (include "gitea.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Database secret key
*/}}
{{- define "gitea.databaseSecretKey" -}}
{{- $mode := include "gitea.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
  {{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else -}}
  database-password
{{- end -}}
{{- end -}}

{{/*
Admin secret name
*/}}
{{- define "gitea.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
  {{- .Values.admin.existingSecret -}}
{{- else -}}
  {{- printf "%s-admin" (include "gitea.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ======================================================================== */}}
{{/* Backup helpers                                                            */}}
{{/* ======================================================================== */}}

{{/*
Backup S3 secret name
*/}}
{{- define "gitea.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
  {{- .Values.backup.s3.existingSecret -}}
{{- else -}}
  {{- printf "%s-backup-s3" (include "gitea.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup database host (override or fallback)
*/}}
{{- define "gitea.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
  {{- .Values.backup.database.host -}}
{{- else -}}
  {{- include "gitea.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database port (override or fallback)
*/}}
{{- define "gitea.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
  {{- .Values.backup.database.port | toString -}}
{{- else -}}
  {{- include "gitea.databasePort" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database name (override or fallback)
*/}}
{{- define "gitea.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
  {{- .Values.backup.database.name -}}
{{- else -}}
  {{- include "gitea.databaseName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database username (override or fallback)
*/}}
{{- define "gitea.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
  {{- .Values.backup.database.username -}}
{{- else -}}
  {{- include "gitea.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret name
*/}}
{{- define "gitea.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
  {{- .Values.backup.database.existingSecret -}}
{{- else if .Values.backup.database.password -}}
  {{- printf "%s-backup-db" (include "gitea.fullname" .) -}}
{{- else -}}
  {{- include "gitea.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret key
*/}}
{{- define "gitea.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
  {{- .Values.backup.database.existingSecretPasswordKey | default "database-password" -}}
{{- else if .Values.backup.database.password -}}
  database-password
{{- else -}}
  {{- include "gitea.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}
