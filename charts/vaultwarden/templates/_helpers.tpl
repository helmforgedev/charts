{{- define "vaultwarden.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vaultwarden.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "vaultwarden.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vaultwarden.labels" -}}
helm.sh/chart: {{ include "vaultwarden.chart" . }}
{{ include "vaultwarden.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "vaultwarden.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vaultwarden.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "vaultwarden.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.smtpSecretName" -}}
{{- if .Values.smtp.existingSecret -}}
{{- .Values.smtp.existingSecret -}}
{{- else -}}
{{- printf "%s-smtp" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.adminEnabled" -}}
{{- if or .Values.admin.token .Values.admin.existingSecret -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.smtpPasswordEnabled" -}}
{{- if and .Values.smtp.enabled (or .Values.smtp.password .Values.smtp.existingSecret) -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.persistenceEnabled" -}}
{{- if .Values.data.persistence.enabled -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.persistenceClaimName" -}}
{{- if .Values.data.persistence.existingClaim -}}
{{- .Values.data.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.adminToken" -}}
{{- if .Values.admin.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- .Values.admin.token -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.smtpPassword" -}}
{{- if .Values.smtp.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- .Values.smtp.password -}}
{{- end -}}
{{- end -}}
