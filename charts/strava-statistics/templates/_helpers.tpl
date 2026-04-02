{{- define "strava-statistics.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "strava-statistics.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "strava-statistics.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "strava-statistics.labels" -}}
helm.sh/chart: {{ include "strava-statistics.chart" . }}
{{ include "strava-statistics.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "strava-statistics.selectorLabels" -}}
app.kubernetes.io/name: {{ include "strava-statistics.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "strava-statistics.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "strava-statistics.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.image" -}}
{{- $tag := .Values.image.tag | default (printf "v%s" .Chart.AppVersion) -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Strava secret name */}}
{{- define "strava-statistics.secretName" -}}
{{- if .Values.strava.existingSecret -}}
{{- .Values.strava.existingSecret -}}
{{- else -}}
{{- printf "%s-strava" (include "strava-statistics.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Strava secret keys */}}
{{- define "strava-statistics.clientIdKey" -}}
{{- if .Values.strava.existingSecret -}}
{{- .Values.strava.existingSecretClientIdKey | default "client-id" -}}
{{- else -}}
{{- "client-id" -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.clientSecretKey" -}}
{{- if .Values.strava.existingSecret -}}
{{- .Values.strava.existingSecretClientSecretKey | default "client-secret" -}}
{{- else -}}
{{- "client-secret" -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.refreshTokenKey" -}}
{{- if .Values.strava.existingSecret -}}
{{- .Values.strava.existingSecretRefreshTokenKey | default "refresh-token" -}}
{{- else -}}
{{- "refresh-token" -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "strava-statistics.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "strava-statistics.fullname" .) -}}
{{- end -}}
{{- end -}}
