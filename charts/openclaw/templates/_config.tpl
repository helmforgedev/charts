{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "openclaw.config" -}}
{{- $cfg := deepCopy .Values.config.values }}
{{- $_ := set $cfg "gateway" (dict "mode" "local" "bind" "lan" "port" 18789 "auth" (dict "mode" "token") "trustedProxies" .Values.gateway.trustedProxies "controlUi" (dict "enabled" .Values.gateway.controlUi.enabled "allowedOrigins" .Values.gateway.controlUi.allowedOrigins) "http" (dict "endpoints" (dict "chatCompletions" .Values.gateway.chatCompletions "responses" .Values.gateway.responses))) }}
{{- $defaults := mergeOverwrite (deepCopy .Values.agent.defaults) (dict "workspace" "/home/node/.openclaw/workspace" "model" (dict "primary" .Values.agent.model) "maxConcurrent" .Values.agent.maxConcurrent) }}
{{- $agents := mergeOverwrite (dict "default" (dict "name" "OpenClaw" "workspace" "/home/node/.openclaw/workspace")) (deepCopy .Values.agent.entries) }}
{{- $_ := set $cfg "agents" (dict "defaults" $defaults "entries" $agents) }}
{{- $_ := set $cfg "tools" (dict "profile" .Values.agent.toolProfile "alsoAllow" .Values.agent.allowTools "deny" .Values.agent.denyTools "fs" (dict "workspaceOnly" true) "elevated" (dict "enabled" false)) }}
{{- $channels := dict }}
{{- range $name, $channel := .Values.channels }}
{{- $_ := set $channels $name (dict "enabled" $channel.enabled "dmPolicy" "allowlist" "allowFrom" $channel.allowFrom "groupPolicy" "disabled") }}
{{- end }}
{{- $_ := set $cfg "channels" $channels }}
{{- $plugins := list }}
{{- if .Values.channels.telegram.enabled }}{{- $plugins = append $plugins "telegram" }}{{- end }}
{{- if .Values.channels.discord.enabled }}{{- $plugins = append $plugins "discord" }}{{- end }}
{{- $entries := dict }}
{{- if .Values.metrics.enabled }}
{{- $plugins = append $plugins "diagnostics-otel" }}
{{- $_ := set $entries "diagnostics-otel" (dict "enabled" true) }}
{{- $endpoint := ternary "http://127.0.0.1:4318" .Values.metrics.externalEndpoint .Values.metrics.collector.enabled }}
{{- $_ := set $cfg "diagnostics" (dict "enabled" true "otel" (dict "enabled" true "endpoint" $endpoint "protocol" "http/protobuf" "serviceName" "openclaw-gateway" "metrics" true "traces" false "logs" false "captureContent" false "flushIntervalMs" (mul .Values.metrics.intervalSeconds 1000))) }}
{{- end }}
{{- $_ := set $cfg "plugins" (dict "allow" $plugins "entries" $entries) }}
{{- $_ := set $cfg "logging" (mergeOverwrite (dict "consoleStyle" "json") (get $cfg "logging" | default dict)) }}
{{- toPrettyJson $cfg }}
{{- end }}
