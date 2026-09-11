{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "hermes-agent.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "hermes-agent.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "hermes-agent.name" .) | trunc 63 | trimSuffix "-" }}{{- end }}
{{- end }}
{{- define "hermes-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hermes-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "hermes-agent.labels" -}}
{{ include "hermes-agent.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "hermes-agent.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end }}
{{- define "hermes-agent.authSecret" -}}{{ default (printf "%s-auth" (include "hermes-agent.fullname" .)) .Values.auth.existingSecret }}{{- end }}
{{- define "hermes-agent.claim" -}}{{ default (printf "%s-data" (include "hermes-agent.fullname" .)) .Values.persistence.existingClaim }}{{- end }}
{{- define "hermes-agent.serviceAccount" -}}
{{- if .Values.serviceAccount.create }}{{ default (include "hermes-agent.fullname" .) .Values.serviceAccount.name }}{{ else }}{{ default "default" .Values.serviceAccount.name }}{{ end }}
{{- end }}
{{- define "hermes-agent.httpRouteName" -}}
{{- $suffix := .route.name | default (printf "route-%v" .index) }}
{{- printf "%s-%s" (include "hermes-agent.fullname" .root | trunc 40 | trimSuffix "-") ($suffix | trunc 22 | trimSuffix "-") }}
{{- end }}
{{- define "hermes-agent.externalSecretName" -}}
{{- default (printf "%s-%s" (include "hermes-agent.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "external" | trunc 22 | trimSuffix "-")) .item.fullnameOverride }}
{{- end }}
{{- define "hermes-agent.validate" -}}
{{- if not .Values.agent.model }}{{ fail "agent.model is required" }}{{- end }}
{{- if and .Values.persistence.existingClaim (not .Values.persistence.enabled) }}{{ fail "persistence.existingClaim requires persistence.enabled=true" }}{{- end }}
{{- if hasKey .Values.config.values "platforms" }}{{ fail "config.values.platforms is reserved for the chart's authenticated gateway contract" }}{{- end }}
{{- if hasKey .Values.config.values "platform_toolsets" }}{{ fail "configure agent.toolsets instead of config.values.platform_toolsets" }}{{- end }}
{{- range $name, $channel := .Values.channels }}
{{- if and $channel.enabled (or (empty $channel.allowedUsers) (empty $.Values.credentials.existingSecret)) }}{{ fail (printf "channels.%s requires allowedUsers and credentials.existingSecret" $name) }}{{- end }}
{{- end }}
{{- if and .Values.dashboard.enabled (or (ne .Values.config.policy "seed") (empty .Values.dashboard.existingSecret)) }}{{ fail "dashboard.enabled requires config.policy=seed and dashboard.existingSecret" }}{{- end }}
{{- if and .Values.agent.apiKeyEnv (or (not (hasPrefix "custom:" .Values.agent.provider)) (empty .Values.agent.baseUrl)) }}{{ fail "agent.apiKeyEnv requires a custom:<name> provider and agent.baseUrl" }}{{- end }}
{{- if and .Values.agent.apiKeyEnv (not (hasPrefix "https://" .Values.agent.baseUrl)) (not (and .Values.agent.allowInsecureHTTP (hasPrefix "http://" .Values.agent.baseUrl))) }}{{ fail "credentialed custom providers require HTTPS; agent.allowInsecureHTTP is an explicit trusted-network exception" }}{{- end }}
{{- if and .Values.metrics.enabled (not .Values.metrics.collector.enabled) (empty .Values.metrics.externalEndpoint) }}{{ fail "metrics.externalEndpoint is required without the local collector" }}{{- end }}
{{- if and (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) (not (and .Values.metrics.enabled .Values.metrics.collector.enabled)) }}{{ fail "Prometheus integration requires metrics.enabled and metrics.collector.enabled" }}{{- end }}
{{- if and (hasKey .Values.config.values "monitoring") .Values.metrics.enabled }}{{ fail "metrics.enabled owns config.values.monitoring; configure metrics values instead" }}{{- end }}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) }}{{ fail "gatewayAPI.enabled requires httpRoutes" }}{{- end }}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) }}{{ fail "externalSecrets.enabled requires items" }}{{- end }}
{{- if or .Values.backup.enabled .Values.restore.enabled }}
{{- if or (not .Values.persistence.enabled) (empty .Values.backup.s3.bucket) (empty .Values.backup.s3.existingSecret) }}{{ fail "backup/restore requires persistence.enabled, backup.s3.bucket and backup.s3.existingSecret" }}{{- end }}
{{- if and .Values.backup.enabled (has "ReadWriteOncePod" .Values.persistence.accessModes) }}{{ fail "backup requires a concurrently mountable RWO or RWX claim, not ReadWriteOncePod" }}{{- end }}
{{- if and (hasPrefix "http://" .Values.backup.s3.endpoint) (not .Values.backup.s3.allowInsecureEndpoint) }}{{ fail "HTTP S3 endpoints require backup.s3.allowInsecureEndpoint=true" }}{{- end }}
{{- if and (eq .Values.backup.s3.sse "aws:kms") (empty .Values.backup.s3.kmsKeyId) }}{{ fail "backup.s3.sse=aws:kms requires kmsKeyId" }}{{- end }}
{{- end }}
{{- if and .Values.restore.enabled (empty .Values.restore.manifestKey) }}{{ fail "restore.enabled requires restore.manifestKey" }}{{- end }}
{{- range .Values.extraEnv }}
{{- if or (has .name (list "HOME" "HERMES_HOME" "API_SERVER_KEY" "HERMES_DISABLE_LAZY_INSTALLS" "PYTHONDONTWRITEBYTECODE")) (hasSuffix "ALLOW_ALL_USERS" .name) (hasSuffix "ALLOWED_USERS" .name) }}{{ fail (printf "extraEnv name %s is owned by chart identity/access controls" .name) }}{{- end }}
{{- end }}
{{- end }}
{{- define "hermes-agent.bindHost" -}}{{ ternary "" "0.0.0.0" (or (has "IPv6" .Values.service.ipFamilies) (eq .Values.service.ipFamilyPolicy "RequireDualStack") (eq .Values.service.ipFamilyPolicy "PreferDualStack")) }}{{- end }}
{{- define "hermes-agent.config" -}}
{{- $model := dict "default" .Values.agent.model "provider" .Values.agent.provider }}
{{- if .Values.agent.baseUrl }}{{ $_ := set $model "base_url" .Values.agent.baseUrl }}{{- end }}
{{- $base := dict "model" $model "agent" (dict "max_turns" .Values.agent.maxIterations) "database" (dict "journal_mode" "wal" "synchronous" "FULL") "terminal" (dict "backend" "local" "cwd" "/opt/data/workspace") }}
{{- $cfg := mergeOverwrite $base (deepCopy .Values.config.values) }}
{{- if .Values.agent.apiKeyEnv }}
{{- $providers := get $cfg "providers" | default dict }}
{{- $_ := set $providers (trimPrefix "custom:" .Values.agent.provider) (dict "base_url" .Values.agent.baseUrl "api_mode" "chat_completions" "key_env" .Values.agent.apiKeyEnv) }}
{{- $_ := set $cfg "providers" $providers }}
{{- end }}
{{- $bind := include "hermes-agent.bindHost" . }}
{{- $platforms := dict "api_server" (dict "enabled" true "extra" (dict "host" $bind "port" 8642)) }}
{{- $toolsets := dict "api_server" .Values.agent.toolsets }}
{{- range $name, $channel := .Values.channels }}
{{- $_ := set $platforms $name (dict "enabled" $channel.enabled) }}
{{- $_ := set $toolsets $name $channel.toolsets }}
{{- end }}
{{- $_ := set $cfg "platforms" $platforms }}
{{- $_ := set $cfg "platform_toolsets" $toolsets }}
{{- if .Values.dashboard.publicUrl }}
{{- $dashboard := get $cfg "dashboard" | default dict }}
{{- $_ := set $dashboard "public_url" .Values.dashboard.publicUrl }}
{{- $_ := set $cfg "dashboard" $dashboard }}
{{- end }}
{{- if .Values.metrics.enabled }}
{{- $endpoint := ternary "http://127.0.0.1:4318/v1/metrics" .Values.metrics.externalEndpoint .Values.metrics.collector.enabled }}
{{- $_ := set $cfg "monitoring" (dict "gateway_health_export" (dict "enabled" true "metrics_enabled" true "diagnostic_events_enabled" false "warning_error_events_enabled" false "export_interval_seconds" .Values.metrics.intervalSeconds) "export" (dict "otlp" (dict "enabled" true "endpoint" $endpoint "headers_env" dict))) }}
{{- end }}
{{- toYaml $cfg }}
{{- end }}
