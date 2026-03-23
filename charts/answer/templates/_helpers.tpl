{{- define "answer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "answer.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "answer.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "answer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "answer.labels" -}}
helm.sh/chart: {{ include "answer.chart" . }}
{{ include "answer.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "answer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "answer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "answer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "answer.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "answer.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

# =============================================================================
# Database Mode Detection
# =============================================================================

{{- define "answer.databaseMode" -}}
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
    {{- fail "answer database selection is ambiguous: configure only one of database.external.host, postgresql.enabled, or mysql.enabled" -}}
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

{{- define "answer.databaseVendor" -}}
{{- $mode := include "answer.databaseMode" . -}}
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

{{/* Answer uses DB_TYPE env var with values: sqlite3, mysql, postgres */}}
{{- define "answer.dbType" -}}
{{- $vendor := include "answer.databaseVendor" . -}}
{{- if eq $vendor "sqlite3" -}}sqlite3
{{- else if eq $vendor "mysql" -}}mysql
{{- else -}}postgres
{{- end -}}
{{- end -}}

{{- define "answer.databaseHost" -}}
{{- $mode := include "answer.databaseMode" . -}}
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

{{- define "answer.databasePort" -}}
{{- $mode := include "answer.databaseMode" . -}}
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

{{- define "answer.databaseName" -}}
{{- $mode := include "answer.databaseMode" . -}}
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

{{- define "answer.databaseUsername" -}}
{{- $mode := include "answer.databaseMode" . -}}
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

{{- define "answer.databasePasswordValue" -}}
{{- $mode := include "answer.databaseMode" . -}}
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

{{/* DB_HOST for Answer includes host:port */}}
{{- define "answer.dbHostPort" -}}
{{- $host := include "answer.databaseHost" . -}}
{{- $port := include "answer.databasePort" . -}}
{{- if and $host $port -}}
{{- printf "%s:%s" $host $port -}}
{{- else -}}
{{- $host -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Secrets
# =============================================================================

{{- define "answer.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "answer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "answer.adminSecretKey" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecretPasswordKey -}}
{{- else -}}
admin-password
{{- end -}}
{{- end -}}

{{- define "answer.databaseSecretName" -}}
{{- $mode := include "answer.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "answer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "answer.databaseSecretKey" -}}
{{- $mode := include "answer.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else -}}
database-password
{{- end -}}
{{- end -}}

# =============================================================================
# Backup
# =============================================================================

{{- define "answer.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "answer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "answer.backupEnabled" -}}
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
  {{- if and (eq (include "answer.databaseMode" .) "sqlite") (not .Values.persistence.enabled) -}}
    {{- fail "backup for sqlite mode requires persistence.enabled=true" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "answer.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "answer.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{- define "answer.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "answer.databasePort" . -}}
{{- end -}}
{{- end -}}

{{- define "answer.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "answer.databaseName" . -}}
{{- end -}}
{{- end -}}

{{- define "answer.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "answer.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{- define "answer.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "answer.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "answer.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
database-password
{{- end -}}
{{- end -}}
