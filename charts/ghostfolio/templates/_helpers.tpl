{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ghostfolio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ghostfolio.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "ghostfolio.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ghostfolio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ghostfolio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ghostfolio.labels" -}}
helm.sh/chart: {{ include "ghostfolio.chart" . }}
{{ include "ghostfolio.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ghostfolio.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ghostfolio.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "ghostfolio.waitImage" -}}
{{- printf "%s:%s" .Values.waitForServices.image.repository .Values.waitForServices.image.tag -}}
{{- end -}}

{{- define "ghostfolio.databaseHost" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- include "ghostfolio.databaseFullname" . -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.databaseFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.databasePort" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.port -}}
{{- else -}}5432{{- end -}}
{{- end -}}

{{- define "ghostfolio.databaseSecretName" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.existingSecret -}}
{{- else if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "ghostfolio.databaseFullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.databaseSecretKey" -}}
{{- default "user-password" .Values.postgresql.auth.existingSecretUserPasswordKey -}}
{{- end -}}

{{- define "ghostfolio.redisFullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.redisHost" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.host -}}
{{- else -}}
{{- printf "%s-client" (include "ghostfolio.redisFullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.redisPort" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.port -}}
{{- else -}}6379{{- end -}}
{{- end -}}

{{- define "ghostfolio.redisDatabase" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.database -}}
{{- else -}}0{{- end -}}
{{- end -}}

{{- define "ghostfolio.redisSecretName" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.existingSecret -}}
{{- else if .Values.redis.auth.existingSecret -}}
{{- .Values.redis.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "ghostfolio.redisFullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.redisSecretKey" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.passwordKey -}}
{{- else -}}{{ default "redis-password" .Values.redis.auth.existingSecretPasswordKey }}{{- end -}}
{{- end -}}

{{- define "ghostfolio.applicationSecretName" -}}
{{- default (printf "%s-application" (include "ghostfolio.fullname" .)) .Values.ghostfolio.existingSecret -}}
{{- end -}}

{{- define "ghostfolio.rootUrl" -}}
{{- if .Values.ghostfolio.rootUrl -}}
{{- .Values.ghostfolio.rootUrl -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- $scheme := ternary "https" "http" (gt (len .Values.ingress.tls) 0) -}}
{{- printf "%s://%s" $scheme (index .Values.ingress.hosts 0).host -}}
{{- else if and .Values.gatewayAPI.enabled (gt (len .Values.gatewayAPI.httpRoutes) 0) (gt (len ((index .Values.gatewayAPI.httpRoutes 0).hostnames | default list)) 0) -}}
{{- printf "%s://%s" .Values.gatewayAPI.rootUrlScheme (index (index .Values.gatewayAPI.httpRoutes 0).hostnames 0) -}}
{{- else -}}
{{- printf "http://%s.%s.svc:%v" (include "ghostfolio.fullname" .) .Release.Namespace .Values.service.port -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- printf "%s-%s" (include "ghostfolio.fullname" $root) $item.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- fail "externalSecrets.items[].name or fullnameOverride is required" -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.httpRouteName" -}}
{{- if .route.fullnameOverride -}}
{{- .route.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .route.name -}}
{{- printf "%s-%s" (include "ghostfolio.fullname" .root) .route.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%d" (include "ghostfolio.fullname" .root) .index | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghostfolio.validate" -}}
{{- if ne (int .Values.replicaCount) 1 }}{{ fail "ghostfolio: replicaCount must remain 1 because migrations, seed, and cron do not document distributed locking" }}{{ end -}}
{{- if and .Values.database.external.enabled .Values.postgresql.enabled }}{{ fail "ghostfolio: database.external.enabled and postgresql.enabled are mutually exclusive" }}{{ end -}}
{{- if and (not .Values.database.external.enabled) (not .Values.postgresql.enabled) }}{{ fail "ghostfolio: enable postgresql or configure database.external" }}{{ end -}}
{{- if .Values.database.external.enabled }}
{{- if not .Values.database.external.host }}{{ fail "ghostfolio: database.external.host is required" }}{{ end -}}
{{- if not .Values.database.external.existingSecret }}{{ fail "ghostfolio: database.external.existingSecret is required" }}{{ end -}}
{{- end -}}
{{- if and .Values.redis.external.enabled .Values.redis.enabled }}{{ fail "ghostfolio: redis.external.enabled and redis.enabled are mutually exclusive" }}{{ end -}}
{{- if and (not .Values.redis.external.enabled) (not .Values.redis.enabled) }}{{ fail "ghostfolio: enable redis or configure redis.external" }}{{ end -}}
{{- if .Values.redis.external.enabled }}
{{- if not .Values.redis.external.host }}{{ fail "ghostfolio: redis.external.host is required" }}{{ end -}}
{{- if not .Values.redis.external.existingSecret }}{{ fail "ghostfolio: redis.external.existingSecret is required" }}{{ end -}}
{{- end -}}
{{- if .Values.oidc.enabled }}
{{- if not .Values.oidc.issuer }}{{ fail "ghostfolio: oidc.issuer is required when OIDC is enabled" }}{{ end -}}
{{- if not .Values.oidc.clientId }}{{ fail "ghostfolio: oidc.clientId is required when OIDC is enabled" }}{{ end -}}
{{- if not .Values.oidc.existingSecret }}{{ fail "ghostfolio: oidc.existingSecret is required when OIDC is enabled" }}{{ end -}}
{{- end -}}
{{- if lt (int .Values.probes.readiness.timeoutSeconds) 5 }}{{ fail "ghostfolio: probes.readiness.timeoutSeconds must be at least 5 for the upstream Redis health check" }}{{ end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled }}{{ fail "ghostfolio: enable either ingress or gatewayAPI, not both" }}{{ end -}}
{{- end -}}
