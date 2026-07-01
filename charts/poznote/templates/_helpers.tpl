{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "poznote.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "poznote.fullname" -}}
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

{{- define "poznote.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "poznote.labels" -}}
helm.sh/chart: {{ include "poznote.chart" . }}
{{ include "poznote.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "poznote.selectorLabels" -}}
app.kubernetes.io/name: {{ include "poznote.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "poznote.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "poznote.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "poznote.nameWithSuffix" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $max := int (default 63 .max) -}}
{{- $baseMax := int (sub $max (len $suffix)) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc $max | trimSuffix "-" -}}
{{- end -}}

{{- define "poznote.appSecretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "poznote.nameWithSuffix" (dict "base" (include "poznote.fullname" .) "suffix" "-app") -}}
{{- end -}}
{{- end -}}

{{- define "poznote.persistenceClaimName" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $persistence := index $root.Values.persistence $name -}}
{{- if $persistence.existingClaim -}}
{{- $persistence.existingClaim -}}
{{- else -}}
{{- include "poznote.nameWithSuffix" (dict "base" (include "poznote.fullname" $root) "suffix" (printf "-%s" $name)) -}}
{{- end -}}
{{- end -}}

{{- define "poznote.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := .index | default 0 -}}
{{- if $route.name -}}
{{- $suffix := printf "-%s" $route.name -}}
{{- $base := include "poznote.fullname" $root | trunc (int (max 1 (sub 63 (len $suffix)))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix | trunc 63 | trimSuffix "-" -}}
{{- else if gt (int $index) 0 -}}
{{- $suffix := printf "-%d" (int $index) -}}
{{- $base := include "poznote.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "poznote.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "poznote.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- $suffix := printf "-%s" $item.name -}}
{{- $base := include "poznote.fullname" $root | trunc (int (max 1 (sub 63 (len $suffix)))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix | trunc 63 | trimSuffix "-" -}}
{{- else if gt $index 0 -}}
{{- $suffix := printf "-%d" $index -}}
{{- $base := include "poznote.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "poznote.appSecretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "poznote.validate" -}}
{{- if gt (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount > 1 is not supported because Poznote uses SQLite for persistence" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- end -}}
