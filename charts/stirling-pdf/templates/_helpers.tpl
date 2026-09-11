{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "stirling-pdf.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "stirling-pdf.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "stirling-pdf.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "stirling-pdf.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "stirling-pdf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stirling-pdf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "stirling-pdf.labels" -}}
helm.sh/chart: {{ include "stirling-pdf.chart" . }}
{{ include "stirling-pdf.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "stirling-pdf.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "stirling-pdf.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "stirling-pdf.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "stirling-pdf.authSecretName" -}}{{- default (printf "%s-auth" (include "stirling-pdf.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "stirling-pdf.claimName" -}}{{- default (include "stirling-pdf.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "stirling-pdf.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "stirling-pdf.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "stirling-pdf.validate" -}}
{{- if and .Values.metrics.enabled (eq (int .Values.metrics.port) (int .Values.server.port)) -}}{{ fail "metrics.port must differ from server.port" }}{{- end -}}
{{- if and .Values.metrics.scrapeConfig.enabled (not (and .Values.metrics.enabled .Values.metrics.scrapeConfig.apiKeySecret)) -}}{{ fail "metrics.scrapeConfig requires metrics.enabled and apiKeySecret" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if hasPrefix "MANAGEMENT_" .name -}}{{ fail "Use metrics values instead of MANAGEMENT_ overrides" }}{{- end -}}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Stirling PDF Community requires exactly one writer and Recreate upgrades" }}{{- end -}}
{{- if and .Values.auth.existingSecret .Values.auth.password -}}{{ fail "auth.existingSecret and auth.password are mutually exclusive" }}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{ fail "ingress.hosts is required when enabled" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must be non-empty when enabled" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (hasPrefix "SECURITY_" .name) (has .name (list "SERVER_PORT" "SYSTEM_ROOTURIPATH" "SYSTEM_ENABLEANALYTICS" "SYSTEM_ENABLEPOSTHOG" "STORAGE_ENABLED" "JAVA_CUSTOM_OPTS" "SPRING_DATASOURCE_URL" "SYSTEM_DATASOURCE_ENABLECUSTOMDATABASE" "SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE" "SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE" "SYSTEM_CONNECTIONTIMEOUTMILLISECONDS")) -}}{{ fail (printf "extraEnv cannot override chart-managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}

{{- define "stirling-pdf.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "stirling-pdf.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "stirling-pdf.fullname" .root }}{{- end -}}
{{- end -}}
