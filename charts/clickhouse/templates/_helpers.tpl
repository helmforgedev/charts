{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "clickhouse.fullname" -}}
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

{{- define "clickhouse.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{- define "clickhouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "clickhouse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "clickhouse.labels" -}}
helm.sh/chart: {{ include "clickhouse.chart" . }}
{{ include "clickhouse.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "clickhouse.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "clickhouse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "clickhouse.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.suffixedName" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (max 1 (sub 63 (len $suffix))) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "clickhouse.headlessServiceName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-headless") -}}
{{- end -}}

{{- define "clickhouse.configMapName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-config") -}}
{{- end -}}

{{- define "clickhouse.secretName" -}}
{{- if .Values.clickhouse.existingSecret -}}
{{- .Values.clickhouse.existingSecret -}}
{{- else -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-auth") -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" $root) "suffix" (printf "-%s" $item.name)) -}}
{{- else if gt $index 0 -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "clickhouse.secretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.validate" -}}
{{- if lt (.Values.replicaCount | int) 1 -}}{{- fail "replicaCount must be at least 1" -}}{{- end -}}
{{- if gt (.Values.replicaCount | int) 1 -}}{{- fail "replicaCount > 1 is intentionally blocked in this chart; use ClickHouse Operator for replicated clusters" -}}{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}{{- fail "metrics.serviceMonitor.enabled requires metrics.enabled=true" -}}{{- end -}}
{{- if and .Values.clickhouse.existingSecret .Values.clickhouse.password -}}{{- fail "clickhouse.existingSecret and clickhouse.password are mutually exclusive" -}}{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{- fail "podLabels must not override app.kubernetes.io/name" -}}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{- fail "podLabels must not override app.kubernetes.io/instance" -}}{{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}{{- end -}}
{{- end -}}
