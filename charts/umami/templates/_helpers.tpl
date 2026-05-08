# SPDX-License-Identifier: Apache-2.0
{{- define "umami.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "umami.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "umami.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "umami.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "umami.labels" -}}
helm.sh/chart: {{ include "umami.chart" . }}
{{ include "umami.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "umami.selectorLabels" -}}
app.kubernetes.io/name: {{ include "umami.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "umami.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "umami.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "umami.componentLabels" -}}
{{ include "umami.selectorLabels" . }}
app.kubernetes.io/component: umami
{{- end -}}

{{- define "umami.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Database host */}}
{{- define "umami.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "umami.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "umami.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "umami" -}}
{{- else -}}
{{- .Values.database.external.name | default "umami" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "umami.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "umami" -}}
{{- else -}}
{{- .Values.database.external.username | default "umami" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "umami.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled .Values.externalSecrets.database.targetName -}}
{{- .Values.externalSecrets.database.targetName -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "umami.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "umami.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" -}}
{{- else if or .Values.database.external.existingSecret (and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled) -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* DATABASE_URL connection string */}}
{{- define "umami.databaseUrl" -}}
{{- printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%s/%s" (include "umami.dbUsername" .) (include "umami.dbHost" .) (include "umami.dbPort" .) (include "umami.dbName" .) -}}
{{- end -}}

{{/* App secret name */}}
{{- define "umami.appSecretName" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.app.enabled .Values.externalSecrets.app.targetName -}}
{{- .Values.externalSecrets.app.targetName -}}
{{- else if .Values.umami.existingSecret -}}
{{- .Values.umami.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "umami.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* App secret key */}}
{{- define "umami.appSecretKey" -}}
{{- if or .Values.umami.existingSecret (and .Values.externalSecrets.enabled .Values.externalSecrets.app.enabled) -}}
{{- .Values.umami.existingSecretKey | default "app-secret" -}}
{{- else -}}
{{- "app-secret" -}}
{{- end -}}
{{- end -}}

{{/* Backup — S3 secret name */}}
{{- define "umami.backupSecretName" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.backup.enabled .Values.externalSecrets.backup.targetName -}}
{{- .Values.externalSecrets.backup.targetName -}}
{{- else if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "umami.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "umami.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.accessKey) (not (and .Values.externalSecrets.enabled .Values.externalSecrets.backup.enabled)) -}}
    {{- fail "backup.s3.accessKey or backup.s3.existingSecret is required when backup.enabled is true" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{/* ExternalSecret data entry helper */}}
{{- define "umami.externalSecretDataItem" -}}
{{- if not .remoteRef.key -}}
{{- fail (printf "%s.key is required when the related ExternalSecret is enabled" .remoteRefName) -}}
{{- end -}}
- secretKey: {{ .secretKey | quote }}
  remoteRef:
    key: {{ .remoteRef.key | quote }}
    {{- with .remoteRef.property }}
    property: {{ . | quote }}
    {{- end }}
{{- end -}}

{{/* Validate External Secrets Operator values */}}
{{- define "umami.validateExternalSecrets" -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.database.enabled .Values.postgresql.enabled -}}
    {{- fail "externalSecrets.database.enabled requires postgresql.enabled=false" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* Validate external database preparation values */}}
{{- define "umami.validateExternalDbInit" -}}
{{- if .Values.database.external.init.enabled -}}
  {{- if .Values.postgresql.enabled -}}
    {{- fail "database.external.init.enabled requires postgresql.enabled=false" -}}
  {{- end -}}
  {{- if not .Values.database.external.init.adminExistingSecret -}}
    {{- fail "database.external.init.adminExistingSecret is required when database.external.init.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* Backup — database host */}}
{{- define "umami.backupDbHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "umami.dbHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database port */}}
{{- define "umami.backupDbPort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "umami.dbPort" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database name */}}
{{- define "umami.backupDbName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "umami.dbName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database username */}}
{{- define "umami.backupDbUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "umami.dbUsername" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret name */}}
{{- define "umami.backupDbPasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "umami.dbSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret key */}}
{{- define "umami.backupDbPasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "umami.dbSecretPasswordKey" . -}}
{{- end -}}
{{- end -}}
