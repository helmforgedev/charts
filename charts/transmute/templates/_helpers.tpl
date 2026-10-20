{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "transmute.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "transmute.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "transmute.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "transmute.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "transmute.selectorLabels" -}}
app.kubernetes.io/name: {{ include "transmute.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: app
{{- end -}}
{{- define "transmute.labels" -}}
helm.sh/chart: {{ include "transmute.chart" . }}
{{ include "transmute.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{ end }}
{{- end -}}
{{- define "transmute.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "transmute.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "transmute.image" -}}{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}{{- end -}}
{{- define "transmute.secretName" -}}{{- default (printf "%s-auth" (include "transmute.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "transmute.claimName" -}}{{- default (include "transmute.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
