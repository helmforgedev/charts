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
{{- $tag := .Values.image.tag | default (printf "v%s" .Chart.AppVersion) -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
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
{{- include "open-webui.secretName" . -}}
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
{{- define "open-webui.databaseHost" -}}
{{- $mode := include "open-webui.databaseMode" . -}}
{{- if eq $mode "auto" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Database secret name (subchart password) */}}
{{- define "open-webui.databaseSecretName" -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}

{{/* Database secret key */}}
{{- define "open-webui.databaseSecretKey" -}}
user-password
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
{{- define "open-webui.redisUrl" -}}
{{- $mode := include "open-webui.redisMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.redisConfig.url -}}
{{- else if eq $mode "auto" -}}
{{- printf "redis://:%s@%s-redis:6379/0" "$(REDIS_PASSWORD)" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Redis secret name */}}
{{- define "open-webui.redisSecretName" -}}
{{- printf "%s-redis" .Release.Name -}}
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
true
{{- end -}}
{{- end -}}

{{/* Backup database host */}}
{{- define "open-webui.backupDbHost" -}}
{{- include "open-webui.databaseHost" . -}}
{{- end -}}

{{/* Backup database port */}}
{{- define "open-webui.backupDbPort" -}}
5432
{{- end -}}

{{/* Backup database name */}}
{{- define "open-webui.backupDbName" -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}

{{/* Backup database username */}}
{{- define "open-webui.backupDbUsername" -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}

{{/* Backup database password secret name */}}
{{- define "open-webui.backupDbPasswordSecretName" -}}
{{- include "open-webui.databaseSecretName" . -}}
{{- end -}}

{{/* Backup database password secret key */}}
{{- define "open-webui.backupDbPasswordSecretKey" -}}
{{- include "open-webui.databaseSecretKey" . -}}
{{- end -}}
