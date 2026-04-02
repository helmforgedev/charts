{{- define "archivebox.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "archivebox.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "archivebox.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "archivebox.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "archivebox.labels" -}}
helm.sh/chart: {{ include "archivebox.chart" . }}
{{ include "archivebox.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "archivebox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "archivebox.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "archivebox.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "archivebox.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "archivebox.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Admin secret name */}}
{{- define "archivebox.secretName" -}}
{{- if .Values.archivebox.existingSecret -}}
{{- .Values.archivebox.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "archivebox.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Admin secret keys */}}
{{- define "archivebox.usernameKey" -}}
{{- if .Values.archivebox.existingSecret -}}
{{- .Values.archivebox.existingSecretUsernameKey | default "admin-username" -}}
{{- else -}}
{{- "admin-username" -}}
{{- end -}}
{{- end -}}

{{- define "archivebox.passwordKey" -}}
{{- if .Values.archivebox.existingSecret -}}
{{- .Values.archivebox.existingSecretPasswordKey | default "admin-password" -}}
{{- else -}}
{{- "admin-password" -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "archivebox.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "archivebox.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup S3 secret name */}}
{{- define "archivebox.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "archivebox.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Validate backup configuration */}}
{{- define "archivebox.backupEnabled" -}}
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
