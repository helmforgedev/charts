{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "flowise.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "flowise.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "flowise.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "flowise.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "flowise.labels" -}}
helm.sh/chart: {{ include "flowise.chart" . }}
{{ include "flowise.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "flowise.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flowise.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "flowise.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "flowise.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "flowise.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "flowise.architectureMode" -}}
{{- $mode := .Values.architecture.mode | default "standalone" -}}
{{- if not (has $mode (list "standalone" "queue")) -}}
{{- fail (printf "architecture.mode must be one of: standalone, queue (got %s)" $mode) -}}
{{- end -}}
{{- $mode -}}
{{- end -}}

{{- define "flowise.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "sqlite" "external" "postgresql")) -}}
{{- fail (printf "database.mode must be one of: auto, sqlite, external, postgresql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasPostgresql -}}
    {{- fail "flowise database selection is ambiguous: configure only one of database.external.* or postgresql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else -}}sqlite
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

{{- define "flowise.databaseType" -}}
{{- $mode := include "flowise.databaseMode" . -}}
{{- if eq $mode "sqlite" -}}sqlite
{{- else if eq $mode "postgresql" -}}postgres
{{- else if eq .Values.database.external.vendor "mysql" -}}mysql
{{- else -}}postgres
{{- end -}}
{{- end -}}

{{- define "flowise.databaseHost" -}}
{{- if eq (include "flowise.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "flowise.databasePort" -}}
{{- if eq (include "flowise.databaseMode" .) "external" -}}
{{- if .Values.database.external.port -}}
{{- .Values.database.external.port | toString -}}
{{- else if eq .Values.database.external.vendor "mysql" -}}3306
{{- else -}}5432
{{- end -}}
{{- else -}}5432
{{- end -}}
{{- end -}}

{{- define "flowise.databaseName" -}}
{{- if eq (include "flowise.databaseMode" .) "external" -}}
{{- .Values.database.external.name -}}
{{- else if eq (include "flowise.databaseMode" .) "postgresql" -}}
{{- .Values.postgresql.auth.database -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "flowise.databaseUsername" -}}
{{- if eq (include "flowise.databaseMode" .) "external" -}}
{{- .Values.database.external.username -}}
{{- else if eq (include "flowise.databaseMode" .) "postgresql" -}}
{{- .Values.postgresql.auth.username -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "flowise.databaseSecretName" -}}
{{- if and (eq (include "flowise.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "flowise.databaseMode" .) "external" -}}
{{- printf "%s-database" (include "flowise.fullname" .) -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "flowise.databaseSecretKey" -}}
{{- if and (eq (include "flowise.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else if eq (include "flowise.databaseMode" .) "external" -}}
database-password
{{- else -}}
user-password
{{- end -}}
{{- end -}}

{{- define "flowise.redisMode" -}}
{{- $hasExternal := or (ne (.Values.redis.external.host | default "") "") (ne (.Values.redis.external.existingSecret | default "") "") -}}
{{- $hasSubchart := .Values.redis.enabled | default false -}}
{{- if and $hasExternal $hasSubchart -}}
{{- fail "flowise redis selection is ambiguous: configure only one of redis.external.* or redis.enabled" -}}
{{- end -}}
{{- if $hasExternal -}}external
{{- else if $hasSubchart -}}subchart
{{- else -}}none
{{- end -}}
{{- end -}}

{{- define "flowise.redisHost" -}}
{{- if eq (include "flowise.redisMode" .) "external" -}}
{{- .Values.redis.external.host -}}
{{- else -}}
{{- printf "%s-redis-client" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "flowise.redisPort" -}}
{{- if eq (include "flowise.redisMode" .) "external" -}}
{{- .Values.redis.external.port | default 6379 | toString -}}
{{- else -}}6379
{{- end -}}
{{- end -}}

{{- define "flowise.redisUsername" -}}
{{- if eq (include "flowise.redisMode" .) "external" -}}
{{- .Values.redis.external.username | default "" -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "flowise.redisSecretName" -}}
{{- if and (eq (include "flowise.redisMode" .) "external") .Values.redis.external.existingSecret -}}
{{- .Values.redis.external.existingSecret -}}
{{- else if eq (include "flowise.redisMode" .) "external" -}}
{{- printf "%s-redis" (include "flowise.fullname" .) -}}
{{- else -}}
{{- printf "%s-redis-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "flowise.redisSecretKey" -}}
{{- if and (eq (include "flowise.redisMode" .) "external") .Values.redis.external.existingSecret -}}
{{- .Values.redis.external.existingSecretPasswordKey | default "redis-password" -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{- define "flowise.hasRedisPassword" -}}
{{- if eq (include "flowise.redisMode" .) "external" -}}
{{- if or .Values.redis.external.password .Values.redis.external.existingSecret -}}true{{- end -}}
{{- else if eq (include "flowise.redisMode" .) "subchart" -}}
{{- if .Values.redis.auth.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{- define "flowise.appUrl" -}}
{{- if .Values.flowise.appUrl -}}
{{- .Values.flowise.appUrl -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- printf "https://%s" (index .Values.ingress.hosts 0).host -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "flowise.authSecretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "flowise.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "flowise.storageSecretName" -}}
{{- if .Values.storage.s3.existingSecret -}}
{{- .Values.storage.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-storage" (include "flowise.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "flowise.dataVolumeEnabled" -}}
{{- if and .Values.persistence.enabled (or (eq .Values.storage.type "local") (eq (include "flowise.databaseMode" .) "sqlite")) -}}true{{- end -}}
{{- end -}}

{{- define "flowise.mainCommand" -}}
sleep 3; flowise start
{{- end -}}

{{- define "flowise.workerCommand" -}}
sleep 3; flowise worker
{{- end -}}

{{- define "flowise.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "flowise.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "flowise.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- $dbMode := include "flowise.databaseMode" . -}}
  {{- if eq $dbMode "sqlite" -}}
    {{- fail "backup.enabled requires PostgreSQL - backup is not supported when database mode is sqlite" -}}
  {{- end -}}
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
