{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "openhab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openhab.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart label value.
*/}}
{{- define "openhab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openhab.labels" -}}
helm.sh/chart: {{ include "openhab.chart" . }}
{{ include "openhab.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openhab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openhab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openhab.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openhab.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate replicaCount - openHAB does not support clustering.
*/}}
{{- define "openhab.validateReplicaCount" -}}
{{- if gt (int .Values.replicaCount) 1 }}
{{- fail "openHAB does not support horizontal scaling. replicaCount MUST be 1. Running multiple replicas against the same persistent storage will corrupt data." }}
{{- end }}
{{- end }}

{{/*
Validate admin secret configuration.
*/}}
{{- define "openhab.validateAdmin" -}}
{{- if and .Values.admin.secretEnabled (not .Values.admin.password) (not .Values.admin.existingSecret) }}
{{- fail "admin.password is required when admin.secretEnabled is true and admin.existingSecret is not set." }}
{{- end }}
{{- end }}

{{/*
Resolve the admin secret name.
*/}}
{{- define "openhab.adminSecretName" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecret }}
{{- else }}
{{- printf "%s-admin" (include "openhab.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Resolve the userdata PVC name.
*/}}
{{- define "openhab.userdataPvcName" -}}
{{- if .Values.persistence.userdata.existingClaim }}
{{- .Values.persistence.userdata.existingClaim }}
{{- else }}
{{- printf "%s-userdata" (include "openhab.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Resolve the conf PVC name.
*/}}
{{- define "openhab.confPvcName" -}}
{{- if .Values.persistence.conf.existingClaim }}
{{- .Values.persistence.conf.existingClaim }}
{{- else }}
{{- printf "%s-conf" (include "openhab.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Resolve the addons PVC name.
*/}}
{{- define "openhab.addonsPvcName" -}}
{{- if .Values.persistence.addons.existingClaim }}
{{- .Values.persistence.addons.existingClaim }}
{{- else }}
{{- printf "%s-addons" (include "openhab.fullname" .) }}
{{- end }}
{{- end }}
