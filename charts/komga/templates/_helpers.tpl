{{- define "komga.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "komga.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "komga.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "komga.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "komga.labels" -}}
helm.sh/chart: {{ include "komga.chart" . }}
{{ include "komga.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "komga.selectorLabels" -}}
app.kubernetes.io/name: {{ include "komga.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "komga.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "komga.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "komga.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Config PVC claim name */}}
{{- define "komga.configClaimName" -}}
{{- if .Values.persistence.config.existingClaim -}}
{{- .Values.persistence.config.existingClaim -}}
{{- else -}}
{{- printf "%s-config" (include "komga.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "komga.dataClaimName" -}}
{{- if .Values.persistence.data.existingClaim -}}
{{- .Values.persistence.data.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "komga.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup S3 secret name */}}
{{- define "komga.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup-s3" (include "komga.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "komga.backupSecretAccessKeyKey" -}}
{{- .Values.backup.s3.existingSecretAccessKeyKey | default "access-key" -}}
{{- end -}}

{{- define "komga.backupSecretSecretKeyKey" -}}
{{- .Values.backup.s3.existingSecretSecretKeyKey | default "secret-key" -}}
{{- end -}}
