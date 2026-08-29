{{/* SPDX-License-Identifier: Apache-2.0 */}}

{{- define "matterbridge.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "matterbridge.fullname" -}}
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

{{- define "matterbridge.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "matterbridge.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matterbridge.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "matterbridge.labels" -}}
helm.sh/chart: {{ include "matterbridge.chart" . }}
{{ include "matterbridge.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "matterbridge.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "matterbridge.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "matterbridge.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "matterbridge.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "matterbridge.nameWithSuffix" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (max 1 (sub 63 (len $suffix))) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "matterbridge.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := int (.index | default 0) -}}
{{- if $route.name -}}
{{- include "matterbridge.nameWithSuffix" (dict "base" (include "matterbridge.fullname" $root) "suffix" (printf "-%s" $route.name)) -}}
{{- else if gt $index 0 -}}
{{- include "matterbridge.nameWithSuffix" (dict "base" (include "matterbridge.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "matterbridge.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "matterbridge.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- include "matterbridge.nameWithSuffix" (dict "base" (include "matterbridge.fullname" $root) "suffix" (printf "-%s" $item.name)) -}}
{{- else if gt $index 0 -}}
{{- include "matterbridge.nameWithSuffix" (dict "base" (include "matterbridge.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "matterbridge.nameWithSuffix" (dict "base" (include "matterbridge.fullname" $root) "suffix" "-external") -}}
{{- end -}}
{{- end -}}

{{- define "matterbridge.validate" -}}
{{- if hasKey .Values.commonLabels "app.kubernetes.io/name" -}}
{{- fail "commonLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey .Values.commonLabels "app.kubernetes.io/instance" -}}
{{- fail "commonLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount must be 1 because Matterbridge does not support shared-state replicas or active-active operation" -}}
{{- end -}}
{{- if has .Values.image.tag (list "latest" "stable" "main" "master" "edge" "dev") -}}
{{- fail "image.tag must be a pinned stable release tag" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}
{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- range .Values.gatewayAPI.httpRoutes | default list -}}
{{- if empty .parentRefs -}}
{{- fail "gatewayAPI.httpRoutes[].parentRefs must contain at least one parent reference" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.networkPolicy.enabled .Values.network.hostNetwork -}}
{{- fail "networkPolicy.enabled requires network.hostNetwork=false because host-network policy enforcement is CNI-dependent" -}}
{{- end -}}
{{- if and .Values.frontend.tls.enabled (empty .Values.frontend.tls.existingSecret) -}}
{{- fail "frontend.tls.existingSecret is required when frontend.tls.enabled=true" -}}
{{- end -}}
{{- if and (not .Values.persistence.enabled) .Values.persistence.existingClaim -}}
{{- fail "persistence.enabled must be true when persistence.existingClaim is set" -}}
{{- end -}}
{{- if lt (int .Values.matterbridge.matterPortRangeSize) 1 -}}
{{- fail "matterbridge.matterPortRangeSize must be at least 1" -}}
{{- end -}}
{{- if gt (int .Values.matterbridge.matterPortRangeSize) 100 -}}
{{- fail "matterbridge.matterPortRangeSize must not exceed 100" -}}
{{- end -}}
{{- $lastMatterPort := add (int .Values.matterbridge.matterPort) (sub (int .Values.matterbridge.matterPortRangeSize) 1) -}}
{{- if gt (int $lastMatterPort) 65535 -}}
{{- fail "matterbridge.matterPort plus matterPortRangeSize exceeds port 65535" -}}
{{- end -}}
{{- if and (ge (int .Values.frontend.port) (int .Values.matterbridge.matterPort)) (le (int .Values.frontend.port) (int $lastMatterPort)) -}}
{{- fail "frontend.port must not overlap the reserved Matter port range" -}}
{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
{{- end -}}
