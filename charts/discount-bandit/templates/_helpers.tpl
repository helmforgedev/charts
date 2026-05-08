{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "discount-bandit.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "discount-bandit.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "discount-bandit.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "discount-bandit.labels" -}}
helm.sh/chart: {{ include "discount-bandit.chart" . }}
{{ include "discount-bandit.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "discount-bandit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "discount-bandit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "discount-bandit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "discount-bandit.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "discount-bandit.mysqlName" -}}
{{- default "mysql" .Values.mysql.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "discount-bandit.mysqlFullname" -}}
{{- if .Values.mysql.fullnameOverride -}}
{{- .Values.mysql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "discount-bandit.mysqlName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "mysql" "external" "sqlite")) -}}
{{- fail (printf "database.mode must be one of: auto, mysql, external, sqlite (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := ne (.Values.database.external.host | default "") "" -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- $hasSqlite := .Values.database.sqlite.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasMysql -}}
    {{- fail "discount-bandit database selection is ambiguous: configure only one of database.external.host or mysql.enabled" -}}
  {{- end -}}
  {{- if and (or $hasExternal $hasMysql) $hasSqlite -}}
    {{- fail "discount-bandit database selection is ambiguous: sqlite mode cannot be combined with mysql or external database" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasMysql -}}mysql
  {{- else if $hasSqlite -}}sqlite
  {{- else -}}{{- fail "discount-bandit requires a database: keep mysql.enabled=true, configure database.external.host, or set database.sqlite.enabled=true" -}}
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}{{- fail "database.mode=mysql requires mysql.enabled=true" -}}{{- end -}}
  {{- if and (eq $mode "mysql") (or $hasExternal $hasSqlite) -}}{{- fail "database.mode=mysql cannot be combined with database.external or database.sqlite.enabled" -}}{{- end -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}{{- fail "database.mode=external requires database.external.host" -}}{{- end -}}
  {{- if and (eq $mode "external") (or $hasMysql $hasSqlite) -}}{{- fail "database.mode=external cannot be combined with mysql.enabled or database.sqlite.enabled" -}}{{- end -}}
  {{- if and (eq $mode "sqlite") (or $hasMysql $hasExternal) -}}{{- fail "database.mode=sqlite cannot be combined with mysql.enabled or database.external" -}}{{- end -}}
  {{- if and (eq $mode "sqlite") (not $hasSqlite) -}}{{- fail "database.mode=sqlite requires database.sqlite.enabled=true" -}}{{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.validateDatabase" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "external" -}}
  {{- if and (not .Values.database.external.password) (not .Values.database.external.existingSecret) (not (and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled)) -}}
    {{- fail "database.mode=external requires database.external.password, database.external.existingSecret, or externalSecrets.database.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseConnection" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "sqlite" -}}sqlite{{- else if eq $mode "external" -}}{{ .Values.database.external.type | default "mysql" }}{{- else -}}mysql{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseHost" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "external" -}}{{ .Values.database.external.host }}{{- else -}}{{ include "discount-bandit.mysqlFullname" . }}{{- end -}}
{{- end -}}

{{- define "discount-bandit.databasePort" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "external" -}}{{ .Values.database.external.port | default 3306 | toString }}{{- else -}}3306{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseName" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "external" -}}{{ .Values.database.external.name }}{{- else -}}{{ .Values.mysql.auth.database }}{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseUsername" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "external" -}}{{ .Values.database.external.username }}{{- else -}}{{ .Values.mysql.auth.username }}{{- end -}}
{{- end -}}

{{- define "discount-bandit.appSecretName" -}}
{{- if .Values.discountBandit.existingSecret -}}
{{- .Values.discountBandit.existingSecret -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.app.enabled .Values.externalSecrets.app.targetName -}}
{{- .Values.externalSecrets.app.targetName -}}
{{- else -}}
{{- printf "%s-app" (include "discount-bandit.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseSecretName" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "mysql" -}}
{{- if .Values.mysql.auth.existingSecret -}}
{{- .Values.mysql.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "discount-bandit.mysqlFullname" .) -}}
{{- end -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled .Values.externalSecrets.database.targetName -}}
{{- .Values.externalSecrets.database.targetName -}}
{{- else -}}
{{- printf "%s-db" (include "discount-bandit.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.databaseSecretPasswordKey" -}}
{{- $mode := include "discount-bandit.databaseMode" . -}}
{{- if eq $mode "mysql" -}}
{{- .Values.mysql.auth.existingSecretUserPasswordKey | default "mysql-user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "database-password" -}}
{{- else -}}
{{- "database-password" -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.dataClaimName" -}}
{{- if .Values.persistence.database.existingClaim -}}
{{- .Values.persistence.database.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "discount-bandit.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.logsClaimName" -}}
{{- if .Values.persistence.logs.existingClaim -}}
{{- .Values.persistence.logs.existingClaim -}}
{{- else -}}
{{- printf "%s-logs" (include "discount-bandit.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.validateExternalSecrets" -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if ne .Values.externalSecrets.apiVersion "external-secrets.io/v1" -}}
    {{- fail "externalSecrets.apiVersion must be external-secrets.io/v1" -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.app.enabled .Values.discountBandit.existingSecret -}}
    {{- fail "externalSecrets.app.enabled cannot be combined with discountBandit.existingSecret" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.app.enabled (not .Values.externalSecrets.app.appKeyRemoteRef.key) -}}
    {{- fail "externalSecrets.app.appKeyRemoteRef.key is required when externalSecrets.app.enabled=true" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.database.enabled (ne (include "discount-bandit.databaseMode" .) "external") -}}
    {{- fail "externalSecrets.database.enabled requires database.mode=external" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.database.enabled .Values.database.external.existingSecret -}}
    {{- fail "externalSecrets.database.enabled cannot be combined with database.external.existingSecret" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.database.enabled (not .Values.externalSecrets.database.passwordRemoteRef.key) -}}
    {{- fail "externalSecrets.database.passwordRemoteRef.key is required when externalSecrets.database.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "discount-bandit.externalSecretDataItem" -}}
- secretKey: {{ .secretKey | quote }}
  remoteRef:
    key: {{ required (printf "%s.key is required" .remoteRefName) .remoteRef.key | quote }}
    {{- with .remoteRef.property }}
    property: {{ . | quote }}
    {{- end }}
{{- end -}}
