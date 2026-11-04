{{/* SPDX-License-Identifier: Apache-2.0 */}}

{{- define "discourse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "discourse.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "discourse.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- define "discourse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "discourse.labels" -}}
helm.sh/chart: {{ include "discourse.chart" . }}
{{ include "discourse.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "discourse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "discourse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "discourse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "discourse.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "discourse.image" -}}
{{- $image := printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $image .Values.image.digest -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end -}}

{{- define "discourse.secretName" -}}
{{- if .Values.discourse.existingSecret -}}
{{- .Values.discourse.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "discourse.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discourse.secretKey" -}}
{{- if .Values.discourse.existingSecret -}}
{{- .Values.discourse.existingSecretKey -}}
{{- else -}}
secret-key-base
{{- end -}}
{{- end -}}

{{- define "discourse.databaseHost" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- include "discourse.postgresqlFullname" . -}}
{{- end -}}
{{- end -}}

{{- define "discourse.nameWithSuffix" -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (sub 63 (len $suffix)) -}}
{{- printf "%s%s" (.base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "discourse.postgresqlFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "postgresql" .Values.postgresql.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "discourse.redisFullname" -}}
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

{{- define "discourse.databasePort" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.port -}}
{{- else -}}5432{{- end -}}
{{- end -}}

{{- define "discourse.databaseName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "discourse.databaseUsername" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "discourse.databaseSecretName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "discourse.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else if and .Values.postgresql.externalSecrets.auth.enabled .Values.postgresql.externalSecrets.auth.targetName -}}
{{- .Values.postgresql.externalSecrets.auth.targetName -}}
{{- else -}}
{{- include "discourse.nameWithSuffix" (dict "base" (include "discourse.postgresqlFullname" .) "suffix" "-auth") -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "discourse.databaseSecretKey" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq .Values.database.mode "external" -}}database-password
{{- else -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{- end -}}
{{- end -}}

{{- define "discourse.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{- include "discourse.nameWithSuffix" (dict "base" (include "discourse.redisFullname" .) "suffix" "-client") -}}
{{- else -}}
{{- .Values.redis.external.host -}}
{{- end -}}
{{- end -}}

{{- define "discourse.redisPort" -}}
{{- if .Values.redis.enabled -}}6379{{- else -}}{{ .Values.redis.external.port }}{{- end -}}
{{- end -}}

{{- define "discourse.redisSecretName" -}}
{{- if .Values.redis.external.existingSecret -}}
{{- .Values.redis.external.existingSecret -}}
{{- else -}}
{{- printf "%s-redis" (include "discourse.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discourse.redisSecretKey" -}}
{{- if .Values.redis.external.existingSecret -}}
{{- .Values.redis.external.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{- define "discourse.sharedClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-shared" (include "discourse.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discourse.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- $suffix := printf "-%s" $item.name -}}
{{- $base := include "discourse.fullname" $root | trunc (int (max 1 (sub 63 (len $suffix)))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix | trunc 63 | trimSuffix "-" -}}
{{- else if gt $index 0 -}}
{{- $suffix := printf "-%d" $index -}}
{{- $base := include "discourse.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "discourse.secretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "discourse.validate" -}}
{{- if ne (int .Values.replicaCount) 1 -}}
{{- fail "discourse: replicaCount must remain 1 while the official Kubernetes runtime is experimental" -}}
{{- end -}}
{{- if not .Values.discourse.hostname -}}
{{- fail "discourse: discourse.hostname is required" -}}
{{- end -}}
{{- if not .Values.image.digest -}}
{{- fail "discourse: image.digest is required because upstream rebuilds version tags" -}}
{{- end -}}
{{- if and (not .Values.persistence.enabled) (not .Values.persistence.existingClaim) -}}
{{- fail "discourse: persistence.enabled=true or persistence.existingClaim is required for /shared" -}}
{{- end -}}
{{- if not (has .Values.database.mode (list "postgresql" "external")) -}}
{{- fail "discourse: database.mode must be postgresql or external" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "postgresql") (not .Values.postgresql.enabled) -}}
{{- fail "discourse: database.mode=postgresql requires postgresql.enabled=true" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") .Values.postgresql.enabled -}}
{{- fail "discourse: database.mode=external cannot be combined with postgresql.enabled=true" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") (not .Values.database.external.host) -}}
{{- fail "discourse: database.external.host is required when database.mode=external" -}}
{{- end -}}
{{- if and (not .Values.redis.enabled) (not .Values.redis.external.host) -}}
{{- fail "discourse: enable redis or configure redis.external.host" -}}
{{- end -}}
{{- if .Values.redis.auth.enabled -}}
{{- fail "discourse: redis.auth.enabled is not supported by the initial experimental runtime contract" -}}
{{- end -}}
{{- if and .Values.podDisruptionBudget.enabled (ne (int .Values.podDisruptionBudget.maxUnavailable) 1) -}}
{{- fail "discourse: podDisruptionBudget.maxUnavailable must be 1 for the singleton runtime" -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (not .Values.gatewayAPI.parentRefs) -}}
{{- fail "discourse: gatewayAPI.parentRefs is required when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if ne (int .Values.securityContext.runAsUser) 0 -}}
{{- fail "discourse: the official experimental image requires securityContext.runAsUser=0" -}}
{{- end -}}
{{- if .Values.securityContext.readOnlyRootFilesystem -}}
{{- fail "discourse: the official experimental image requires a writable root filesystem" -}}
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
