{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "notediscovery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "notediscovery.fullname" -}}
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
{{- define "notediscovery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "notediscovery.labels" -}}
helm.sh/chart: {{ include "notediscovery.chart" . }}
{{ include "notediscovery.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "notediscovery.selectorLabels" -}}
app.kubernetes.io/name: {{ include "notediscovery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name.
*/}}
{{- define "notediscovery.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "notediscovery.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Configuration resource name.
*/}}
{{- define "notediscovery.configName" -}}
{{- printf "%s-config" (include "notediscovery.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Rendered config source name. Auth uses Secret; non-auth uses ConfigMap.
*/}}
{{- define "notediscovery.configSourceName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- include "notediscovery.configName" . -}}
{{- end -}}
{{- end -}}

{{/*
Rendered config source key.
*/}}
{{- define "notediscovery.configSourceKey" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecretKey -}}
{{- else -}}
config.yaml
{{- end -}}
{{- end -}}

{{/*
Configuration checksum for pod rollouts.
*/}}
{{- define "notediscovery.configChecksum" -}}
{{- if .Values.auth.existingSecret -}}
{{- dict "existingSecret" .Values.auth.existingSecret "existingSecretKey" .Values.auth.existingSecretKey "externalSecrets" .Values.externalSecrets | toJson | sha256sum -}}
{{- else if .Values.auth.enabled -}}
{{- include (print .Template.BasePath "/secret.yaml") . | sha256sum -}}
{{- else -}}
{{- include (print .Template.BasePath "/configmap.yaml") . | sha256sum -}}
{{- end -}}
{{- end -}}

{{/*
HTTPRoute name helper.
*/}}
{{- define "notediscovery.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := .index | default 0 -}}
{{- if $route.name -}}
{{- printf "%s-%s" (include "notediscovery.fullname" $root) $route.name | trunc 63 | trimSuffix "-" -}}
{{- else if gt (int $index) 0 -}}
{{- printf "%s-%d" (include "notediscovery.fullname" $root) $index | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "notediscovery.fullname" $root -}}
{{- end -}}
{{- end -}}

{{/*
ExternalSecret name helper.
*/}}
{{- define "notediscovery.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- printf "%s-%s" (include "notediscovery.fullname" $root) $item.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "notediscovery.configName" $root -}}
{{- end -}}
{{- end -}}

{{/*
Validate chart values.
*/}}
{{- define "notediscovery.validate" -}}
{{- if and (gt (int .Values.replicaCount) 1) (not .Values.persistence.existingClaim) -}}
{{- fail "replicaCount > 1 requires persistence.existingClaim because NoteDiscovery stores notes as local files on a single writable volume" -}}
{{- end -}}
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) (or (empty .Values.auth.secretKey) (empty .Values.auth.password)) -}}
{{- fail "auth.secretKey and auth.password are required when auth.enabled=true unless auth.existingSecret is set" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- end -}}
