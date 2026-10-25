{{/* SPDX-License-Identifier: Apache-2.0 */}}
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
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "strava-statistics.configData" -}}
config.yaml: |
{{ .Values.strava.config | indent 2 }}
memory-limit.ini: |
  memory_limit = 4G
{{- end -}}

{{/* Dreeve runtime secret name and keys */}}
{{- define "strava-statistics.dreeveSecretName" -}}
{{- if .Values.dreeve.existingSecret -}}
{{- .Values.dreeve.existingSecret -}}
{{- else -}}
{{- printf "%s-dreeve" (include "strava-statistics.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.dreeveAppSecretKey" -}}
{{- if .Values.dreeve.existingSecret -}}
{{- .Values.dreeve.existingSecretAppSecretKey | default "app-secret" -}}
{{- else -}}
{{- "app-secret" -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.dreeveAdminPasswordHashKey" -}}
{{- if .Values.dreeve.existingSecret -}}
{{- .Values.dreeve.existingSecretAdminPasswordHashKey | default "admin-password-hash" -}}
{{- else -}}
{{- "admin-password-hash" -}}
{{- end -}}
{{- end -}}

{{- define "strava-statistics.dreeveApiKeyKey" -}}
{{- if .Values.dreeve.existingSecret -}}
{{- .Values.dreeve.existingSecretApiKeyKey | default "api-key" -}}
{{- else -}}
{{- "api-key" -}}
{{- end -}}
{{- end -}}

{{/* Shared Dreeve environment for the web and daemon containers. */}}
{{- define "strava-statistics.env" -}}
- name: APP_URL
  value: {{ .Values.dreeve.appUrl | quote }}
- name: IMPORT_MODE
  value: {{ .Values.dreeve.importMode | quote }}
- name: APP_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "strava-statistics.dreeveSecretName" . }}
      key: {{ include "strava-statistics.dreeveAppSecretKey" . }}
- name: ADMIN_USERNAME
  value: {{ .Values.dreeve.adminUsername | quote }}
- name: ADMIN_PASSWORD_HASH
  valueFrom:
    secretKeyRef:
      name: {{ include "strava-statistics.dreeveSecretName" . }}
      key: {{ include "strava-statistics.dreeveAdminPasswordHashKey" . }}
- name: DREEVE_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "strava-statistics.dreeveSecretName" . }}
      key: {{ include "strava-statistics.dreeveApiKeyKey" . }}
      optional: true
{{- if .Values.dreeve.adminAllowedIps }}
- name: ADMIN_ALLOWED_IPS
  value: {{ .Values.dreeve.adminAllowedIps | quote }}
{{- end }}
{{- if .Values.dreeve.trustedProxies }}
- name: TRUSTED_PROXIES
  value: {{ .Values.dreeve.trustedProxies | quote }}
{{- end }}
{{- if eq .Values.dreeve.importMode "stravaApi" }}
- name: STRAVA_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "strava-statistics.secretName" . }}
      key: {{ include "strava-statistics.clientIdKey" . }}
- name: STRAVA_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "strava-statistics.secretName" . }}
      key: {{ include "strava-statistics.clientSecretKey" . }}
- name: STRAVA_REFRESH_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "strava-statistics.secretName" . }}
      key: {{ include "strava-statistics.refreshTokenKey" . }}
{{- end }}
- name: TZ
  value: {{ .Values.strava.timezone | quote }}
{{- with .Values.strava.extraEnv }}
{{ toYaml . }}
{{- end }}
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

{{/*
Validation helper
*/}}
{{- define "strava-statistics.validate" -}}
{{- if and (eq .Values.dreeve.importMode "stravaApi") (not .Values.strava.existingSecret) -}}
  {{- if or (not .Values.strava.clientId) (not .Values.strava.clientSecret) (not .Values.strava.refreshToken) -}}
    {{- fail "strava-statistics: strava.existingSecret must be set or strava.clientId, strava.clientSecret, and strava.refreshToken must be provided" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
