{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "authelia.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "authelia.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "authelia.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "authelia.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "authelia.labels" -}}
helm.sh/chart: {{ include "authelia.chart" . }}
{{ include "authelia.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "authelia.selectorLabels" -}}
app.kubernetes.io/name: {{ include "authelia.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Image helper */}}
{{- define "authelia.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Database helpers                                              */}}
{{/* ============================================================ */}}

{{- define "authelia.dbType" -}}
{{- .Values.database.type | default "sqlite" -}}
{{- end -}}

{{- define "authelia.dbHost" -}}
{{- $type := include "authelia.dbType" . -}}
{{- if eq $type "postgres" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- printf "%s-postgresql" .Release.Name -}}
  {{- else -}}
    {{- .Values.database.external.host -}}
  {{- end -}}
{{- else if eq $type "mysql" -}}
  {{- if .Values.mysql.enabled -}}
    {{- printf "%s-mysql" .Release.Name -}}
  {{- else -}}
    {{- .Values.database.external.host -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "authelia.dbPort" -}}
{{- $type := include "authelia.dbType" . -}}
{{- if eq $type "postgres" -}}
  {{- if .Values.database.external.port -}}
    {{- .Values.database.external.port | toString -}}
  {{- else -}}
    5432
  {{- end -}}
{{- else if eq $type "mysql" -}}
  {{- if .Values.database.external.port -}}
    {{- .Values.database.external.port | toString -}}
  {{- else -}}
    3306
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "authelia.dbName" -}}
{{- $type := include "authelia.dbType" . -}}
{{- if eq $type "postgres" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- .Values.postgresql.auth.database -}}
  {{- else -}}
    {{- .Values.database.external.name -}}
  {{- end -}}
{{- else if eq $type "mysql" -}}
  {{- if .Values.mysql.enabled -}}
    {{- .Values.mysql.auth.database -}}
  {{- else -}}
    {{- .Values.database.external.name -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "authelia.dbUsername" -}}
{{- $type := include "authelia.dbType" . -}}
{{- if eq $type "postgres" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- .Values.postgresql.auth.username -}}
  {{- else -}}
    {{- .Values.database.external.username -}}
  {{- end -}}
{{- else if eq $type "mysql" -}}
  {{- if .Values.mysql.enabled -}}
    {{- .Values.mysql.auth.username -}}
  {{- else -}}
    {{- .Values.database.external.username -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "authelia.dbSecretName" -}}
{{- $type := include "authelia.dbType" . -}}
{{- if and (ne $type "sqlite") .Values.database.external.existingSecret -}}
  {{- .Values.database.external.existingSecret -}}
{{- else -}}
  {{- printf "%s-db" (include "authelia.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "authelia.dbSecretPasswordKey" -}}
{{- if .Values.database.external.existingSecret -}}
  {{- .Values.database.external.existingSecretPasswordKey -}}
{{- else -}}
  db-password
{{- end -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Redis helpers                                                 */}}
{{/* ============================================================ */}}

{{- define "authelia.redisEnabled" -}}
{{- if .Values.redis.enabled -}}true{{- end -}}
{{- end -}}

{{- define "authelia.redisHost" -}}
{{- if .Values.redis.enabled -}}
  {{- printf "%s-redis-client" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Secret helpers                                                */}}
{{/* ============================================================ */}}

{{- define "authelia.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
  {{- .Values.secrets.existingSecret -}}
{{- else -}}
  {{- printf "%s-secrets" (include "authelia.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "authelia.secretJwtKey" -}}
{{- if .Values.secrets.existingSecret -}}
  {{- .Values.secrets.existingSecretJwtKey -}}
{{- else -}}
  jwt-secret
{{- end -}}
{{- end -}}

{{- define "authelia.secretSessionKey" -}}
{{- if .Values.secrets.existingSecret -}}
  {{- .Values.secrets.existingSecretSessionKey -}}
{{- else -}}
  session-secret
{{- end -}}
{{- end -}}

{{- define "authelia.secretStorageEncryptionKey" -}}
{{- if .Values.secrets.existingSecret -}}
  {{- .Values.secrets.existingSecretStorageEncryptionKey -}}
{{- else -}}
  storage-encryption-key
{{- end -}}
{{- end -}}

{{- define "authelia.secretOidcHmacKey" -}}
{{- if .Values.secrets.existingSecret -}}
  {{- .Values.secrets.existingSecretOidcHmacKey -}}
{{- else -}}
  oidc-hmac-secret
{{- end -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Users database helpers                                        */}}
{{/* ============================================================ */}}

{{- define "authelia.usersDbSecretName" -}}
{{- if .Values.usersDatabase.existingSecret -}}
  {{- .Values.usersDatabase.existingSecret -}}
{{- else -}}
  {{- printf "%s-users" (include "authelia.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "authelia.usersDbSecretKey" -}}
{{- if .Values.usersDatabase.existingSecret -}}
  {{- .Values.usersDatabase.existingSecretKey -}}
{{- else -}}
  users_database.yml
{{- end -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Persistence helpers                                           */}}
{{/* ============================================================ */}}

{{- define "authelia.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
  {{- .Values.persistence.existingClaim -}}
{{- else -}}
  {{- printf "%s-data" (include "authelia.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Backup helpers                                                */}}
{{/* ============================================================ */}}

{{- define "authelia.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
  {{- .Values.backup.s3.existingSecret -}}
{{- else -}}
  {{- printf "%s-backup" (include "authelia.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ============================================================ */}}
{{/* Configuration builder                                         */}}
{{/* ============================================================ */}}
{{/* Renders the Authelia configuration.yml, overriding storage    */}}
{{/* and session.redis based on chart-level database/redis values  */}}

{{- define "authelia.configuration" -}}
{{- $cfg := deepCopy .Values.config -}}

{{/* Override storage based on database.type */}}
{{- $dbType := include "authelia.dbType" . -}}
{{- if eq $dbType "postgres" -}}
  {{- $_ := unset $cfg.storage "local" -}}
  {{- $pgCfg := dict "host" (include "authelia.dbHost" .) "port" (include "authelia.dbPort" . | int) "database" (include "authelia.dbName" .) "username" (include "authelia.dbUsername" .) "schema" (.Values.database.external.schema | default "public") -}}
  {{- $_ := set $cfg.storage "postgres" $pgCfg -}}
{{- else if eq $dbType "mysql" -}}
  {{- $_ := unset $cfg.storage "local" -}}
  {{- $myCfg := dict "host" (include "authelia.dbHost" .) "port" (include "authelia.dbPort" . | int) "database" (include "authelia.dbName" .) "username" (include "authelia.dbUsername" .) -}}
  {{- $_ := set $cfg.storage "mysql" $myCfg -}}
{{- end -}}

{{/* Add Redis session provider when Redis is enabled */}}
{{- if (include "authelia.redisEnabled" .) -}}
  {{- $redisCfg := dict "host" (include "authelia.redisHost" .) "port" 6379 -}}
  {{- $_ := set $cfg.session "redis" $redisCfg -}}
{{- end -}}

{{ toYaml $cfg }}
{{- end -}}
