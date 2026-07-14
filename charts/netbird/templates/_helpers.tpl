{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "netbird.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "netbird.fullname" -}}
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

{{/*
Chart label.
*/}}
{{- define "netbird.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "netbird.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "netbird.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Component selector labels.
*/}}
{{- define "netbird.componentSelectorLabels" -}}
{{ include "netbird.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
NetBird server service name.
*/}}
{{- define "netbird.serverServiceName" -}}
{{- printf "%s-server" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
NetBird dashboard service name.
*/}}
{{- define "netbird.dashboardServiceName" -}}
{{- printf "%s-dashboard" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
NetBird config secret name.
*/}}
{{- define "netbird.configSecretName" -}}
{{- if .Values.server.config.existingSecret -}}
{{- .Values.server.config.existingSecret -}}
{{- else -}}
{{- printf "%s-config" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
ServiceAccount name.
*/}}
{{- define "netbird.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "netbird.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
HTTPRoute name helper.
*/}}
{{- define "netbird.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := .index | default 0 -}}
{{- if $route.name -}}
{{- $suffix := printf "-%s" $route.name -}}
{{- $base := include "netbird.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else if gt (int $index) 0 -}}
{{- $suffix := printf "-%d" (int $index) -}}
{{- $base := include "netbird.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "netbird.fullname" $root -}}
{{- end -}}
{{- end -}}

{{/*
ExternalSecret name helper.
*/}}
{{- define "netbird.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- $suffix := printf "-%s" $item.name -}}
{{- $base := include "netbird.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else if gt $index 0 -}}
{{- $suffix := printf "-%d" $index -}}
{{- $base := printf "%s-secret" (include "netbird.fullname" $root) | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- printf "%s-secret" (include "netbird.fullname" $root) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Validate chart values.
*/}}
{{- define "netbird.validate" -}}
{{- if and (gt (int .Values.server.replicaCount) 1) (eq .Values.server.store.engine "sqlite") -}}
{{- fail "server.replicaCount > 1 requires server.store.engine other than sqlite" -}}
{{- end -}}
{{- if and (ne .Values.server.store.engine "sqlite") (empty .Values.server.store.dsn) -}}
{{- fail "server.store.dsn is required when server.store.engine is postgres or mysql" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and (not .Values.server.config.existingSecret) (not .Values.server.authSecret) -}}
{{- fail "server.authSecret is required when server.config.existingSecret is not set" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- range $key := (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}
{{- if hasKey $podLabels $key -}}
{{- fail (printf "podLabels must not override the selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
