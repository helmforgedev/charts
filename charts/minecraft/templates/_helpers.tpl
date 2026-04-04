{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "minecraft.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "minecraft.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "minecraft.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "minecraft.labels" -}}
helm.sh/chart: {{ include "minecraft.chart" . }}
{{ include "minecraft.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: minecraft
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "minecraft.selectorLabels" -}}
app.kubernetes.io/name: {{ include "minecraft.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "minecraft.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "minecraft.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Secret name for RCON password.
*/}}
{{- define "minecraft.secretName" -}}
{{- if .Values.rcon.existingSecret }}
{{- .Values.rcon.existingSecret }}
{{- else }}
{{- include "minecraft.fullname" . }}
{{- end }}
{{- end }}

{{/*
Secret key for RCON password.
*/}}
{{- define "minecraft.secretKey" -}}
{{- if .Values.rcon.existingSecret }}
{{- .Values.rcon.existingSecretKey }}
{{- else }}
{{- print "rcon-password" }}
{{- end }}
{{- end }}

{{/*
Backup secret name for S3 credentials.
*/}}
{{- define "minecraft.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret }}
{{- .Values.backup.s3.existingSecret }}
{{- else }}
{{- printf "%s-backup" (include "minecraft.fullname" .) }}
{{- end }}
{{- end }}

{{/*
ConfigMap name for backup scripts.
*/}}
{{- define "minecraft.backupConfigMapName" -}}
{{- printf "%s-backup-scripts" (include "minecraft.fullname" .) }}
{{- end }}

{{/*
Validate backup configuration. Fails if required fields are missing.
*/}}
{{- define "minecraft.backupEnabled" -}}
{{- if .Values.backup.enabled }}
{{- if not .Values.backup.s3.endpoint }}
{{- fail "backup.s3.endpoint is required when backup is enabled" }}
{{- end }}
{{- if not .Values.backup.s3.bucket }}
{{- fail "backup.s3.bucket is required when backup is enabled" }}
{{- end }}
{{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.accessKey) }}
{{- fail "backup.s3.accessKey or backup.s3.existingSecret is required when backup is enabled" }}
{{- end }}
{{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.secretKey) }}
{{- fail "backup.s3.secretKey or backup.s3.existingSecret is required when backup is enabled" }}
{{- end }}
{{- if not .Values.persistence.enabled }}
{{- fail "persistence.enabled must be true when backup is enabled" }}
{{- end }}
{{- if not .Values.rcon.enabled }}
{{- fail "rcon.enabled must be true when backup is enabled (required for save coordination)" }}
{{- end }}
true
{{- end }}
{{- end }}

{{/*
Image string with tag fallback to appVersion.
*/}}
{{- define "minecraft.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
