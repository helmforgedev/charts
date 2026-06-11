{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "qdrant.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "qdrant.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "qdrant.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "qdrant.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "qdrant.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qdrant.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "qdrant.labels" -}}
helm.sh/chart: {{ include "qdrant.chart" . }}
{{ include "qdrant.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "qdrant.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "qdrant.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "qdrant.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
