{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "paperless-ngx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ngx.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "paperless-ngx.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ngx.labels" -}}
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{ include "paperless-ngx.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "paperless-ngx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Component labels. Every workload carries a component label so the Paperless-ngx,
Tika, and Gotenberg selectors never overlap.
Usage: include "paperless-ngx.componentLabels" (dict "ctx" $ "component" "tika")
*/}}
{{- define "paperless-ngx.componentLabels" -}}
{{ include "paperless-ngx.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "paperless-ngx.componentSelectorLabels" -}}
{{ include "paperless-ngx.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "paperless-ngx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "paperless-ngx.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "paperless-ngx.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "postgresql" "sqlite")) -}}
{{- fail (printf "database.mode must be one of: auto, external, postgresql, sqlite (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasPostgresql -}}
    {{- fail "paperless-ngx database selection is ambiguous: configure only one of database.external.* or postgresql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else -}}sqlite
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not .Values.database.external.host) -}}
    {{- fail "database.mode=external requires database.external.host" -}}
  {{- end -}}
  {{- if and (ne $mode "postgresql") $hasPostgresql -}}
    {{- fail (printf "database.mode=%s cannot be combined with postgresql.enabled" $mode) -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") (not $hasPostgresql) -}}
    {{- fail "database.mode=postgresql requires postgresql.enabled=true" -}}
  {{- end -}}
  {{- if and (ne $mode "external") $hasExternal -}}
    {{- fail (printf "database.mode=%s cannot be combined with database.external.*" $mode) -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{/*
Name helpers for the HelmForge PostgreSQL subchart. They mirror postgresql.fullname,
postgresql.primaryServiceName and postgresql.secretName so that subchart overrides
(fullnameOverride, nameOverride, architecture, auth.existingSecret, externalSecrets.auth)
keep the Paperless-ngx wiring correct. Subchart defaults are not visible to the parent
chart, so every lookup is nil-safe and falls back to the subchart default.
*/}}
{{- define "paperless-ngx.postgresqlFullname" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- if $pg.fullnameOverride -}}
{{- $pg.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (default "postgresql" $pg.nameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Usage: include "paperless-ngx.nameWithSuffix" (dict "base" "name" "suffix" "-auth") */}}
{{- define "paperless-ngx.nameWithSuffix" -}}
{{- $baseMax := int (sub 63 (len .suffix)) -}}
{{- printf "%s%s" (.base | trunc $baseMax | trimSuffix "-") .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ngx.postgresqlHost" -}}
{{- $fullname := include "paperless-ngx.postgresqlFullname" . -}}
{{- if eq (dig "architecture" "standalone" (.Values.postgresql | default dict)) "replication" -}}
{{- include "paperless-ngx.nameWithSuffix" (dict "base" $fullname "suffix" "-primary") -}}
{{- else -}}
{{- $fullname -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.postgresqlSecretName" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $existing := dig "auth" "existingSecret" "" $pg -}}
{{- $default := include "paperless-ngx.nameWithSuffix" (dict "base" (include "paperless-ngx.postgresqlFullname" .) "suffix" "-auth") -}}
{{- if $existing -}}
{{- $existing -}}
{{- else if and (dig "externalSecrets" "enabled" false $pg) (dig "externalSecrets" "auth" "enabled" false $pg) -}}
{{- default $default (dig "externalSecrets" "auth" "targetName" "" $pg) -}}
{{- else -}}
{{- $default -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.postgresqlSecretKey" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- if eq (dig "auth" "username" "app" $pg) "postgres" -}}
{{- dig "auth" "existingSecretPostgresPasswordKey" "postgres-password" $pg -}}
{{- else -}}
{{- dig "auth" "existingSecretUserPasswordKey" "user-password" $pg -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.databaseHost" -}}
{{- if eq (include "paperless-ngx.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- include "paperless-ngx.postgresqlHost" . -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.databasePort" -}}
{{- if eq (include "paperless-ngx.databaseMode" .) "external" -}}
{{- .Values.database.external.port | default 5432 | toString -}}
{{- else -}}
{{- dig "service" "port" 5432 (.Values.postgresql | default dict) | toString -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.databaseName" -}}
{{- if eq (include "paperless-ngx.databaseMode" .) "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.databaseUsername" -}}
{{- if eq (include "paperless-ngx.databaseMode" .) "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.databaseSecretName" -}}
{{- if and (eq (include "paperless-ngx.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "paperless-ngx.databaseMode" .) "external" -}}
{{- printf "%s-database" (include "paperless-ngx.fullname" .) -}}
{{- else -}}
{{- include "paperless-ngx.postgresqlSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.databaseSecretKey" -}}
{{- if and (eq (include "paperless-ngx.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else if eq (include "paperless-ngx.databaseMode" .) "external" -}}
database-password
{{- else -}}
{{- include "paperless-ngx.postgresqlSecretKey" . -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.valkeyMode" -}}
{{- $hasExternal := or (ne (.Values.valkey.external.host | default "") "") (ne (.Values.valkey.external.existingSecret | default "") "") -}}
{{- $hasSubchart := .Values.valkey.enabled | default false -}}
{{- if and $hasExternal $hasSubchart -}}
{{- fail "paperless-ngx valkey selection is ambiguous: configure only one of valkey.external.* or valkey.enabled" -}}
{{- end -}}
{{- if and $hasExternal (not .Values.valkey.external.host) -}}
{{- fail "valkey.external.existingSecret requires valkey.external.host" -}}
{{- end -}}
{{- if $hasExternal -}}external
{{- else if $hasSubchart -}}subchart
{{- else -}}{{- fail "paperless-ngx requires Valkey: enable valkey.enabled or configure valkey.external.host" -}}
{{- end -}}
{{- end -}}

{{/*
Name helpers for the HelmForge Valkey subchart. They mirror valkey.fullname (including the
rule that reuses the release name when it already contains the chart name),
valkey.clientServiceName, valkey.primaryServiceName and valkey.secretName.
*/}}
{{- define "paperless-ngx.valkeyFullname" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- if $vk.fullnameOverride -}}
{{- $vk.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "valkey" $vk.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.valkeyHost" -}}
{{- if eq (include "paperless-ngx.valkeyMode" .) "external" -}}
{{- .Values.valkey.external.host -}}
{{- else -}}
{{- $architecture := dig "architecture" "standalone" (.Values.valkey | default dict) -}}
{{- if eq $architecture "standalone" -}}
{{- printf "%s-client" (include "paperless-ngx.valkeyFullname" .) -}}
{{- else if eq $architecture "replication" -}}
{{- printf "%s-primary" (include "paperless-ngx.valkeyFullname" .) -}}
{{- else -}}
{{- fail (printf "paperless-ngx supports valkey.architecture=standalone or replication for the Valkey subchart (got %s); use valkey.external.* for other topologies" $architecture) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.valkeyPort" -}}
{{- if eq (include "paperless-ngx.valkeyMode" .) "external" -}}
{{- .Values.valkey.external.port | default 6379 | toString -}}
{{- else -}}
{{- dig "service" "ports" "valkey" 6379 (.Values.valkey | default dict) | toString -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.valkeySecretName" -}}
{{- if eq (include "paperless-ngx.valkeyMode" .) "external" -}}
{{- if .Values.valkey.external.existingSecret -}}
{{- .Values.valkey.external.existingSecret -}}
{{- else -}}
{{- printf "%s-valkey" (include "paperless-ngx.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- $existing := dig "auth" "existingSecret" "" (.Values.valkey | default dict) -}}
{{- if $existing -}}
{{- $existing -}}
{{- else -}}
{{- printf "%s-auth" (include "paperless-ngx.valkeyFullname" .) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.valkeySecretKey" -}}
{{- if eq (include "paperless-ngx.valkeyMode" .) "external" -}}
{{- if .Values.valkey.external.existingSecret -}}
{{- .Values.valkey.external.existingSecretPasswordKey | default "valkey-password" -}}
{{- else -}}
valkey-password
{{- end -}}
{{- else -}}
{{- dig "auth" "existingSecretPasswordKey" "valkey-password" (.Values.valkey | default dict) -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.hasValkeyPassword" -}}
{{- if eq (include "paperless-ngx.valkeyMode" .) "external" -}}
{{- if or .Values.valkey.external.password .Values.valkey.external.existingSecret -}}true{{- end -}}
{{- else -}}
{{- if .Values.valkey.auth.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.url" -}}
{{- if .Values.paperless.url -}}
{{- .Values.paperless.url | trimSuffix "/" -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- printf "https://%s" (index .Values.ingress.hosts 0).host -}}
{{- else if and .Values.gateway.enabled (gt (len .Values.gateway.hostnames) 0) -}}
{{- printf "https://%s" (index .Values.gateway.hostnames 0) -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.secretKeySecretName" -}}
{{- if .Values.paperless.existingSecret -}}
{{- .Values.paperless.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "paperless-ngx.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.secretKeySecretKey" -}}
{{- if .Values.paperless.existingSecret -}}
{{- .Values.paperless.existingSecretSecretKeyKey -}}
{{- else -}}
secret-key
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.adminSecretName" -}}
{{- if .Values.paperless.admin.existingSecret -}}
{{- .Values.paperless.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "paperless-ngx.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.adminSecretKey" -}}
{{- if .Values.paperless.admin.existingSecret -}}
{{- .Values.paperless.admin.existingSecretPasswordKey -}}
{{- else -}}
admin-password
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.tikaEnabled" -}}
{{- if and .Values.tika.enabled .Values.gotenberg.enabled -}}true{{- end -}}
{{- end -}}

{{- define "paperless-ngx.tikaEndpoint" -}}
{{- printf "http://%s-tika:%v" (include "paperless-ngx.fullname" .) .Values.tika.containerPorts.http -}}
{{- end -}}

{{- define "paperless-ngx.gotenbergEndpoint" -}}
{{- printf "http://%s-gotenberg:%v" (include "paperless-ngx.fullname" .) .Values.gotenberg.containerPorts.http -}}
{{- end -}}

{{/*
Persistent volume source for one of the data, media, consume, or export directories.
Usage: include "paperless-ngx.volumeSource" (dict "ctx" $ "name" "data")
*/}}
{{- define "paperless-ngx.volumeSource" -}}
{{- $p := index .ctx.Values.persistence .name -}}
{{- if $p.existingClaim -}}
persistentVolumeClaim:
  claimName: {{ $p.existingClaim }}
{{- else if $p.enabled -}}
persistentVolumeClaim:
  claimName: {{ include "paperless-ngx.fullname" .ctx }}-{{ .name }}
{{- else -}}
emptyDir: {}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.validate" -}}
{{- $mode := include "paperless-ngx.databaseMode" . -}}
{{- $valkey := include "paperless-ngx.valkeyMode" . -}}
{{- if and (eq $mode "external") (not .Values.database.external.host) -}}
{{- fail "paperless-ngx: database.external.host is required for an external PostgreSQL database" -}}
{{- end -}}
{{- if gt (int .Values.replicaCount) 1 -}}
{{- fail "paperless-ngx: replicaCount must be 0 or 1 because the scheduler and document consumer must run as a single instance" -}}
{{- end -}}
{{- if ne (.Values.tika.enabled | default false) (.Values.gotenberg.enabled | default false) -}}
{{- fail "paperless-ngx: tika.enabled and gotenberg.enabled must be enabled together; Paperless-ngx needs both to convert office documents and emails" -}}
{{- end -}}
{{- if and .Values.paperless.admin.enabled (not .Values.paperless.admin.username) -}}
{{- fail "paperless-ngx: paperless.admin.username is required when paperless.admin.enabled=true" -}}
{{- end -}}
{{- if and .Values.paperless.url (not (regexMatch "^https?://[^/]+$" (.Values.paperless.url | trimSuffix "/"))) -}}
{{- fail "paperless-ngx: paperless.url must be scheme and host only, for example https://paperless.example.com (no path)" -}}
{{- end -}}
{{- range .Values.paperless.extraEnv -}}
{{- if eq .name "PAPERLESS_PORT" -}}
{{- fail "paperless-ngx: paperless.extraEnv must not override PAPERLESS_PORT; use containerPorts.http" -}}
{{- end -}}
{{- end -}}
{{- range .Values.tika.args -}}
{{- if regexMatch "^(?:--host(?:=|$)|-h(?:=|$)|--port(?:=|$)|-p(?:=|$))" . -}}
{{- fail "paperless-ngx: tika.args must not override --host or --port; use tika.containerPorts.http" -}}
{{- end -}}
{{- end -}}
{{- range .Values.gotenberg.args -}}
{{- if regexMatch "^--api-port(?:=|$)" . -}}
{{- fail "paperless-ngx: gotenberg.args must not override --api-port; use gotenberg.containerPorts.http" -}}
{{- end -}}
{{- end -}}
{{- end -}}
