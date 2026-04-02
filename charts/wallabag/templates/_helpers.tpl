{{- define "wallabag.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wallabag.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "wallabag.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "wallabag.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wallabag.labels" -}}
helm.sh/chart: {{ include "wallabag.chart" . }}
{{ include "wallabag.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "wallabag.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wallabag.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "wallabag.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "wallabag.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "wallabag.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Database host */}}
{{- define "wallabag.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "wallabag.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "wallabag.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "wallabag" -}}
{{- else -}}
{{- .Values.database.external.name | default "wallabag" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "wallabag.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "wallabag" -}}
{{- else -}}
{{- .Values.database.external.username | default "wallabag" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name */}}
{{- define "wallabag.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "wallabag.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "wallabag.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- "user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Redis host */}}
{{- define "wallabag.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else -}}
{{- .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/* Redis port */}}
{{- define "wallabag.redisPort" -}}
{{- if .Values.redis.enabled -}}
{{- "6379" -}}
{{- else -}}
{{- .Values.externalRedis.port | default "6379" -}}
{{- end -}}
{{- end -}}

{{/* App secret name */}}
{{- define "wallabag.appSecretName" -}}
{{- if .Values.wallabag.existingSecret -}}
{{- .Values.wallabag.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "wallabag.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* App secret key */}}
{{- define "wallabag.appSecretKey" -}}
{{- if .Values.wallabag.existingSecret -}}
{{- .Values.wallabag.existingSecretKey | default "symfony-secret" -}}
{{- else -}}
{{- "symfony-secret" -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "wallabag.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "wallabag.fullname" .) -}}
{{- end -}}
{{- end -}}
{{/* Backup — S3 secret name */}}
{{- define "wallabag.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "wallabag.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "wallabag.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
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

{{/* Backup — database host */}}
{{- define "wallabag.backupDbHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "wallabag.dbHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database port */}}
{{- define "wallabag.backupDbPort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "wallabag.dbPort" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database name */}}
{{- define "wallabag.backupDbName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "wallabag.dbName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database username */}}
{{- define "wallabag.backupDbUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "wallabag.dbUsername" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret name */}}
{{- define "wallabag.backupDbPasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "wallabag.dbSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret key */}}
{{- define "wallabag.backupDbPasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "wallabag.dbSecretPasswordKey" . -}}
{{- end -}}
{{- end -}}
