{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "kubernetes-mcp-server.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "kubernetes-mcp-server.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "kubernetes-mcp-server.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "kubernetes-mcp-server.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "kubernetes-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubernetes-mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "kubernetes-mcp-server.labels" -}}
helm.sh/chart: {{ include "kubernetes-mcp-server.chart" . }}
{{ include "kubernetes-mcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "kubernetes-mcp-server.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "kubernetes-mcp-server.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "kubernetes-mcp-server.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
