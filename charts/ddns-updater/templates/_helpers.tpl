{{- define "ddns-updater.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ddns-updater.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ddns-updater.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ddns-updater.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ddns-updater.labels" -}}
helm.sh/chart: {{ include "ddns-updater.chart" . }}
{{ include "ddns-updater.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ddns-updater.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ddns-updater.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ddns-updater.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ddns-updater.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ddns-updater.image" -}}
{{- $tag := .Values.image.tag | default (printf "v%s" .Chart.AppVersion) -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Config secret name */}}
{{- define "ddns-updater.configSecretName" -}}
{{- if .Values.config.existingSecret -}}
{{- .Values.config.existingSecret -}}
{{- else -}}
{{- printf "%s-config" (include "ddns-updater.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Config secret key */}}
{{- define "ddns-updater.configSecretKey" -}}
{{- .Values.config.existingSecretKey | default "config.json" -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "ddns-updater.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "ddns-updater.fullname" .) -}}
{{- end -}}
{{- end -}}
