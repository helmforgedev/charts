{{- define "countly.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "countly.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "countly.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "countly.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "countly.labels" -}}
helm.sh/chart: {{ include "countly.chart" . }}
{{ include "countly.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "countly.selectorLabels" -}}
app.kubernetes.io/name: {{ include "countly.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "countly.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "countly.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "countly.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* MongoDB host */}}
{{- define "countly.mongodbHost" -}}
{{- if .Values.externalMongodb.enabled -}}
{{- "" -}}
{{- else -}}
{{- printf "%s-mongodb" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* MongoDB URI */}}
{{- define "countly.mongodbUri" -}}
{{- if .Values.externalMongodb.enabled -}}
{{- .Values.externalMongodb.uri -}}
{{- else -}}
{{- printf "mongodb://root:$(MONGODB_ROOT_PASSWORD)@%s-mongodb:27017/countly?authSource=admin" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* MongoDB secret name */}}
{{- define "countly.mongodbSecretName" -}}
{{- if .Values.externalMongodb.enabled -}}
{{- .Values.externalMongodb.existingSecret -}}
{{- else -}}
{{- printf "%s-mongodb" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Backup — S3 secret name */}}
{{- define "countly.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "countly.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "countly.backupEnabled" -}}
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

{{/* Backup — MongoDB URI (hardcoded password for non-interactive dump) */}}
{{- define "countly.backupMongodbUri" -}}
{{- if .Values.backup.database.uri -}}
{{- .Values.backup.database.uri -}}
{{- else if .Values.externalMongodb.enabled -}}
{{- .Values.externalMongodb.uri -}}
{{- else -}}
{{- printf "mongodb://root:$(MONGODB_ROOT_PASSWORD)@%s-mongodb:27017/countly?authSource=admin" .Release.Name -}}
{{- end -}}
{{- end -}}
