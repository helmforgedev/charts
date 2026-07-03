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

{{- define "authelia.validate" -}}
{{- $dbType := include "authelia.dbType" . -}}
{{- if not (has $dbType (list "sqlite" "postgres" "mysql")) -}}
{{- fail (printf "database.type must be one of: sqlite, postgres, mysql (got %s)" $dbType) -}}
{{- end -}}
{{- if and (eq $dbType "postgres") .Values.mysql.enabled -}}
{{- fail "database.type=postgres cannot be used with mysql.enabled=true" -}}
{{- end -}}
{{- if and (eq $dbType "mysql") .Values.postgresql.enabled -}}
{{- fail "database.type=mysql cannot be used with postgresql.enabled=true" -}}
{{- end -}}
{{- if and (eq $dbType "postgres") (not .Values.postgresql.enabled) (not .Values.database.external.host) -}}
{{- fail "database.external.host is required when database.type is not sqlite and no matching database subchart is enabled" -}}
{{- end -}}
{{- if and (eq $dbType "mysql") (not .Values.mysql.enabled) (not .Values.database.external.host) -}}
{{- fail "database.external.host is required when database.type is not sqlite and no matching database subchart is enabled" -}}
{{- end -}}
{{- if and .Values.backup.enabled (not .Values.backup.s3.endpoint) -}}
{{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
{{- end -}}
{{- if and .Values.backup.enabled (not .Values.backup.s3.bucket) -}}
{{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
{{- end -}}
{{- if and .Values.backup.enabled (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
{{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.enabled requires ingress.hosts to contain at least one host" -}}
{{- end -}}
{{- if .Values.ingress.enabled -}}
{{- range $index, $host := .Values.ingress.hosts -}}
{{- if not $host.host -}}
{{- fail (printf "ingress.hosts[%d].host is required when ingress.enabled is true" $index) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and .Values.gateway.enabled (not .Values.gateway.parentRefs) -}}
{{- fail "gateway.enabled requires gateway.parentRefs to be set to create a valid HTTPRoute." -}}
{{- end -}}
{{- range $index, $parentRef := .Values.gateway.parentRefs -}}
{{- if and $.Values.gateway.enabled (not $parentRef.name) -}}
{{- fail (printf "gateway.parentRefs[%d].name is required when gateway.enabled is true" $index) -}}
{{- end -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
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

{{- define "authelia.tcpAddress" -}}
{{- $host := .host | toString | trim -}}
{{- $port := .port | toString | trim -}}
{{- if and (contains ":" $host) (not (hasPrefix "[" $host)) -}}
{{- printf "tcp://[%s]:%s" $host $port -}}
{{- else -}}
{{- printf "tcp://%s:%s" $host $port -}}
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

{{- define "authelia.jwtSecret" -}}
{{- if .Values.secrets.jwtSecret -}}
  {{- .Values.secrets.jwtSecret -}}
{{- else -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-secrets" (include "authelia.fullname" .)) -}}
  {{- if and $secret $secret.data (hasKey $secret.data "jwt-secret") -}}
    {{- index $secret.data "jwt-secret" | b64dec -}}
  {{- else -}}
    {{- randAlphaNum 64 -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "authelia.sessionSecret" -}}
{{- if .Values.secrets.sessionSecret -}}
  {{- .Values.secrets.sessionSecret -}}
{{- else -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-secrets" (include "authelia.fullname" .)) -}}
  {{- if and $secret $secret.data (hasKey $secret.data "session-secret") -}}
    {{- index $secret.data "session-secret" | b64dec -}}
  {{- else -}}
    {{- randAlphaNum 64 -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "authelia.storageEncryptionKey" -}}
{{- if .Values.secrets.storageEncryptionKey -}}
  {{- .Values.secrets.storageEncryptionKey -}}
{{- else -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-secrets" (include "authelia.fullname" .)) -}}
  {{- if and $secret $secret.data (hasKey $secret.data "storage-encryption-key") -}}
    {{- index $secret.data "storage-encryption-key" | b64dec -}}
  {{- else -}}
    {{- randAlphaNum 64 -}}
  {{- end -}}
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
  {{- $pgAddress := include "authelia.tcpAddress" (dict "host" (include "authelia.dbHost" .) "port" (include "authelia.dbPort" .)) -}}
  {{- $pgCfg := dict "address" $pgAddress "database" (include "authelia.dbName" .) "username" (include "authelia.dbUsername" .) "schema" (.Values.database.external.schema | default "public") -}}
  {{- $_ := set $cfg.storage "postgres" $pgCfg -}}
{{- else if eq $dbType "mysql" -}}
  {{- $_ := unset $cfg.storage "local" -}}
  {{- $myAddress := include "authelia.tcpAddress" (dict "host" (include "authelia.dbHost" .) "port" (include "authelia.dbPort" .)) -}}
  {{- $myCfg := dict "address" $myAddress "database" (include "authelia.dbName" .) "username" (include "authelia.dbUsername" .) -}}
  {{- $_ := set $cfg.storage "mysql" $myCfg -}}
{{- end -}}

{{/* Add Redis session provider when Redis is enabled */}}
{{- if (include "authelia.redisEnabled" .) -}}
  {{- $redisCfg := dict "host" (include "authelia.redisHost" .) "port" 6379 -}}
  {{- $_ := set $cfg.session "redis" $redisCfg -}}
{{- end -}}

{{ toYaml $cfg }}
{{- end -}}
