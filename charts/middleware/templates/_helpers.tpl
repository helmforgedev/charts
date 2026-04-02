{{- define "middleware.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "middleware.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "middleware.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "middleware.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "middleware.labels" -}}
helm.sh/chart: {{ include "middleware.chart" . }}
{{ include "middleware.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "middleware.selectorLabels" -}}
app.kubernetes.io/name: {{ include "middleware.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "middleware.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "middleware.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "middleware.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* PostgreSQL host */}}
{{- define "middleware.dbHost" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL port */}}
{{- define "middleware.dbPort" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.port | toString -}}
{{- else -}}
{{- "5432" -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL database name */}}
{{- define "middleware.dbName" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL user */}}
{{- define "middleware.dbUser" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.user -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL secret name */}}
{{- define "middleware.dbSecretName" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL secret password key */}}
{{- define "middleware.dbSecretPasswordKey" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.existingSecretPasswordKey | default "user-password" -}}
{{- else -}}
{{- "user-password" -}}
{{- end -}}
{{- end -}}

{{/* Redis host */}}
{{- define "middleware.redisHost" -}}
{{- if .Values.externalRedis.enabled -}}
{{- .Values.externalRedis.host -}}
{{- else -}}
{{- printf "%s-redis" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Redis port */}}
{{- define "middleware.redisPort" -}}
{{- if .Values.externalRedis.enabled -}}
{{- .Values.externalRedis.port | toString -}}
{{- else -}}
{{- "6379" -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "middleware.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "middleware.fullname" .) -}}
{{- end -}}
{{- end -}}
{{/* Backup — S3 secret name */}}
{{- define "middleware.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "middleware.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "middleware.backupEnabled" -}}
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
{{- define "middleware.backupDbHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "middleware.dbHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database port */}}
{{- define "middleware.backupDbPort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "middleware.dbPort" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database name */}}
{{- define "middleware.backupDbName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "middleware.dbName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database username */}}
{{- define "middleware.backupDbUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "middleware.dbUser" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret name */}}
{{- define "middleware.backupDbPasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "middleware.dbSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret key */}}
{{- define "middleware.backupDbPasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "middleware.dbSecretPasswordKey" . -}}
{{- end -}}
{{- end -}}
