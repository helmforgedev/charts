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
Database/store mode selection.
*/}}
{{- define "netbird.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "sqlite" "postgresql" "external")) -}}
{{- fail (printf "database.mode must be one of: auto, sqlite, postgresql, external (got %s)" $mode) -}}
{{- end -}}
{{- $external := .Values.database.external | default dict -}}
{{- $hasExternal := or (ne ($external.host | default "") "") (ne ($external.existingSecret | default "") "") (ne ($external.dsn | default "") "") (ne ($external.password | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasPostgresql -}}
    {{- fail "netbird database selection is ambiguous: configure only one of database.external.* or postgresql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else -}}sqlite
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host, database.external.existingSecret, database.external.password, or database.external.dsn" -}}
  {{- end -}}
  {{- if and (eq $mode "external") $hasPostgresql -}}
    {{- fail "database.mode=external cannot be combined with postgresql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") (not $hasPostgresql) -}}
    {{- fail "database.mode=postgresql requires postgresql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") $hasExternal -}}
    {{- fail "database.mode=postgresql cannot be combined with database.external.*" -}}
  {{- end -}}
  {{- if and (eq $mode "sqlite") $hasPostgresql -}}
    {{- fail "database.mode=sqlite requires postgresql.enabled=false" -}}
  {{- end -}}
  {{- if and (eq $mode "sqlite") $hasExternal -}}
    {{- fail "database.mode=sqlite cannot be combined with database.external.*" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "netbird.storeEngine" -}}
{{- if .Values.server.store.engine -}}
{{- .Values.server.store.engine -}}
{{- else -}}
{{- $mode := include "netbird.databaseMode" . -}}
{{- if eq $mode "sqlite" -}}sqlite
{{- else if eq $mode "postgresql" -}}postgres
{{- else -}}{{ .Values.database.external.engine | default "postgres" }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "netbird.postgresqlSecretName" -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}

{{- define "netbird.databasePasswordSecretName" -}}
{{- $mode := include "netbird.databaseMode" . -}}
{{- if eq $mode "postgresql" -}}
{{- include "netbird.postgresqlSecretName" . -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "netbird.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databasePasswordSecretKey" -}}
{{- if eq (include "netbird.databaseMode" .) "postgresql" -}}
user-password
{{- else -}}
{{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databaseHost" -}}
{{- if eq (include "netbird.databaseMode" .) "postgresql" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databasePort" -}}
{{- if eq (include "netbird.databaseMode" .) "postgresql" -}}5432{{- else -}}{{ .Values.database.external.port | toString }}{{- end -}}
{{- end -}}

{{- define "netbird.databaseName" -}}
{{- if eq (include "netbird.databaseMode" .) "postgresql" -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.database.external.name }}{{- end -}}
{{- end -}}

{{- define "netbird.databaseUsername" -}}
{{- if eq (include "netbird.databaseMode" .) "postgresql" -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.database.external.username }}{{- end -}}
{{- end -}}

{{- define "netbird.storeConfigDsn" -}}
{{- if .Values.server.store.dsn -}}
{{- .Values.server.store.dsn -}}
{{- else if and (eq (include "netbird.databaseMode" .) "external") .Values.database.external.dsn -}}
{{- .Values.database.external.dsn -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "netbird.storeDsnEnvName" -}}
{{- if eq (include "netbird.storeEngine" .) "mysql" -}}NETBIRD_STORE_ENGINE_MYSQL_DSN{{- else -}}NETBIRD_STORE_ENGINE_POSTGRES_DSN{{- end -}}
{{- end -}}

{{- define "netbird.storeDsnTemplate" -}}
{{- $mode := include "netbird.databaseMode" . -}}
{{- if eq (include "netbird.storeEngine" .) "mysql" -}}
{{- printf "%s:%s@tcp(%s:%s)/%s" (include "netbird.databaseUsername" .) "$(NETBIRD_DATABASE_PASSWORD)" (include "netbird.databaseHost" .) (include "netbird.databasePort" .) (include "netbird.databaseName" .) -}}
{{- else -}}
{{- printf "host=%s user=%s password=%s dbname=%s port=%s sslmode=%s" (include "netbird.databaseHost" .) (include "netbird.databaseUsername" .) "$(NETBIRD_DATABASE_PASSWORD)" (include "netbird.databaseName" .) (include "netbird.databasePort" .) (ternary "disable" (.Values.database.external.sslMode | default "disable") (eq $mode "postgresql")) -}}
{{- end -}}
{{- end -}}

{{- define "netbird.storeEnv" -}}
{{- $mode := include "netbird.databaseMode" . -}}
{{- $configDsn := include "netbird.storeConfigDsn" . -}}
{{- if and (ne $mode "sqlite") (not .Values.server.store.dsn) (not $configDsn) }}
- name: NETBIRD_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "netbird.databasePasswordSecretName" . }}
      key: {{ include "netbird.databasePasswordSecretKey" . }}
- name: {{ include "netbird.storeDsnEnvName" . }}
  value: {{ include "netbird.storeDsnTemplate" . | quote }}
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
{{- $_ := include "netbird.databaseMode" . -}}
{{- if and (gt (int .Values.server.replicaCount) 1) (eq .Values.server.store.engine "sqlite") -}}
{{- fail "server.replicaCount > 1 requires server.store.engine other than sqlite" -}}
{{- end -}}
{{- if and (gt (int .Values.server.replicaCount) 1) (eq (include "netbird.databaseMode" .) "sqlite") -}}
{{- fail "server.replicaCount > 1 requires database.mode other than sqlite" -}}
{{- end -}}
{{- if and (eq (include "netbird.databaseMode" .) "external") (not .Values.database.external.dsn) (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
{{- fail "database.external.password, database.external.existingSecret, or database.external.dsn is required when database.mode=external" -}}
{{- end -}}
{{- if and (eq (include "netbird.databaseMode" .) "external") (not .Values.database.external.dsn) (not .Values.database.external.host) -}}
{{- fail "database.external.host or database.external.dsn is required when database.mode=external" -}}
{{- end -}}
{{- if and .Values.server.store.engine (not (has .Values.server.store.engine (list "sqlite" "postgres" "mysql"))) -}}
{{- fail "server.store.engine must be one of: sqlite, postgres, mysql" -}}
{{- end -}}
{{- $mode := include "netbird.databaseMode" . -}}
{{- if and .Values.server.store.engine (eq $mode "sqlite") (ne .Values.server.store.engine "sqlite") -}}
{{- fail "server.store.engine must be sqlite when database.mode resolves to sqlite" -}}
{{- end -}}
{{- if and .Values.server.store.engine (eq $mode "postgresql") (ne .Values.server.store.engine "postgres") -}}
{{- fail "server.store.engine must be postgres when database.mode resolves to postgresql" -}}
{{- end -}}
{{- if and .Values.server.store.engine (eq $mode "external") (ne .Values.server.store.engine (.Values.database.external.engine | default "postgres")) -}}
{{- fail "server.store.engine must match database.external.engine when database.mode resolves to external" -}}
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
