{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "jupyterhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "jupyterhub.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- end -}}
{{- define "jupyterhub.chart" -}}{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "jupyterhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jupyterhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "jupyterhub.labels" -}}
helm.sh/chart: {{ include "jupyterhub.chart" . }}
{{ include "jupyterhub.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "jupyterhub.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ default (include "jupyterhub.fullname" .) .Values.serviceAccount.name }}{{- else }}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}
{{- define "jupyterhub.hubName" -}}{{ include "jupyterhub.fullname" . }}-hub{{- end -}}
{{- define "jupyterhub.proxyName" -}}{{ include "jupyterhub.fullname" . }}{{- end -}}
{{- define "jupyterhub.proxyApiName" -}}{{ include "jupyterhub.fullname" . }}-proxy-api{{- end -}}
{{- define "jupyterhub.hubDataClaimName" -}}
{{- if .Values.hub.persistence.existingClaim }}{{ .Values.hub.persistence.existingClaim }}{{- else }}{{ include "jupyterhub.hubName" . }}-data{{- end -}}
{{- end -}}
{{- define "jupyterhub.secretName" -}}
{{- if .Values.proxy.existingSecret }}{{ .Values.proxy.existingSecret }}{{- else }}{{ include "jupyterhub.fullname" . }}-proxy{{- end -}}
{{- end -}}
{{- define "jupyterhub.proxyToken" -}}
{{- if .Values.proxy.secretToken }}{{ .Values.proxy.secretToken }}{{- else if .Values.proxy.existingSecret }}{{ "" }}{{- else }}{{ randAlphaNum 64 }}{{- end -}}
{{- end -}}
