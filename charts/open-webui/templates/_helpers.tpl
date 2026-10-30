{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "open-webui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "open-webui.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "open-webui.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "open-webui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "open-webui.labels" -}}
{{- include "open-webui.validateValues" . -}}
helm.sh/chart: {{ include "open-webui.chart" . }}
{{ include "open-webui.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "open-webui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "open-webui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "open-webui.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "open-webui.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "open-webui.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Validate combinations that JSON Schema cannot express. */}}
{{- define "open-webui.validateValues" -}}
{{- if and (eq .Values.database.mode "sqlite") .Values.postgresql.enabled -}}
{{- fail "database.mode=sqlite cannot be combined with postgresql.enabled=true" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") .Values.postgresql.enabled -}}
{{- fail "database.mode=external cannot be combined with postgresql.enabled=true" -}}
{{- end -}}
{{- if and .Values.postgresql.enabled (dig "tls" "enabled" false .Values.postgresql) -}}
{{- fail "postgresql.tls.enabled is not supported by the generated Open WebUI database URL" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") (not .Values.database.url) (not .Values.database.existingSecret) -}}
{{- fail "database.mode=external requires database.url or database.existingSecret" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redis.enabled -}}
{{- fail "redisConfig.mode=external cannot be combined with redis.enabled=true" -}}
{{- end -}}
{{- if and .Values.redis.enabled (dig "tls" "enabled" false .Values.redis) -}}
{{- fail "redis.tls.enabled is not supported by the bundled Open WebUI Redis URL" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "disabled") .Values.redis.enabled -}}
{{- fail "redisConfig.mode=disabled cannot be combined with redis.enabled=true" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "external") (not .Values.redisConfig.url) (not .Values.redisConfig.existingSecret) -}}
{{- fail "redisConfig.mode=external requires redisConfig.url or redisConfig.existingSecret" -}}
{{- end -}}
{{- if and .Values.openWebui.secretKey .Values.openWebui.existingSecret -}}
{{- fail "openWebui.secretKey and openWebui.existingSecret are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.openWebui.openaiApiKey .Values.openWebui.openaiExistingSecret -}}
{{- fail "openWebui.openaiApiKey and openWebui.openaiExistingSecret are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.enabled requires ingress.hosts to contain at least one host" -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component") -}}
{{- fail (printf "podLabels cannot override reserved selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "open-webui.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "open-webui.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ===== Secret helpers ===== */}}

{{/* Application secret name */}}
{{- define "open-webui.secretName" -}}
{{- if .Values.openWebui.existingSecret -}}
{{- .Values.openWebui.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "open-webui.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* OpenAI secret name */}}
{{- define "open-webui.openaiSecretName" -}}
{{- if .Values.openWebui.openaiExistingSecret -}}
{{- .Values.openWebui.openaiExistingSecret -}}
{{- else -}}
{{- printf "%s-openai" (include "open-webui.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* External database URL secret name */}}
{{- define "open-webui.externalDatabaseSecretName" -}}
{{- if .Values.database.existingSecret -}}
{{- .Values.database.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "open-webui.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* External Redis URL secret name */}}
{{- define "open-webui.externalRedisSecretName" -}}
{{- if .Values.redisConfig.existingSecret -}}
{{- .Values.redisConfig.existingSecret -}}
{{- else -}}
{{- printf "%s-redis" (include "open-webui.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ===== Database helpers ===== */}}

{{/* Database mode detection */}}
{{- define "open-webui.databaseMode" -}}
{{- if eq .Values.database.mode "sqlite" -}}
sqlite
{{- else if eq .Values.database.mode "external" -}}
external
{{- else -}}
{{- /* auto: use subchart if enabled, otherwise sqlite */}}
{{- if .Values.postgresql.enabled -}}
auto
{{- else -}}
sqlite
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Database type (sqlite or postgres) */}}
{{- define "open-webui.databaseType" -}}
{{- $mode := include "open-webui.databaseMode" . -}}
{{- if eq $mode "sqlite" -}}
sqlite
{{- else -}}
postgres
{{- end -}}
{{- end -}}

{{/* Database URL for PostgreSQL */}}
{{- define "open-webui.databaseUrl" -}}
{{- $mode := include "open-webui.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.url -}}
{{- else if eq $mode "auto" -}}
{{- printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%s/%s" .Values.postgresql.auth.username (include "open-webui.databaseHost" .) "5432" .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{/* Database host */}}
{{- define "open-webui.postgresqlFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Database host */}}
{{- define "open-webui.databaseHost" -}}
{{- $mode := include "open-webui.databaseMode" . -}}
{{- if eq $mode "auto" -}}
{{- if eq (default "standalone" .Values.postgresql.architecture) "replication" -}}
{{- printf "%s-primary" (include "open-webui.postgresqlFullname" .) -}}
{{- else -}}
{{- include "open-webui.postgresqlFullname" . -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Database secret name (subchart password) */}}
{{- define "open-webui.databaseSecretName" -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- $externalSecrets := .Values.postgresql.externalSecrets | default dict -}}
{{- $auth := get $externalSecrets "auth" | default dict -}}
{{- if and (get $externalSecrets "enabled") (get $auth "enabled") -}}
{{- default (printf "%s-auth" (include "open-webui.postgresqlFullname" .)) (get $auth "targetName") -}}
{{- else -}}
{{- printf "%s-auth" (include "open-webui.postgresqlFullname" .) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Database secret key */}}
{{- define "open-webui.databaseSecretKey" -}}
{{- .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" -}}
{{- end -}}

{{/* ===== Redis helpers ===== */}}

{{/* Redis mode detection */}}
{{- define "open-webui.redisMode" -}}
{{- if eq .Values.redisConfig.mode "disabled" -}}
disabled
{{- else if eq .Values.redisConfig.mode "external" -}}
external
{{- else -}}
{{- if .Values.redis.enabled -}}
auto
{{- else -}}
disabled
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Redis URL */}}
{{- define "open-webui.redisFullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Redis URL */}}
{{- define "open-webui.redisUrl" -}}
{{- $mode := include "open-webui.redisMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.redisConfig.url -}}
{{- else if eq $mode "auto" -}}
{{- if .Values.redis.auth.enabled -}}
{{- printf "redis://:%s@%s-client:6379/0" "$(REDIS_PASSWORD)" (include "open-webui.redisFullname" .) -}}
{{- else -}}
{{- printf "redis://%s-client:6379/0" (include "open-webui.redisFullname" .) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Redis secret name */}}
{{- define "open-webui.redisSecretName" -}}
{{- if .Values.redis.auth.existingSecret -}}
{{- .Values.redis.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "open-webui.redisFullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Redis subchart password key */}}
{{- define "open-webui.redisSecretKey" -}}
{{- .Values.redis.auth.existingSecretPasswordKey | default "redis-password" -}}
{{- end -}}

{{/* ===== Backup helpers ===== */}}

{{/* Backup S3 secret name */}}
{{- define "open-webui.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "open-webui.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Validate backup configuration */}}
{{- define "open-webui.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- $dbType := include "open-webui.databaseType" . -}}
  {{- if eq $dbType "sqlite" -}}
    {{- fail "backup requires PostgreSQL — set postgresql.enabled=true or database.mode=external" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.accessKey) -}}
    {{- fail "backup.s3.accessKey or backup.s3.existingSecret is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.secretKey) -}}
    {{- fail "backup.s3.secretKey or backup.s3.existingSecret is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if eq .Values.database.mode "external" -}}
    {{- if not .Values.backup.database.host -}}
      {{- fail "backup.database.host is required for external PostgreSQL backups" -}}
    {{- end -}}
    {{- if not .Values.backup.database.name -}}
      {{- fail "backup.database.name is required for external PostgreSQL backups" -}}
    {{- end -}}
    {{- if not .Values.backup.database.username -}}
      {{- fail "backup.database.username is required for external PostgreSQL backups" -}}
    {{- end -}}
    {{- if not .Values.backup.database.existingSecret -}}
      {{- fail "backup.database.existingSecret is required for external PostgreSQL backups" -}}
    {{- end -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{/* Backup database host */}}
{{- define "open-webui.backupDbHost" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "open-webui.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup database port */}}
{{- define "open-webui.backupDbPort" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.backup.database.port -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{/* Backup database name */}}
{{- define "open-webui.backupDbName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{/* Backup database username */}}
{{- define "open-webui.backupDbUsername" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{/* Backup database password secret name */}}
{{- define "open-webui.backupDbPasswordSecretName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "open-webui.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup database password secret key */}}
{{- define "open-webui.backupDbPasswordSecretKey" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.backup.database.existingSecretKey -}}
{{- else -}}
{{- include "open-webui.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}
