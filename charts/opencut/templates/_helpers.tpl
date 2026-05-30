{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "opencut.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opencut.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "opencut.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "opencut.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opencut.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opencut.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "opencut.labels" -}}
helm.sh/chart: {{ include "opencut.chart" . }}
{{ include "opencut.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "opencut.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "opencut.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "opencut.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "opencut.secretName" -}}
{{- printf "%s-app" (include "opencut.fullname" .) -}}
{{- end -}}

{{- define "opencut.postgresqlName" -}}
{{- default "postgresql" .Values.postgresql.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opencut.postgresqlFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "opencut.postgresqlName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "opencut.postgresqlServiceName" -}}
{{- if eq (.Values.postgresql.architecture | default "standalone") "replication" -}}
{{- printf "%s-primary" (include "opencut.postgresqlFullname" .) -}}
{{- else -}}
{{- include "opencut.postgresqlFullname" . -}}
{{- end -}}
{{- end -}}

{{- define "opencut.redisName" -}}
{{- default "redis" .Values.redis.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opencut.redisFullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "opencut.redisName" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "opencut.redisClientServiceName" -}}
{{- printf "%s-client" (include "opencut.redisFullname" .) -}}
{{- end -}}

{{- define "opencut.redisPrimaryServiceName" -}}
{{- printf "%s-primary" (include "opencut.redisFullname" .) -}}
{{- end -}}

{{- define "opencut.redisServiceName" -}}
{{- if eq (.Values.redis.architecture | default "standalone") "replication" -}}
{{- include "opencut.redisPrimaryServiceName" . -}}
{{- else -}}
{{- include "opencut.redisClientServiceName" . -}}
{{- end -}}
{{- end -}}

{{- define "opencut.databaseMode" -}}
{{- $hasExternal := ne (.Values.database.external.host | default "") "" -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if and $hasExternal $hasPostgresql -}}
{{- fail "opencut database selection is ambiguous: configure only one of database.external.host or postgresql.enabled" -}}
{{- end -}}
{{- if $hasExternal -}}external{{- else if $hasPostgresql -}}postgresql{{- else -}}{{- fail "opencut requires PostgreSQL: enable postgresql.enabled or set database.external.host" -}}{{- end -}}
{{- end -}}

{{- define "opencut.databaseHost" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.host }}{{- else -}}{{ include "opencut.postgresqlServiceName" . }}{{- end -}}
{{- end -}}

{{- define "opencut.databasePort" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.port | toString }}{{- else -}}{{ dig "service" "port" 5432 .Values.postgresql | toString }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseName" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.name }}{{- else -}}{{ .Values.postgresql.auth.database }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseUsername" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.username }}{{- else -}}{{ .Values.postgresql.auth.username }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseSecretName" -}}
{{- if and (eq (include "opencut.databaseMode" .) "external") .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecret }}{{- else if eq (include "opencut.databaseMode" .) "external" -}}{{ printf "%s-database" (include "opencut.fullname" .) }}{{- else if .Values.postgresql.auth.existingSecret -}}{{ .Values.postgresql.auth.existingSecret }}{{- else if and .Values.postgresql.externalSecrets.enabled .Values.postgresql.externalSecrets.auth.enabled .Values.postgresql.externalSecrets.auth.targetName -}}{{ .Values.postgresql.externalSecrets.auth.targetName }}{{- else -}}{{ printf "%s-auth" (include "opencut.postgresqlFullname" .) }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseSecretKey" -}}
{{- if and (eq (include "opencut.databaseMode" .) "external") .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecretPasswordKey | default "database-password" }}{{- else if eq (include "opencut.databaseMode" .) "external" -}}database-password{{- else -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" }}{{- end -}}
{{- end -}}

{{- define "opencut.redisHost" -}}
{{- if and .Values.redisHttp.enabled (not .Values.redis.enabled) (not .Values.redis.external.host) -}}{{- fail "redisHttp.enabled requires redis.enabled=true or redis.external.host to be set" -}}{{- end -}}
{{- if .Values.redis.external.host -}}{{ .Values.redis.external.host }}{{- else -}}{{ include "opencut.redisServiceName" . }}{{- end -}}
{{- end -}}

{{- define "opencut.redisPort" -}}
{{- if .Values.redis.external.host -}}{{ .Values.redis.external.port | toString }}{{- else -}}{{ dig "service" "ports" "redis" 6379 .Values.redis | toString }}{{- end -}}
{{- end -}}

{{- define "opencut.redisAuthEnabled" -}}
{{- if or (and (not .Values.redis.external.host) .Values.redis.auth.enabled) .Values.redis.external.password .Values.redis.external.existingSecret -}}true{{- end -}}
{{- end -}}

{{- define "opencut.redisSecretName" -}}
{{- if .Values.redis.external.existingSecret -}}{{ .Values.redis.external.existingSecret }}{{- else if .Values.redis.external.password -}}{{ include "opencut.secretName" . }}{{- else if .Values.redis.auth.existingSecret -}}{{ .Values.redis.auth.existingSecret }}{{- else -}}{{ printf "%s-auth" (include "opencut.redisFullname" .) }}{{- end -}}
{{- end -}}

{{- define "opencut.redisSecretKey" -}}
{{- if .Values.redis.external.existingSecret -}}{{ .Values.redis.external.existingSecretPasswordKey | default "redis-password" }}{{- else if .Values.redis.external.password -}}redis-password{{- else -}}{{ .Values.redis.auth.existingSecretPasswordKey | default "redis-password" }}{{- end -}}
{{- end -}}

{{- define "opencut.redisHttpName" -}}
{{- printf "%s-redis-http" (include "opencut.fullname" .) -}}
{{- end -}}

{{- define "opencut.siteUrl" -}}
{{- if .Values.opencut.siteUrl -}}{{ .Values.opencut.siteUrl }}{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}{{ printf "%s://%s" (ternary "https" "http" (gt (len .Values.ingress.tls) 0)) (index .Values.ingress.hosts 0).host }}{{- else if and .Values.gateway.enabled (gt (len .Values.gateway.hostnames) 0) -}}{{ printf "https://%s" (index .Values.gateway.hostnames 0) }}{{- else -}}http://localhost:3000{{- end -}}
{{- end -}}

{{- define "opencut.betterAuthSecret" -}}
{{- $secretName := include "opencut.secretName" . -}}
{{- if .Values.opencut.betterAuthSecret -}}{{ .Values.opencut.betterAuthSecret }}{{- else -}}{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}{{- if and $existing (index $existing.data "better-auth-secret") -}}{{ index $existing.data "better-auth-secret" | b64dec }}{{- else -}}{{ randAlphaNum 48 }}{{- end -}}{{- end -}}
{{- end -}}

{{- define "opencut.redisRestToken" -}}
{{- $secretName := include "opencut.secretName" . -}}
{{- if .Values.redisHttp.token -}}{{ .Values.redisHttp.token }}{{- else -}}{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}{{- if and $existing (index $existing.data "redis-rest-token") -}}{{ index $existing.data "redis-rest-token" | b64dec }}{{- else -}}{{ randAlphaNum 32 }}{{- end -}}{{- end -}}
{{- end -}}
