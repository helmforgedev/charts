{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ntfy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Validate chart values before rendering resources. */}}
{{- define "ntfy.validate" -}}
{{- if and .Values.ntfy.database.enabled (empty .Values.ntfy.database.existingSecret) -}}
{{- fail "ntfy.database.enabled requires ntfy.database.existingSecret" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- end -}}

{{- define "ntfy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ntfy.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ntfy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ntfy.labels" -}}
helm.sh/chart: {{ include "ntfy.chart" . }}
{{ include "ntfy.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ntfy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ntfy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ntfy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ntfy.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ntfy.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "ntfy.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "ntfy.fullname" .) -}}
{{- end -}}
{{- end -}}
