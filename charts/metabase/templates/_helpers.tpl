{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "metabase.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "metabase.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "metabase.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "metabase.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "metabase.labels" -}}
helm.sh/chart: {{ include "metabase.chart" . }}
{{ include "metabase.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "metabase.selectorLabels" -}}
app.kubernetes.io/name: {{ include "metabase.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "metabase.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "metabase.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "metabase.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Database host */}}
{{- define "metabase.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "metabase.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "metabase.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "metabase" -}}
{{- else -}}
{{- .Values.database.external.name | default "metabase" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "metabase.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "metabase" -}}
{{- else -}}
{{- .Values.database.external.username | default "metabase" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "metabase.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "metabase.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "metabase.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- "user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Backup — S3 secret name */}}
{{- define "metabase.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "metabase.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "metabase.backupEnabled" -}}
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
{{- define "metabase.backupDbHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "metabase.dbHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database port */}}
{{- define "metabase.backupDbPort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "metabase.dbPort" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database name */}}
{{- define "metabase.backupDbName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "metabase.dbName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database username */}}
{{- define "metabase.backupDbUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "metabase.dbUsername" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret name */}}
{{- define "metabase.backupDbPasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "metabase.dbSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret key */}}
{{- define "metabase.backupDbPasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "metabase.dbSecretPasswordKey" . -}}
{{- end -}}
{{- end -}}

{{/* Encryption secret name */}}
{{- define "metabase.encryptionSecretName" -}}
{{- if .Values.metabase.existingSecret -}}
{{- .Values.metabase.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "metabase.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Encryption secret key */}}
{{- define "metabase.encryptionSecretKey" -}}
{{- if .Values.metabase.existingSecret -}}
{{- .Values.metabase.existingSecretKey | default "encryption-secret-key" -}}
{{- else -}}
{{- "encryption-secret-key" -}}
{{- end -}}
{{- end -}}
