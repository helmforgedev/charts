{{- define "homarr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "homarr.fullname" -}}
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

{{- define "homarr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "homarr.labels" -}}
helm.sh/chart: {{ include "homarr.chart" . }}
{{ include "homarr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "homarr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homarr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "homarr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "homarr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "homarr.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end }}

{{/* ======================================================================== */}}
{{/* Encryption helpers                                                        */}}
{{/* ======================================================================== */}}

{{- define "homarr.encryptionSecretName" -}}
{{- if .Values.encryption.existingSecret -}}
  {{- .Values.encryption.existingSecret -}}
{{- else -}}
  {{- printf "%s-encryption" (include "homarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "homarr.encryptionSecretKey" -}}
{{- if .Values.encryption.existingSecret -}}
  {{- .Values.encryption.existingSecretKey | default "secret-encryption-key" -}}
{{- else -}}
  secret-encryption-key
{{- end -}}
{{- end -}}

{{/* ======================================================================== */}}
{{/* Database helpers                                                          */}}
{{/* ======================================================================== */}}

{{- define "homarr.databaseMode" -}}
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
    {{- fail "homarr database selection is ambiguous: configure only one of database.external.host, postgresql.enabled, or mysql.enabled" -}}
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

{{- define "homarr.databaseVendor" -}}
{{- $mode := include "homarr.databaseMode" . -}}
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
Homarr DB_DRIVER value: better-sqlite3, node-postgres, mysql2
*/}}
{{- define "homarr.dbDriver" -}}
{{- $vendor := include "homarr.databaseVendor" . -}}
{{- if eq $vendor "sqlite3" -}}better-sqlite3
{{- else if eq $vendor "mysql" -}}mysql2
{{- else -}}node-postgres
{{- end -}}
{{- end -}}

{{- define "homarr.databaseHost" -}}
{{- $mode := include "homarr.databaseMode" . -}}
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

{{- define "homarr.databasePort" -}}
{{- $mode := include "homarr.databaseMode" . -}}
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

{{- define "homarr.databaseName" -}}
{{- $mode := include "homarr.databaseMode" . -}}
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

{{- define "homarr.databaseUsername" -}}
{{- $mode := include "homarr.databaseMode" . -}}
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

{{- define "homarr.databasePasswordValue" -}}
{{- $mode := include "homarr.databaseMode" . -}}
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
Database URL for Homarr (postgres://user:pass@host:port/db or mysql://...)
*/}}
{{- define "homarr.dbUrl" -}}
{{- $mode := include "homarr.databaseMode" . -}}
{{- if eq $mode "sqlite" -}}
{{- .Values.database.sqlite.path -}}
{{- else -}}
{{- $vendor := include "homarr.databaseVendor" . -}}
{{- $host := include "homarr.databaseHost" . -}}
{{- $port := include "homarr.databasePort" . -}}
{{- $name := include "homarr.databaseName" . -}}
{{- $user := include "homarr.databaseUsername" . -}}
{{- if eq $vendor "mysql" -}}
{{- printf "mysql://%s:$(DB_PASSWORD)@%s:%s/%s" $user $host $port $name -}}
{{- else -}}
{{- printf "postgres://%s:$(DB_PASSWORD)@%s:%s/%s" $user $host $port $name -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "homarr.databaseSecretName" -}}
{{- $mode := include "homarr.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
  {{- .Values.database.external.existingSecret -}}
{{- else -}}
  {{- printf "%s-database" (include "homarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "homarr.databaseSecretKey" -}}
{{- $mode := include "homarr.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
  {{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else -}}
  database-password
{{- end -}}
{{- end -}}

{{/* ======================================================================== */}}
{{/* Backup helpers                                                            */}}
{{/* ======================================================================== */}}

{{- define "homarr.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
  {{- .Values.backup.s3.existingSecret -}}
{{- else -}}
  {{- printf "%s-backup-s3" (include "homarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "homarr.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
  {{- .Values.backup.database.host -}}
{{- else -}}
  {{- include "homarr.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{- define "homarr.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
  {{- .Values.backup.database.port | toString -}}
{{- else -}}
  {{- include "homarr.databasePort" . -}}
{{- end -}}
{{- end -}}

{{- define "homarr.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
  {{- .Values.backup.database.name -}}
{{- else -}}
  {{- include "homarr.databaseName" . -}}
{{- end -}}
{{- end -}}

{{- define "homarr.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
  {{- .Values.backup.database.username -}}
{{- else -}}
  {{- include "homarr.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{- define "homarr.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
  {{- .Values.backup.database.existingSecret -}}
{{- else if .Values.backup.database.password -}}
  {{- printf "%s-backup-db" (include "homarr.fullname" .) -}}
{{- else -}}
  {{- include "homarr.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "homarr.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
  {{- .Values.backup.database.existingSecretPasswordKey | default "database-password" -}}
{{- else if .Values.backup.database.password -}}
  database-password
{{- else -}}
  {{- include "homarr.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}
