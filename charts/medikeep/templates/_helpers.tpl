{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "medikeep.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "medikeep.fullname" -}}
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

{{- define "medikeep.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "medikeep.labels" -}}
helm.sh/chart: {{ include "medikeep.chart" . }}
{{ include "medikeep.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "medikeep.selectorLabels" -}}
app.kubernetes.io/name: {{ include "medikeep.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "medikeep.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "medikeep.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.nameWithSuffix" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $max := int (default 63 .max) -}}
{{- $baseMax := int (sub $max (len $suffix)) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc $max | trimSuffix "-" -}}
{{- end -}}

{{- define "medikeep.appSecretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "medikeep.nameWithSuffix" (dict "base" (include "medikeep.fullname" .) "suffix" "-app") -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.appSecretKey" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.secretKeyKey | default "secret-key" -}}
{{- else -}}
secret-key
{{- end -}}
{{- end -}}

{{- define "medikeep.secretKey" -}}
{{- if .Values.secrets.secretKey -}}
{{- .Values.secrets.secretKey -}}
{{- else -}}
{{- $secretName := include "medikeep.appSecretName" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data "secret-key") -}}
{{- index $existing.data "secret-key" | b64dec -}}
{{- else -}}
{{- randAlphaNum 64 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- dig "service" "port" 5432 .Values.postgresql -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "medical_records" -}}
{{- else -}}
{{- .Values.database.external.name | default "medical_records" -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "medapp" -}}
{{- else -}}
{{- .Values.database.external.username | default "medapp" -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- include "medikeep.nameWithSuffix" (dict "base" (include "medikeep.fullname" .) "suffix" "-db") -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
user-password
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
password
{{- end -}}
{{- end -}}

{{- define "medikeep.persistenceClaimName" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $persistence := index $root.Values.persistence $name -}}
{{- if $persistence.existingClaim -}}
{{- $persistence.existingClaim -}}
{{- else -}}
{{- include "medikeep.nameWithSuffix" (dict "base" (include "medikeep.fullname" $root) "suffix" (printf "-%s" $name)) -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := .index | default 0 -}}
{{- if $route.name -}}
{{- $suffix := printf "-%s" $route.name -}}
{{- $base := include "medikeep.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else if gt (int $index) 0 -}}
{{- $suffix := printf "-%d" (int $index) -}}
{{- $base := include "medikeep.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "medikeep.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- $suffix := printf "-%s" $item.name -}}
{{- $base := include "medikeep.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else if gt $index 0 -}}
{{- $suffix := printf "-%d" $index -}}
{{- $base := include "medikeep.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "medikeep.appSecretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "medikeep.validate" -}}
{{- if gt (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount > 1 is not supported because MediKeep stores uploads, logs, and generated backups on pod-local writable volumes" -}}
{{- end -}}
{{- if and (not .Values.postgresql.enabled) (empty .Values.database.external.host) -}}
{{- fail "database.external.host is required when postgresql.enabled=false" -}}
{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not .Values.database.external.existingSecret) (empty .Values.database.external.password) -}}
{{- fail "database.external.password or database.external.existingSecret is required when postgresql.enabled=false" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- end -}}
