{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "nautilus-trader.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "nautilus-trader.fullname" -}}
{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- end -}}{{- end -}}
{{- define "nautilus-trader.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "nautilus-trader.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nautilus-trader.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "nautilus-trader.labels" -}}
helm.sh/chart: {{ include "nautilus-trader.chart" . }}
{{ include "nautilus-trader.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "nautilus-trader.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{- default (include "nautilus-trader.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}
{{- define "nautilus-trader.nameWithSuffix" -}}
{{- $baseMax := int (max 1 (sub 63 (len .suffix))) -}}
{{- printf "%s%s" (.base | trunc $baseMax | trimSuffix "-") .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "nautilus-trader.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{- .item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- include "nautilus-trader.nameWithSuffix" (dict "base" (include "nautilus-trader.fullname" .root) "suffix" (printf "-%s" (.item.name | default "credentials"))) -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.postgresqlHost" -}}
{{- if .Values.postgresql.enabled -}}{{- include "postgresql.primaryServiceName" .Subcharts.postgresql -}}{{- else -}}{{- .Values.database.external.host -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.postgresqlSecret" -}}
{{- if .Values.postgresql.enabled -}}{{- include "postgresql.secretName" .Subcharts.postgresql -}}{{- else -}}{{- .Values.database.external.existingSecret -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.redisHost" -}}
{{- if .Values.redis.enabled -}}{{- include "redis.clientServiceName" .Subcharts.redis -}}{{- else -}}{{- .Values.messageBus.external.host -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.redisSecret" -}}
{{- if .Values.redis.enabled -}}{{- include "redis.secretName" .Subcharts.redis -}}{{- else -}}{{- .Values.messageBus.external.existingSecret -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.claimName" -}}
{{- $config := index .root.Values.persistence .kind -}}
{{- if $config.existingClaim -}}{{- $config.existingClaim -}}
{{- else -}}{{- include "nautilus-trader.nameWithSuffix" (dict "base" (include "nautilus-trader.fullname" .root) "suffix" (printf "-%s" (kebabcase .kind))) -}}{{- end -}}
{{- end -}}
{{- define "nautilus-trader.validate" -}}
{{- if and (eq .Values.live.mode "live") (not .Values.live.factory) (empty .Values.live.command) -}}{{- fail "live.factory is required when live.mode=live unless live.command overrides the chart runner" -}}{{- end -}}
{{- if and (not .Values.image.digest) (not .Values.image.tag) -}}{{- fail "image.tag or image.digest is required" -}}{{- end -}}
{{- if and .Values.postgresql.enabled (ne .Values.database.mode "postgresql") -}}{{- fail "database.mode must be postgresql when postgresql.enabled=true" -}}{{- end -}}
{{- if and (eq .Values.database.mode "postgresql") (not .Values.postgresql.enabled) -}}{{- fail "postgresql.enabled must be true when database.mode=postgresql" -}}{{- end -}}
{{- if and (eq .Values.database.mode "external") (not (and .Values.database.external.host .Values.database.external.existingSecret)) -}}{{- fail "external PostgreSQL requires database.external.host and database.external.existingSecret" -}}{{- end -}}
{{- if and .Values.redis.enabled (ne .Values.messageBus.mode "redis") -}}{{- fail "messageBus.mode must be redis when redis.enabled=true" -}}{{- end -}}
{{- if and (eq .Values.messageBus.mode "redis") (not .Values.redis.enabled) -}}{{- fail "redis.enabled must be true when messageBus.mode=redis" -}}{{- end -}}
{{- if and (eq .Values.messageBus.mode "external") (not (and .Values.messageBus.external.host .Values.messageBus.external.existingSecret)) -}}{{- fail "external Redis requires messageBus.external.host and messageBus.external.existingSecret" -}}{{- end -}}
{{- if eq (int .Values.messageBus.cacheDatabase) (int .Values.messageBus.busDatabase) -}}{{- fail "messageBus.cacheDatabase and messageBus.busDatabase must be different" -}}{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{- fail "podLabels must not override chart selector labels" -}}{{- end -}}{{- end -}}
{{- if and .Values.monitoring.prometheusRule.enabled (not .Values.monitoring.serviceMonitor.enabled) -}}{{- fail "monitoring.serviceMonitor.enabled must be true when prometheusRule is enabled" -}}{{- end -}}
{{- end -}}

