{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "temporal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "temporal.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "temporal.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "temporal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "temporal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "temporal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "temporal.labels" -}}
helm.sh/chart: {{ include "temporal.chart" . }}
{{ include "temporal.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "temporal.componentLabels" -}}
{{ include "temporal.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "temporal.componentSelectorLabels" -}}
{{ include "temporal.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "temporal.componentName" -}}
{{- $maxLength := ternary 52 63 (eq .component "history") -}}
{{- $baseLength := sub $maxLength (add (len .component) 1) -}}
{{- $base := include "temporal.fullname" .root | trunc (int $baseLength) | trimSuffix "-" -}}
{{- printf "%s-%s" $base .component -}}
{{- end -}}

{{- define "temporal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "temporal.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "temporal.databaseHost" -}}
{{- if .Values.database.host -}}
{{- .Values.database.host -}}
{{- else if eq .Values.database.mode "postgresql" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "temporal.databaseSecretName" -}}
{{- default .Values.credentials.secretName .Values.credentials.existingSecret -}}
{{- end -}}

{{- define "temporal.httpRouteName" -}}
{{- if .route.name -}}
{{- printf "%s-%s" (include "temporal.fullname" .root) .route.name | trunc 63 | trimSuffix "-" -}}
{{- else if eq (int .index) 0 -}}
{{- printf "%s-web" (include "temporal.fullname" .root) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-web-%d" (include "temporal.fullname" .root) (int .index) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "temporal.grpcRouteName" -}}
{{- if .route.name -}}
{{- printf "%s-%s" (include "temporal.fullname" .root) .route.name | trunc 63 | trimSuffix "-" -}}
{{- else if eq (int .index) 0 -}}
{{- printf "%s-frontend" (include "temporal.fullname" .root) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-frontend-%d" (include "temporal.fullname" .root) (int .index) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "temporal.externalSecretName" -}}
{{- if .item.fullnameOverride -}}
{{- .item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .item.name -}}
{{- printf "%s-%s" (include "temporal.fullname" .root) .item.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "temporal.databaseSecretName" .root -}}
{{- end -}}
{{- end -}}

{{- define "temporal.validate" -}}
{{- if not (has .Values.database.mode (list "postgresql" "external")) -}}
{{- fail "database.mode must be one of: postgresql, external" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "postgresql") (not .Values.postgresql.enabled) -}}
{{- fail "postgresql.enabled must be true when database.mode=postgresql" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") .Values.postgresql.enabled -}}
{{- fail "postgresql.enabled must be false when database.mode=external" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") (not .Values.database.host) -}}
{{- fail "database.host is required when database.mode=external" -}}
{{- end -}}
{{- if and .Values.schema.useHelmHooks (ne .Values.database.mode "external") -}}
{{- fail "schema.useHelmHooks=true requires database.mode=external because pre-install hooks run before bundled PostgreSQL" -}}
{{- end -}}
{{- if ne (int .Values.server.numHistoryShards) 512 -}}
{{- fail "server.numHistoryShards defaults to 512 and is immutable after initialization; acknowledge a custom topology through an external database bootstrap before changing it" -}}
{{- end -}}
{{- if .Values.gatewayAPI.enabled -}}
{{- if and (gt (len (.Values.gatewayAPI.httpRoutes | default list)) 0) (not .Values.web.enabled) -}}
{{- fail "web.enabled must be true when gatewayAPI.httpRoutes use the chart-managed Web UI backend" -}}
{{- end -}}
{{- if and (gt (len (.Values.gatewayAPI.grpcRoutes | default list)) 0) (not .Values.server.components.frontend.enabled) -}}
{{- fail "server.components.frontend.enabled must be true when gatewayAPI.grpcRoutes use the chart-managed frontend backend" -}}
{{- end -}}
{{- end -}}
{{- end -}}
