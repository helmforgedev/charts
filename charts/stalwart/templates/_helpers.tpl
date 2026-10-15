{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "stalwart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "stalwart.fullname" -}}
{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- $name := default .Chart.Name .Values.nameOverride -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- end -}}
{{- define "stalwart.chart" -}}{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "stalwart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stalwart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "stalwart.labels" -}}
helm.sh/chart: {{ include "stalwart.chart" . }}
{{ include "stalwart.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "stalwart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{- default (include "stalwart.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}
{{- end -}}
{{- define "stalwart.configName" -}}
{{- if eq .Values.config.source "existingConfigMap" -}}{{ .Values.config.existingConfigMap.name }}{{- else if eq .Values.config.source "existingSecret" -}}{{ .Values.config.existingSecret.name }}{{- else -}}{{ include "stalwart.fullname" . }}-config{{- end -}}
{{- end -}}
{{- define "stalwart.configKey" -}}
{{- if eq .Values.config.source "existingConfigMap" -}}{{ .Values.config.existingConfigMap.key }}{{- else if eq .Values.config.source "existingSecret" -}}{{ .Values.config.existingSecret.key }}{{- else -}}config.json{{- end -}}
{{- end -}}
{{- define "stalwart.httpServiceName" -}}{{ include "stalwart.fullname" . }}-http{{- end -}}
{{- define "stalwart.mailServiceName" -}}{{ include "stalwart.fullname" . }}-mail{{- end -}}
{{- define "stalwart.headlessServiceName" -}}{{ include "stalwart.fullname" . }}-headless{{- end -}}
{{- define "stalwart.servicePort" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $service := .service -}}
{{- $port := get $root.Values.ports $name -}}
{{- if and $port (not $port.enabled) -}}{{- $port = "" -}}{{- end -}}
{{- if not $port -}}
{{- range $candidate := $root.Values.extraPorts -}}
{{- if eq $candidate.name $name -}}{{- $port = $candidate -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- if not $port -}}{{- fail (printf "gateway route backendPort %q does not match an enabled built-in port or extraPorts entry" $name) -}}{{- end -}}
{{- if ne $port.service $service -}}{{- fail (printf "gateway route backendPort %q belongs to the %s service, not %s" $name $port.service $service) -}}{{- end -}}
{{- $port.servicePort -}}
{{- end -}}
{{- define "stalwart.routeName" -}}
{{- $root := .root -}}{{- $route := .route -}}{{- $kind := .kind -}}{{- $index := int .index -}}
{{- if $route.name -}}{{ printf "%s-%s" (include "stalwart.fullname" $root) $route.name | trunc 63 | trimSuffix "-" }}{{- else if gt $index 0 -}}{{ printf "%s-%s-%d" (include "stalwart.fullname" $root) $kind $index | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "stalwart.fullname" $root) $kind | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- define "stalwart.externalSecretName" -}}
{{- $root := .root -}}{{- $item := .item -}}{{- $index := int .index -}}
{{- if $item.fullnameOverride -}}{{ $item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else if $item.name -}}{{ printf "%s-%s" (include "stalwart.fullname" $root) $item.name | trunc 63 | trimSuffix "-" }}{{- else if gt $index 0 -}}{{ printf "%s-%d" (include "stalwart.fullname" $root) $index | trunc 63 | trimSuffix "-" }}{{- else -}}{{ include "stalwart.fullname" $root }}{{- end -}}
{{- end -}}
{{- define "stalwart.validate" -}}
{{- if hasKey .Values.commonLabels "app.kubernetes.io/name" -}}{{ fail "commonLabels must not override the selector label app.kubernetes.io/name" }}{{- end -}}
{{- if hasKey .Values.commonLabels "app.kubernetes.io/instance" -}}{{ fail "commonLabels must not override the selector label app.kubernetes.io/instance" }}{{- end -}}
{{- if eq .Values.image.tag "latest" -}}{{ fail "image.tag must be a pinned stable release tag" }}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{ fail "ingress.hosts must contain at least one host when ingress.enabled=true" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" }}{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.persistence.enabled -}}{{ fail "replicaCount > 1 requires persistence.enabled=false and an external shared DataStore" }}{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (eq .Values.config.source "generated") -}}
{{- $kind := lower (get .Values.config.dataStore "@type") -}}
{{- if or (eq $kind "rocksdb") (eq $kind "sqlite") -}}{{ fail "replicaCount > 1 requires an external shared DataStore; RocksDb and Sqlite are single-node backends" }}{{- end -}}
{{- end -}}
{{- if and (eq .Values.config.source "existingConfigMap") (empty .Values.config.existingConfigMap.name) -}}{{ fail "config.existingConfigMap.name is required when config.source=existingConfigMap" }}{{- end -}}
{{- if and (eq .Values.config.source "existingSecret") (empty .Values.config.existingSecret.name) -}}{{ fail "config.existingSecret.name is required when config.source=existingSecret" }}{{- end -}}
{{- if and .Values.applyJob.enabled (eq .Values.applyJob.plan.source "existingConfigMap") (empty .Values.applyJob.plan.existingConfigMap) -}}{{ fail "applyJob.plan.existingConfigMap is required when applyJob is enabled with an existingConfigMap plan" }}{{- end -}}
{{- if and .Values.applyJob.enabled (eq .Values.applyJob.plan.source "existingSecret") (empty .Values.applyJob.plan.existingSecret) -}}{{ fail "applyJob.plan.existingSecret is required when applyJob is enabled with an existingSecret plan" }}{{- end -}}
{{- if .Values.podLabels -}}{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{ fail "podLabels must not override the selector label app.kubernetes.io/name" }}{{- end -}}{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{ fail "podLabels must not override the selector label app.kubernetes.io/instance" }}{{- end -}}{{- end -}}
{{- $names := dict -}}
{{- range $name, $port := .Values.ports -}}{{- if $port.enabled -}}{{- $_ := set $names $name true -}}{{- end -}}{{- end -}}
{{- range .Values.extraPorts -}}{{- if hasKey $names .name -}}{{ fail (printf "extraPorts contains duplicate port name %q" .name) }}{{- end -}}{{- $_ := set $names .name true -}}{{- end -}}
{{- if .Values.gatewayAPI.enabled -}}{{- if and (empty .Values.gatewayAPI.httpRoutes) (empty .Values.gatewayAPI.tcpRoutes) (empty .Values.gatewayAPI.tlsRoutes) -}}{{ fail "gatewayAPI requires at least one route when enabled" }}{{- end -}}{{- end -}}
{{- end -}}
