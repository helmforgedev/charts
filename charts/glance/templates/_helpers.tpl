{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "glance.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "glance.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "glance.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "glance.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "glance.selectorLabels" -}}
app.kubernetes.io/name: {{ include "glance.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "glance.labels" -}}
helm.sh/chart: {{ include "glance.chart" . }}
{{ include "glance.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "glance.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "glance.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "glance.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "glance.authSecretName" -}}{{- default (printf "%s-auth" (include "glance.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "glance.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" (include "glance.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- define "glance.validate" -}}
{{- if or (hasKey .Values.config.data "auth") (hasKey .Values.config.data "server") -}}{{ fail "config.data auth and server are chart-managed; use auth and server values" }}{{- end -}}
{{- if not .Values.config.data.pages -}}{{ fail "config.data.pages must contain at least one dashboard page" }}{{- end -}}
{{- if and .Values.auth.enabled (not .Values.auth.username) -}}{{ fail "auth.username is required when authentication is enabled" }}{{- end -}}
{{- if and .Values.auth.secretKey (ne (len (.Values.auth.secretKey | b64dec)) 64) -}}{{ fail "auth.secretKey must encode exactly 64 random bytes in base64" }}{{- end -}}
{{- if and .Values.auth.existingSecret (or .Values.auth.password .Values.auth.secretKey) -}}{{ fail "auth.existingSecret cannot be combined with inline auth.password or auth.secretKey" }}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{ fail "ingress.hosts is required when ingress.enabled=true" }}{{- end -}}
{{- range .Values.ingress.hosts -}}{{- if not .host -}}{{ fail "ingress.hosts entries require a non-empty host" }}{{- end -}}{{- end -}}
{{- if and .Values.podDisruptionBudget.enabled (lt (int .Values.replicaCount) 2) -}}{{ fail "podDisruptionBudget.enabled requires at least two replicas" }}{{- end -}}
{{- if and .Values.podDisruptionBudget.enabled (ge (int .Values.podDisruptionBudget.maxUnavailable) (int .Values.replicaCount)) -}}{{ fail "podDisruptionBudget.maxUnavailable must be smaller than replicaCount" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must be non-empty when enabled" }}{{- end -}}
{{- range $labels := list .Values.podLabels .Values.commonLabels -}}
{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}
{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}

