{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "apache.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "apache.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "apache.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "apache.selectorLabels" -}}
app.kubernetes.io/name: {{ include "apache.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "apache.labels" -}}
helm.sh/chart: {{ include "apache.chart" . }}
{{ include "apache.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "apache.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "apache.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "apache.configMapName" -}}
{{- printf "%s-config" (include "apache.fullname" .) -}}
{{- end -}}

{{- define "apache.contentConfigMapName" -}}
{{- if .Values.content.existingConfigMap -}}
{{- .Values.content.existingConfigMap -}}
{{- else -}}
{{- printf "%s-content" (include "apache.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "apache.basicAuthSecretName" -}}
{{- default (printf "%s-basicauth" (include "apache.fullname" .)) .Values.basicAuth.existingSecret -}}
{{- end -}}
