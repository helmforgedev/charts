{{- define "uptime-kuma.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uptime-kuma.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "uptime-kuma.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "uptime-kuma.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uptime-kuma.labels" -}}
helm.sh/chart: {{ include "uptime-kuma.chart" . }}
{{ include "uptime-kuma.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "uptime-kuma.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uptime-kuma.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "uptime-kuma.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "uptime-kuma.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "uptime-kuma.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Database type */}}
{{- define "uptime-kuma.dbType" -}}
{{- .Values.database.type | default "sqlite" -}}
{{- end -}}

{{/* Database host */}}
{{- define "uptime-kuma.dbHost" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "uptime-kuma.dbPort" -}}
{{- if .Values.mysql.enabled -}}
{{- "3306" -}}
{{- else -}}
{{- .Values.database.external.port | default "3306" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "uptime-kuma.dbName" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.database | default "uptime_kuma" -}}
{{- else -}}
{{- .Values.database.external.name | default "uptime_kuma" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "uptime-kuma.dbUsername" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.username | default "uptime_kuma" -}}
{{- else -}}
{{- .Values.database.external.username | default "uptime_kuma" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name */}}
{{- define "uptime-kuma.dbSecretName" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "uptime-kuma.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "uptime-kuma.dbSecretPasswordKey" -}}
{{- if .Values.mysql.enabled -}}
{{- "mysql-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "uptime-kuma.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "uptime-kuma.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup S3 secret name */}}
{{- define "uptime-kuma.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup-s3" (include "uptime-kuma.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "uptime-kuma.backupSecretAccessKeyKey" -}}
{{- .Values.backup.s3.existingSecretAccessKeyKey | default "access-key" -}}
{{- end -}}

{{- define "uptime-kuma.backupSecretSecretKeyKey" -}}
{{- .Values.backup.s3.existingSecretSecretKeyKey | default "secret-key" -}}
{{- end -}}
