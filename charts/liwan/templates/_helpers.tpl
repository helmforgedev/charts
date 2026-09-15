{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "liwan.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "liwan.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "liwan.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "liwan.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "liwan.labels" -}}
helm.sh/chart: {{ include "liwan.chart" . }}
{{ include "liwan.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "liwan.selectorLabels" -}}
app.kubernetes.io/name: {{ include "liwan.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "liwan.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "liwan.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "liwan.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "liwan.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "liwan.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Reject the removed upstream proxy switch instead of silently ignoring it. */}}
{{- define "liwan.validate" -}}
{{- range .Values.liwan.extraEnv -}}
{{- if eq .name "LIWAN_USE_FORWARD_HEADERS" -}}
{{- fail "LIWAN_USE_FORWARD_HEADERS was removed in Liwan 1.7; configure LIWAN_TRUSTED_PROXIES and LIWAN_TRUSTED_HEADERS instead" -}}
{{- end -}}
{{- end -}}
{{- end -}}
