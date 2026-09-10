{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "n8n.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "n8n.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "n8n.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "n8n.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "n8n.labels" -}}
helm.sh/chart: {{ include "n8n.chart" . }}
{{ include "n8n.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "n8n.selectorLabels" -}}
app.kubernetes.io/name: {{ include "n8n.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "n8n.workerLabels" -}}
{{ include "n8n.selectorLabels" . }}
app.kubernetes.io/component: worker
{{- end -}}

{{- define "n8n.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "n8n.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "n8n.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "n8n.runnerImage" -}}
{{- printf "%s:%s" .Values.taskRunners.image.repository (.Values.taskRunners.image.tag | default .Values.image.tag) -}}
{{- end -}}

{{- define "n8n.validate" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- $taskRunnerMode := .Values.taskRunners.mode | default "external" -}}
{{- if not (has $taskRunnerMode (list "internal" "external")) -}}
{{- fail (printf "taskRunners.mode must be one of: internal, external (got %s)" $taskRunnerMode) -}}
{{- end -}}
{{- if and .Values.taskRunners.nativePython.enabled (ne $taskRunnerMode "external") -}}
{{- fail "taskRunners.nativePython.enabled=true requires taskRunners.mode=external" -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Database Mode Detection
# =============================================================================

{{- define "n8n.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- $vendor := .Values.database.external.vendor | default "postgres" -}}
{{- if or (.Values.mysql.enabled | default false) (eq $mode "mysql") (has $vendor (list "mysql" "mariadb")) -}}
{{- fail "n8n 2.x removed MySQL/MariaDB storage; migrate data to PostgreSQL or SQLite before upgrading" -}}
{{- end -}}
{{- if not (has $mode (list "auto" "sqlite" "external" "postgresql")) -}}
{{- fail (printf "database.mode must be one of: auto, sqlite, external, postgresql (got %s)" $mode) -}}
{{- end -}}
{{- if ne $vendor "postgres" -}}
{{- fail "database.external.vendor must be postgres; n8n 2.x supports only PostgreSQL and SQLite storage" -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- $hasRedis := or (.Values.redis.enabled | default false) (ne (.Values.queue.external.host | default "") "") -}}
{{- if and .Values.queue.enabled (not $hasRedis) -}}
{{- fail "queue.enabled=true requires redis.enabled=true or queue.external.host to be set" -}}
{{- end -}}
{{- if and .Values.queue.enabled (or (eq $mode "sqlite") (and (eq $mode "auto") (not (or $hasExternal $hasPostgresql)))) -}}
{{- fail "queue.enabled=true is not supported with SQLite; configure PostgreSQL or an external PostgreSQL database" -}}
{{- end -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasPostgresql -}}
    {{- fail "n8n database selection is ambiguous: configure only one of database.external.host or postgresql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else -}}sqlite
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "sqlite") (or $hasExternal $hasPostgresql) -}}
    {{- fail "database.mode=sqlite cannot be combined with database.external or postgresql.enabled" -}}
  {{- end -}}
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
    {{- fail "database.mode=postgresql cannot be combined with database.external" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "n8n.databaseVendor" -}}
{{- if eq (include "n8n.databaseMode" .) "sqlite" -}}sqlite{{- else -}}postgres{{- end -}}
{{- end -}}

{{/* n8n 2.x supports only sqlite and postgresdb. */}}
{{- define "n8n.dbType" -}}
{{- if eq (include "n8n.databaseVendor" .) "sqlite" -}}sqlite{{- else -}}postgresdb{{- end -}}
{{- end -}}

{{- define "n8n.databaseHost" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if eq $mode "external" -}}{{- .Values.database.external.host -}}
{{- else if eq $mode "postgresql" -}}{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "n8n.databasePort" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if eq $mode "external" -}}{{- .Values.database.external.port | default 5432 | toString -}}
{{- else if eq $mode "postgresql" -}}5432
{{- end -}}
{{- end -}}

{{- define "n8n.databaseName" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if eq $mode "external" -}}{{- .Values.database.external.name -}}
{{- else if eq $mode "postgresql" -}}{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "n8n.databaseUsername" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if eq $mode "external" -}}{{- .Values.database.external.username -}}
{{- else if eq $mode "postgresql" -}}{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "n8n.databasePasswordValue" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if eq $mode "external" -}}{{- .Values.database.external.password -}}
{{- else if eq $mode "postgresql" -}}{{- .Values.postgresql.auth.password -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Secrets
# =============================================================================

{{- define "n8n.encryptionKeySecretName" -}}
{{- if .Values.encryptionKey.existingSecret -}}
{{- .Values.encryptionKey.existingSecret -}}
{{- else -}}
{{- printf "%s-encryption" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "n8n.encryptionKeySecretKey" -}}
{{- if .Values.encryptionKey.existingSecret -}}
{{- .Values.encryptionKey.existingSecretKey -}}
{{- else -}}
encryption-key
{{- end -}}
{{- end -}}

{{- define "n8n.databaseSecretName" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "n8n.databaseSecretKey" -}}
{{- $mode := include "n8n.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else -}}
database-password
{{- end -}}
{{- end -}}

{{- define "n8n.taskRunnerSecretName" -}}
{{- if .Values.taskRunners.existingSecret -}}
{{- .Values.taskRunners.existingSecret -}}
{{- else -}}
{{- printf "%s-task-runners" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "n8n.taskRunnerSecretKey" -}}
{{- if .Values.taskRunners.existingSecret -}}
{{- .Values.taskRunners.existingSecretKey -}}
{{- else -}}
auth-token
{{- end -}}
{{- end -}}

# =============================================================================
# Redis / Queue
# =============================================================================

{{- define "n8n.redisHost" -}}
{{- if .Values.queue.external.host -}}
{{- .Values.queue.external.host -}}
{{- else if .Values.redis.enabled -}}
{{- printf "%s-redis-client" .Release.Name -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "n8n.redisPort" -}}
{{- if .Values.queue.external.host -}}
{{- .Values.queue.external.port | default 6379 | toString -}}
{{- else -}}
6379
{{- end -}}
{{- end -}}

{{- define "n8n.redisSecretName" -}}
{{- if .Values.queue.external.existingSecret -}}
{{- .Values.queue.external.existingSecret -}}
{{- else -}}
{{- printf "%s-redis-queue" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "n8n.redisSecretKey" -}}
{{- if .Values.queue.external.existingSecret -}}
{{- .Values.queue.external.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{- define "n8n.redisPasswordValue" -}}
{{- if .Values.queue.external.host -}}
{{- .Values.queue.external.password -}}
{{- else if .Values.redis.enabled -}}
{{- .Values.redis.auth.password -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "n8n.hasRedisPassword" -}}
{{- if or .Values.queue.external.password .Values.queue.external.existingSecret (and .Values.redis.enabled .Values.redis.auth.password) -}}true{{- end -}}
{{- end -}}

# =============================================================================
# Backup
# =============================================================================

{{- define "n8n.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "n8n.backupEnabled" -}}
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
  {{- if and (eq (include "n8n.databaseMode" .) "sqlite") (not .Values.persistence.enabled) -}}
    {{- fail "backup for sqlite mode requires persistence.enabled=true" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "n8n.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "n8n.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{- define "n8n.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "n8n.databasePort" . -}}
{{- end -}}
{{- end -}}

{{- define "n8n.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "n8n.databaseName" . -}}
{{- end -}}
{{- end -}}

{{- define "n8n.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "n8n.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{- define "n8n.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "n8n.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "n8n.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
database-password
{{- end -}}
{{- end -}}
