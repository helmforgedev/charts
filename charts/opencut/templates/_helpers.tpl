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

{{- define "opencut.databaseMode" -}}
{{- $hasExternal := ne (.Values.database.external.host | default "") "" -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if and $hasExternal $hasPostgresql -}}
{{- fail "opencut database selection is ambiguous: configure only one of database.external.host or postgresql.enabled" -}}
{{- end -}}
{{- if $hasExternal -}}external{{- else if $hasPostgresql -}}postgresql{{- else -}}{{- fail "opencut requires PostgreSQL: enable postgresql.enabled or set database.external.host" -}}{{- end -}}
{{- end -}}

{{- define "opencut.databaseHost" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.host }}{{- else -}}{{ printf "%s-postgresql" .Release.Name }}{{- end -}}
{{- end -}}

{{- define "opencut.databasePort" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.port | toString }}{{- else -}}5432{{- end -}}
{{- end -}}

{{- define "opencut.databaseName" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.name }}{{- else -}}{{ .Values.postgresql.auth.database }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseUsername" -}}
{{- if eq (include "opencut.databaseMode" .) "external" -}}{{ .Values.database.external.username }}{{- else -}}{{ .Values.postgresql.auth.username }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseSecretName" -}}
{{- if and (eq (include "opencut.databaseMode" .) "external") .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecret }}{{- else if eq (include "opencut.databaseMode" .) "external" -}}{{ printf "%s-database" (include "opencut.fullname" .) }}{{- else -}}{{ printf "%s-postgresql-auth" .Release.Name }}{{- end -}}
{{- end -}}

{{- define "opencut.databaseSecretKey" -}}
{{- if and (eq (include "opencut.databaseMode" .) "external") .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecretPasswordKey | default "database-password" }}{{- else if eq (include "opencut.databaseMode" .) "external" -}}database-password{{- else -}}user-password{{- end -}}
{{- end -}}

{{- define "opencut.redisHost" -}}
{{- if .Values.redis.external.host -}}{{ .Values.redis.external.host }}{{- else -}}{{ printf "%s-redis-client" .Release.Name }}{{- end -}}
{{- end -}}

{{- define "opencut.redisPort" -}}
{{- if .Values.redis.external.host -}}{{ .Values.redis.external.port | toString }}{{- else -}}6379{{- end -}}
{{- end -}}

{{- define "opencut.redisHttpName" -}}
{{- printf "%s-redis-http" (include "opencut.fullname" .) -}}
{{- end -}}

{{- define "opencut.siteUrl" -}}
{{- if .Values.opencut.siteUrl -}}{{ .Values.opencut.siteUrl }}{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}{{ printf "https://%s" (index .Values.ingress.hosts 0).host }}{{- else -}}http://localhost:3000{{- end -}}
{{- end -}}

{{- define "opencut.betterAuthSecret" -}}
{{- $secretName := include "opencut.secretName" . -}}
{{- if .Values.opencut.betterAuthSecret -}}{{ .Values.opencut.betterAuthSecret }}{{- else -}}{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}{{- if and $existing (index $existing.data "better-auth-secret") -}}{{ index $existing.data "better-auth-secret" | b64dec }}{{- else -}}{{ randAlphaNum 48 }}{{- end -}}{{- end -}}
{{- end -}}

{{- define "opencut.redisRestToken" -}}
{{- $secretName := include "opencut.secretName" . -}}
{{- if .Values.redisHttp.token -}}{{ .Values.redisHttp.token }}{{- else -}}{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}{{- if and $existing (index $existing.data "redis-rest-token") -}}{{ index $existing.data "redis-rest-token" | b64dec }}{{- else -}}{{ randAlphaNum 32 }}{{- end -}}{{- end -}}
{{- end -}}
