{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "openclaw.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "openclaw.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "openclaw.name" .) | trunc 63 | trimSuffix "-" }}{{- end }}
{{- end }}
{{- define "openclaw.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "openclaw.labels" -}}
{{ include "openclaw.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "openclaw.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end }}
{{- define "openclaw.authSecret" -}}{{ default (printf "%s-auth" (include "openclaw.fullname" .)) .Values.auth.existingSecret }}{{- end }}
{{- define "openclaw.claim" -}}{{ default (printf "%s-data" (include "openclaw.fullname" .)) .Values.persistence.existingClaim }}{{- end }}
{{- define "openclaw.serviceAccount" -}}
{{- if .Values.serviceAccount.create }}{{ default (include "openclaw.fullname" .) .Values.serviceAccount.name }}{{ else }}{{ default "default" .Values.serviceAccount.name }}{{ end }}
{{- end }}
{{- define "openclaw.httpRouteName" -}}
{{- $suffix := .route.name | default (printf "route-%v" .index) }}
{{- $complete := printf "%s-%s" (include "openclaw.fullname" .root) $suffix }}
{{- printf "%s-%s" ($complete | trunc 54 | trimSuffix "-") ($complete | sha256sum | trunc 8) }}
{{- end }}
{{- define "openclaw.externalSecretName" -}}
{{- default (printf "%s-%s" (include "openclaw.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "external" | trunc 22 | trimSuffix "-")) .item.fullnameOverride }}
{{- end }}
{{- define "openclaw.validate" -}}
{{- $routeNames := dict }}
{{- range $index, $route := .Values.gatewayAPI.httpRoutes }}
{{- $name := $route.name | default (printf "route-%v" $index) }}
{{- if hasKey $routeNames $name }}{{ fail (printf "gatewayAPI.httpRoutes contains duplicate effective name: %s" $name) }}{{- end }}
{{- $_ := set $routeNames $name true }}
{{- end }}
{{- if and .Values.networkPolicy.enabled (or .Values.ingress.enabled .Values.gatewayAPI.enabled) (empty .Values.networkPolicy.ingressFrom) }}{{ fail "remote ingress with NetworkPolicy requires networkPolicy.ingressFrom" }}{{- end }}
{{- if and .Values.networkPolicy.enabled .Values.metrics.serviceMonitor.enabled (empty .Values.metrics.ingressFrom) }}{{ fail "ServiceMonitor with NetworkPolicy requires metrics.ingressFrom" }}{{- end }}
{{- range $key := list "workspace" "model" "maxConcurrent" }}
{{- if hasKey $.Values.agent.defaults $key }}{{ fail (printf "agent.defaults.%s is reserved; use the explicit agent values" $key) }}{{- end }}
{{- end }}
{{- range $id, $agent := .Values.agent.entries }}
{{- range $key := list "workspace" "agentDir" }}
{{- $path := get $agent $key | default "" }}
{{- if and $path (or (not (hasPrefix "/home/node/" $path)) (contains ".." $path)) }}{{ fail (printf "agent.entries.%s.%s must stay inside /home/node" $id $key) }}{{- end }}
{{- end }}
{{- end }}
{{- if and .Values.persistence.existingClaim (not .Values.persistence.enabled) }}{{ fail "persistence.existingClaim requires persistence.enabled" }}{{- end }}
{{- if or (has "IPv6" .Values.service.ipFamilies) (eq .Values.service.ipFamilyPolicy "RequireDualStack") }}{{ fail "OpenClaw's official gateway currently binds IPv4 only; use IPv4 SingleStack" }}{{- end }}
{{- range $key := list "gateway" "agents" "tools" "channels" "diagnostics" "plugins" }}
{{- if hasKey $.Values.config.values $key }}{{ fail (printf "config.values.%s is chart-owned; use the explicit values contract" $key) }}{{- end }}
{{- end }}
{{- if and (or .Values.ingress.enabled .Values.gatewayAPI.enabled) (empty .Values.gateway.controlUi.allowedOrigins) }}{{ fail "remote access requires explicit gateway.controlUi.allowedOrigins" }}{{- end }}
{{- range .Values.gateway.controlUi.allowedOrigins }}{{- if contains "*" . }}{{ fail "wildcard Control UI origins are forbidden" }}{{- end }}{{- end }}
{{- range .Values.gateway.trustedProxies }}{{- if has . (list "0.0.0.0/0" "::/0") }}{{ fail "trustedProxies must identify actual reverse proxies" }}{{- end }}{{- end }}
{{- range $name, $channel := .Values.channels }}
{{- if and $channel.enabled (or (empty $channel.allowFrom) (empty $.Values.credentials.existingSecret)) }}{{ fail (printf "channels.%s requires allowFrom and credentials.existingSecret" $name) }}{{- end }}
{{- end }}
{{- if and .Values.metrics.enabled (not .Values.metrics.collector.enabled) (empty .Values.metrics.externalEndpoint) }}{{ fail "external metrics require metrics.externalEndpoint" }}{{- end }}
{{- if and (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) (not (and .Values.metrics.enabled .Values.metrics.collector.enabled)) }}{{ fail "Prometheus integration requires metrics.enabled and metrics.collector.enabled" }}{{- end }}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) }}{{ fail "gatewayAPI.enabled requires httpRoutes" }}{{- end }}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) }}{{ fail "externalSecrets.enabled requires items" }}{{- end }}
{{- if or .Values.backup.enabled .Values.restore.enabled }}
{{- if or (not .Values.persistence.enabled) (empty .Values.backup.s3.bucket) (empty .Values.backup.s3.existingSecret) }}{{ fail "backup/restore requires persistent storage, backup.s3.bucket and backup.s3.existingSecret" }}{{- end }}
{{- if and .Values.backup.enabled (has "ReadWriteOncePod" .Values.persistence.accessModes) }}{{ fail "backup requires RWO or RWX, not ReadWriteOncePod" }}{{- end }}
{{- if and (hasPrefix "http://" .Values.backup.s3.endpoint) (not .Values.backup.s3.allowInsecureEndpoint) }}{{ fail "HTTP S3 requires explicit backup.s3.allowInsecureEndpoint" }}{{- end }}
{{- if and (eq .Values.backup.s3.sse "aws:kms") (empty .Values.backup.s3.kmsKeyId) }}{{ fail "aws:kms requires backup.s3.kmsKeyId" }}{{- end }}
{{- end }}
{{- if and .Values.restore.enabled (empty .Values.restore.manifestKey) }}{{ fail "restore.enabled requires restore.manifestKey" }}{{- end }}
{{- range .Values.extraEnv }}
{{- if or (hasPrefix "OPENCLAW_" .name) (has .name (list "HOME" "NODE_OPTIONS" "NODE_ENV" "DO_NOT_TRACK" "CONFIG_POLICY")) }}{{ fail (printf "extraEnv.%s conflicts with the chart runtime contract" .name) }}{{- end }}
{{- end }}
{{- end }}
