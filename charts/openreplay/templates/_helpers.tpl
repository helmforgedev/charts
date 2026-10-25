{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "openreplay.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openreplay.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "openreplay.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openreplay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openreplay.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "openreplay.labels" -}}
helm.sh/chart: {{ include "openreplay.chart" . }}
{{ include "openreplay.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "openreplay.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "openreplay.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "openreplay.nameWithSuffix" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (max 1 (sub 63 (len $suffix))) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openreplay.componentName" -}}
{{- include "openreplay.nameWithSuffix" (dict "base" (include "openreplay.fullname" .root) "suffix" (printf "-%s" .component)) -}}
{{- end -}}

{{- define "openreplay.credentialsSecretName" -}}
{{- default .Values.credentials.secretName .Values.credentials.existingSecret -}}
{{- end -}}

{{- define "openreplay.postgresqlHost" -}}
{{- default (printf "%s-postgresql" .Release.Name) .Values.database.postgresql.host -}}
{{- end -}}

{{- define "openreplay.redisHost" -}}
{{- default (printf "%s-redis-client" .Release.Name) .Values.database.redis.host -}}
{{- end -}}

{{- define "openreplay.clickhouseHost" -}}
{{- default (printf "%s-clickhouse" .Release.Name) .Values.database.clickhouse.host -}}
{{- end -}}

{{- define "openreplay.s3Endpoint" -}}
{{- if .Values.objectStorage.endpoint -}}
{{- .Values.objectStorage.endpoint -}}
{{- else -}}
{{- printf "%s-rustfs:%v" (include "openreplay.fullname" .) .Values.rustfs.service.ports.s3 -}}
{{- end -}}
{{- end -}}

{{- define "openreplay.scratchClaimName" -}}
{{- default (printf "%s-scratch" (include "openreplay.fullname" .)) .Values.scratch.existingClaim -}}
{{- end -}}

{{- define "openreplay.httpRouteName" -}}
{{- if .route.name -}}
{{- include "openreplay.nameWithSuffix" (dict "base" (include "openreplay.fullname" .root) "suffix" (printf "-%s" .route.name)) -}}
{{- else if gt (int .index) 0 -}}
{{- include "openreplay.nameWithSuffix" (dict "base" (include "openreplay.fullname" .root) "suffix" (printf "-%d" .index)) -}}
{{- else -}}
{{- include "openreplay.fullname" .root -}}
{{- end -}}
{{- end -}}

{{- define "openreplay.externalSecretName" -}}
{{- if .item.fullnameOverride -}}
{{- .item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .item.name -}}
{{- include "openreplay.nameWithSuffix" (dict "base" (include "openreplay.fullname" .root) "suffix" (printf "-%s" .item.name)) -}}
{{- else if gt (int .index) 0 -}}
{{- include "openreplay.nameWithSuffix" (dict "base" (include "openreplay.fullname" .root) "suffix" (printf "-%d" .index)) -}}
{{- else -}}
{{- include "openreplay.fullname" .root -}}
{{- end -}}
{{- end -}}

{{- define "openreplay.image" -}}
{{- printf "%s:%s@%s" .repository .tag .digest -}}
{{- end -}}

{{- define "openreplay.validate" -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled -}}
{{- fail "ingress.enabled and gatewayAPI.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}
{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.credentials.existingSecret) -}}
{{- fail "credentials.existingSecret must name the ExternalSecret target when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.scratch.ephemeral .Values.scratch.existingClaim -}}
{{- fail "scratch.ephemeral and scratch.existingClaim are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.rustfs.enabled .Values.objectStorage.endpoint -}}
{{- fail "rustfs.enabled and objectStorage.endpoint are mutually exclusive" -}}
{{- end -}}
{{- if not .Values.router.enabled -}}
{{- fail "router.enabled must remain true because public OpenReplay routes require the internal router" -}}
{{- end -}}
{{- if not .Values.openreplay.domain -}}
{{- fail "openreplay.domain is required" -}}
{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
{{- if not .Values.openreplay.allowUnsupportedArchitecture -}}
{{- $arch := get .Values.componentDefaults.nodeSelector "kubernetes.io/arch" -}}
{{- if ne $arch "amd64" -}}
{{- fail "componentDefaults.nodeSelector[kubernetes.io/arch] must be amd64 unless openreplay.allowUnsupportedArchitecture=true" -}}
{{- end -}}
{{- end -}}
{{- end -}}

