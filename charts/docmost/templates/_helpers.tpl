{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "docmost.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "docmost.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "docmost.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "docmost.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "docmost.labels" -}}
helm.sh/chart: {{ include "docmost.chart" . }}
{{ include "docmost.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "docmost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "docmost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "docmost.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "docmost.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "docmost.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "docmost.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "postgresql")) -}}
{{- fail (printf "database.mode must be one of: auto, external, postgresql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasPostgresql -}}
    {{- fail "docmost database selection is ambiguous: configure only one of database.external.* or postgresql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else -}}{{- fail "docmost requires PostgreSQL: enable postgresql.enabled or configure database.external.host" -}}
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

{{- define "docmost.databaseHost" -}}
{{- if eq (include "docmost.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "docmost.databasePort" -}}
{{- if eq (include "docmost.databaseMode" .) "external" -}}
{{- .Values.database.external.port | default 5432 | toString -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{- define "docmost.databaseName" -}}
{{- if eq (include "docmost.databaseMode" .) "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "docmost.databaseUsername" -}}
{{- if eq (include "docmost.databaseMode" .) "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "docmost.databaseSecretName" -}}
{{- if and (eq (include "docmost.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "docmost.databaseMode" .) "external" -}}
{{- printf "%s-database" (include "docmost.fullname" .) -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "docmost.databaseSecretKey" -}}
{{- if and (eq (include "docmost.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else if eq (include "docmost.databaseMode" .) "external" -}}
database-password
{{- else -}}
user-password
{{- end -}}
{{- end -}}

{{- define "docmost.redisMode" -}}
{{- $hasExternal := or (ne (.Values.redis.external.host | default "") "") (ne (.Values.redis.external.existingSecret | default "") "") -}}
{{- $hasSubchart := .Values.redis.enabled | default false -}}
{{- if and $hasExternal $hasSubchart -}}
{{- fail "docmost redis selection is ambiguous: configure only one of redis.external.* or redis.enabled" -}}
{{- end -}}
{{- if $hasExternal -}}external
{{- else if $hasSubchart -}}subchart
{{- else -}}{{- fail "docmost requires Redis: enable redis.enabled or configure redis.external.host" -}}
{{- end -}}
{{- end -}}

{{- define "docmost.redisHost" -}}
{{- if eq (include "docmost.redisMode" .) "external" -}}
{{- .Values.redis.external.host -}}
{{- else -}}
{{- printf "%s-redis-client" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "docmost.redisPort" -}}
{{- if eq (include "docmost.redisMode" .) "external" -}}
{{- .Values.redis.external.port | default 6379 | toString -}}
{{- else -}}
6379
{{- end -}}
{{- end -}}

{{- define "docmost.redisSecretName" -}}
{{- if and (eq (include "docmost.redisMode" .) "external") .Values.redis.external.existingSecret -}}
{{- .Values.redis.external.existingSecret -}}
{{- else if eq (include "docmost.redisMode" .) "external" -}}
{{- printf "%s-redis" (include "docmost.fullname" .) -}}
{{- else -}}
{{- printf "%s-redis-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "docmost.redisSecretKey" -}}
{{- if and (eq (include "docmost.redisMode" .) "external") .Values.redis.external.existingSecret -}}
{{- .Values.redis.external.existingSecretPasswordKey | default "redis-password" -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{- define "docmost.hasRedisPassword" -}}
{{- if eq (include "docmost.redisMode" .) "external" -}}
{{- if or .Values.redis.external.password .Values.redis.external.existingSecret -}}true{{- end -}}
{{- else -}}
{{- if .Values.redis.auth.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{- define "docmost.appUrl" -}}
{{- if .Values.docmost.appUrl -}}
{{- .Values.docmost.appUrl -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- printf "https://%s" (index .Values.ingress.hosts 0).host -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "docmost.appSecretSecretName" -}}
{{- printf "%s-app" (include "docmost.fullname" .) -}}
{{- end -}}

{{- define "docmost.storageSecretName" -}}
{{- if .Values.storage.s3.existingSecret -}}
{{- .Values.storage.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-storage" (include "docmost.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "docmost.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "docmost.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "docmost.backupEnabled" -}}
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

{{- define "docmost.backupDbHost" -}}
{{- include "docmost.databaseHost" . -}}
{{- end -}}

{{- define "docmost.backupDbPort" -}}
{{- include "docmost.databasePort" . -}}
{{- end -}}

{{- define "docmost.backupDbName" -}}
{{- include "docmost.databaseName" . -}}
{{- end -}}

{{- define "docmost.backupDbUsername" -}}
{{- include "docmost.databaseUsername" . -}}
{{- end -}}

{{- define "docmost.backupDbPasswordSecretName" -}}
{{- include "docmost.databaseSecretName" . -}}
{{- end -}}

{{- define "docmost.backupDbPasswordSecretKey" -}}
{{- include "docmost.databaseSecretKey" . -}}
{{- end -}}
