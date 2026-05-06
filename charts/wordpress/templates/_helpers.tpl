# SPDX-License-Identifier: Apache-2.0
{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "wordpress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "wordpress.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "wordpress.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "wordpress.labels" -}}
helm.sh/chart: {{ include "wordpress.chart" . }}
{{ include "wordpress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: wordpress
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "wordpress.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wordpress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "wordpress.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "wordpress.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image string with tag fallback to appVersion.
*/}}
{{- define "wordpress.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{/*
ExternalSecret feature flags.
*/}}
{{- define "wordpress.externalSecretAdminEnabled" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.admin.enabled -}}true{{- end -}}
{{- end -}}

{{- define "wordpress.externalSecretDatabaseEnabled" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled -}}true{{- end -}}
{{- end -}}

{{- define "wordpress.externalSecretBackupEnabled" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.backup.enabled -}}true{{- end -}}
{{- end -}}

{{/*
Database mode detection (auto | external | mysql).
Auto precedence:
  1. database.external.host or database.external.existingSecret → external
  2. mysql.enabled → mysql
  3. fail (WordPress requires a database)
*/}}
{{- define "wordpress.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "mysql")) -}}
{{- fail (printf "database.mode must be one of: auto, external, mysql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasMysql -}}
    {{- fail "wordpress database selection is ambiguous: configure only one of database.external.host or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasMysql -}}mysql
  {{- else -}}
    {{- fail "wordpress requires a database: set database.external.host or mysql.enabled=true" -}}
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}
  {{- end -}}
  {{- if and (eq $mode "external") $hasMysql -}}
    {{- fail "database.mode=external cannot be combined with mysql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}
    {{- fail "database.mode=mysql requires mysql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") $hasExternal -}}
    {{- fail "database.mode=mysql cannot be combined with database.external" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{/*
Database host.
*/}}
{{- define "wordpress.databaseHost" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Database port.
*/}}
{{- define "wordpress.databasePort" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.port | default 3306 | toString -}}
{{- else -}}
{{- print "3306" -}}
{{- end -}}
{{- end -}}

{{/*
Database name.
*/}}
{{- define "wordpress.databaseName" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.mysql.auth.database -}}
{{- end -}}
{{- end -}}

{{/*
Database username.
*/}}
{{- define "wordpress.databaseUsername" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.mysql.auth.username -}}
{{- end -}}
{{- end -}}

{{/*
Database password secret name.
*/}}
{{- define "wordpress.databaseSecretName" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if and (eq (include "wordpress.externalSecretDatabaseEnabled" .) "true") .Values.externalSecrets.database.targetName -}}
{{- .Values.externalSecrets.database.targetName -}}
{{- else if eq (include "wordpress.externalSecretDatabaseEnabled" .) "true" -}}
{{- printf "%s-database" (include "wordpress.fullname" .) -}}
{{- else if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq $mode "mysql" -}}
{{- printf "%s-mysql-auth" .Release.Name -}}
{{- else -}}
{{- printf "%s-database" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Database password secret key.
*/}}
{{- define "wordpress.databaseSecretKey" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq $mode "mysql" -}}
{{- print "mysql-user-password" -}}
{{- else -}}
{{- print "database-password" -}}
{{- end -}}
{{- end -}}

{{/*
Database password value (for generating secrets).
*/}}
{{- define "wordpress.databasePasswordValue" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.password -}}
{{- else -}}
{{- .Values.mysql.auth.password -}}
{{- end -}}
{{- end -}}

{{/*
Admin secret name.
*/}}
{{- define "wordpress.adminSecretName" -}}
{{- if and (eq (include "wordpress.externalSecretAdminEnabled" .) "true") .Values.externalSecrets.admin.targetName -}}
{{- .Values.externalSecrets.admin.targetName -}}
{{- else if eq (include "wordpress.externalSecretAdminEnabled" .) "true" -}}
{{- printf "%s-admin" (include "wordpress.fullname" .) -}}
{{- else if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Admin secret key.
*/}}
{{- define "wordpress.adminSecretKey" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecretPasswordKey -}}
{{- else -}}
{{- print "admin-password" -}}
{{- end -}}
{{- end -}}

{{/*
Backup enabled (with validation).
*/}}
{{- define "wordpress.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (ne (include "wordpress.externalSecretBackupEnabled" .) "true") (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires backup.s3.existingSecret, externalSecrets.backup.enabled, or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{/*
Backup S3 secret name.
*/}}
{{- define "wordpress.backupSecretName" -}}
{{- if and (eq (include "wordpress.externalSecretBackupEnabled" .) "true") .Values.externalSecrets.backup.targetName -}}
{{- .Values.externalSecrets.backup.targetName -}}
{{- else if eq (include "wordpress.externalSecretBackupEnabled" .) "true" -}}
{{- printf "%s-backup" (include "wordpress.fullname" .) -}}
{{- else if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup database host (override or fallback to app).
*/}}
{{- define "wordpress.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "wordpress.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database port.
*/}}
{{- define "wordpress.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "wordpress.databasePort" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database name.
*/}}
{{- define "wordpress.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "wordpress.databaseName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database username.
*/}}
{{- define "wordpress.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "wordpress.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret name.
*/}}
{{- define "wordpress.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "wordpress.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret key.
*/}}
{{- define "wordpress.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "wordpress.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}

{{/*
ConfigMap name.
*/}}
{{- define "wordpress.configMapName" -}}
{{- printf "%s-config" (include "wordpress.fullname" .) -}}
{{- end -}}

{{/*
Redis object cache helpers.
*/}}
{{- define "wordpress.objectCacheRedisEnabled" -}}
{{- if and .Values.objectCache.enabled (eq .Values.objectCache.provider "redis-cache") -}}true{{- end -}}
{{- end -}}

{{- define "wordpress.redisSubchartFullname" -}}
{{- $redisValues := default dict .Values.redis -}}
{{- $fullnameOverride := default "" (get $redisValues "fullnameOverride") -}}
{{- $nameOverride := default "" (get $redisValues "nameOverride") -}}
{{- if $fullnameOverride -}}
{{- $fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" $nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.redisHost" -}}
{{- if eq .Values.objectCache.redis.mode "external" -}}
{{- .Values.objectCache.redis.external.host -}}
{{- else -}}
{{- printf "%s-client" (include "wordpress.redisSubchartFullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.redisSecretName" -}}
{{- $redisValues := default dict .Values.redis -}}
{{- $redisAuth := default dict (get $redisValues "auth") -}}
{{- if .Values.objectCache.redis.auth.existingSecret -}}
{{- .Values.objectCache.redis.auth.existingSecret -}}
{{- else if eq .Values.objectCache.redis.mode "external" -}}
{{- printf "%s-redis-auth" (include "wordpress.fullname" .) -}}
{{- else if get $redisAuth "existingSecret" -}}
{{- get $redisAuth "existingSecret" -}}
{{- else -}}
{{- printf "%s-auth" (include "wordpress.redisSubchartFullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.redisSecretKey" -}}
{{- $redisValues := default dict .Values.redis -}}
{{- $redisAuth := default dict (get $redisValues "auth") -}}
{{- if .Values.objectCache.redis.auth.existingSecret -}}
{{- .Values.objectCache.redis.auth.existingSecretPasswordKey -}}
{{- else if and (eq .Values.objectCache.redis.mode "subchart") (get $redisAuth "existingSecret") -}}
{{- default "redis-password" (get $redisAuth "existingSecretPasswordKey") -}}
{{- else -}}
{{- .Values.objectCache.redis.auth.existingSecretPasswordKey -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.redisPasswordEnabled" -}}
{{- $redisValues := default dict .Values.redis -}}
{{- $redisAuth := default dict (get $redisValues "auth") -}}
{{- $subchartAuthEnabled := true -}}
{{- if hasKey $redisAuth "enabled" -}}
{{- $subchartAuthEnabled = get $redisAuth "enabled" -}}
{{- end -}}
{{- if and (eq (include "wordpress.objectCacheRedisEnabled" .) "true") .Values.objectCache.redis.auth.enabled -}}
{{- if or (eq .Values.objectCache.redis.mode "external") $subchartAuthEnabled -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.redisPrefix" -}}
{{- if .Values.objectCache.redis.prefix -}}
{{- .Values.objectCache.redis.prefix -}}
{{- else -}}
{{- printf "%s:" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.pluginsJobEnabled" -}}
{{- if and .Values.plugins.enabled .Values.plugins.installer.enabled -}}true{{- end -}}
{{- end -}}

{{/*
Generated wp-config.php additions derived from structured values.
*/}}
{{- define "wordpress.generatedConfigExtra" -}}
{{- if .Values.wordpress.forceSSLAdmin }}
define('FORCE_SSL_ADMIN', true);
{{- end }}
{{- if .Values.wordpress.disallowFileEdit }}
define('DISALLOW_FILE_EDIT', true);
{{- end }}
{{- if or .Values.wordpress.disableWpCron .Values.wpCron.cronJob.enabled }}
define('DISABLE_WP_CRON', true);
{{- end }}
{{- with .Values.wordpress.memoryLimit }}
define('WP_MEMORY_LIMIT', {{ . | quote }});
{{- end }}
{{- with .Values.wordpress.maxMemoryLimit }}
define('WP_MAX_MEMORY_LIMIT', {{ . | quote }});
{{- end }}
{{- if eq (include "wordpress.objectCacheRedisEnabled" .) "true" }}
define('WP_CACHE', true);
define('WP_REDIS_CLIENT', {{ .Values.objectCache.redis.client | quote }});
define('WP_REDIS_SCHEME', {{ .Values.objectCache.redis.scheme | quote }});
define('WP_REDIS_HOST', {{ include "wordpress.redisHost" . | quote }});
define('WP_REDIS_PORT', {{ int .Values.objectCache.redis.port }});
define('WP_REDIS_DATABASE', {{ int .Values.objectCache.redis.database }});
define('WP_REDIS_PREFIX', {{ include "wordpress.redisPrefix" . | quote }});
{{- if eq (include "wordpress.redisPasswordEnabled" .) "true" }}
define('WP_REDIS_PASSWORD', getenv('WP_REDIS_PASSWORD'));
{{- end }}
{{- with .Values.objectCache.redis.maxTtl }}
define('WP_REDIS_MAXTTL', {{ int . }});
{{- end }}
{{- end }}
{{- with .Values.wordpress.configExtra }}
{{ . }}
{{- end }}
{{- end -}}

{{/* ExternalSecret remoteRef item */}}
{{- define "wordpress.externalSecretDataItem" -}}
- secretKey: {{ .secretKey | quote }}
  remoteRef:
    {{- if not .remoteRef.key }}
    {{- fail (printf "%s.key is required when %s=true" .remoteRefName .enabledName) }}
    {{- end }}
    key: {{ .remoteRef.key | quote }}
    {{- with .remoteRef.property }}
    property: {{ . | quote }}
    {{- end }}
    {{- with .remoteRef.version }}
    version: {{ . | quote }}
    {{- end }}
    {{- with .remoteRef.decodingStrategy }}
    decodingStrategy: {{ . | quote }}
    {{- end }}
    {{- with .remoteRef.conversionStrategy }}
    conversionStrategy: {{ . | quote }}
    {{- end }}
{{- end -}}

{{/* Validate ExternalSecret settings */}}
{{- define "wordpress.validateExternalSecrets" -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if ne .Values.externalSecrets.apiVersion "external-secrets.io/v1" -}}
    {{- fail "externalSecrets.apiVersion must be external-secrets.io/v1" -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.admin.enabled (not .Values.externalSecrets.enabled) -}}
{{- fail "externalSecrets.enabled must be true when externalSecrets.admin.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.database.enabled (not .Values.externalSecrets.enabled) -}}
{{- fail "externalSecrets.enabled must be true when externalSecrets.database.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.backup.enabled (not .Values.externalSecrets.enabled) -}}
{{- fail "externalSecrets.enabled must be true when externalSecrets.backup.enabled=true" -}}
{{- end -}}
{{- if and .Values.admin.existingSecret (eq (include "wordpress.externalSecretAdminEnabled" .) "true") -}}
{{- fail "admin.existingSecret and externalSecrets.admin.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.database.external.existingSecret (eq (include "wordpress.externalSecretDatabaseEnabled" .) "true") -}}
{{- fail "database.external.existingSecret and externalSecrets.database.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.backup.s3.existingSecret (eq (include "wordpress.externalSecretBackupEnabled" .) "true") -}}
{{- fail "backup.s3.existingSecret and externalSecrets.backup.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and (eq (include "wordpress.externalSecretDatabaseEnabled" .) "true") (ne (include "wordpress.databaseMode" .) "external") -}}
{{- fail "externalSecrets.database.enabled requires database.mode=external or database.external.host" -}}
{{- end -}}
{{- if and (eq (include "wordpress.externalSecretBackupEnabled" .) "true") (not .Values.backup.enabled) -}}
{{- fail "externalSecrets.backup.enabled requires backup.enabled=true" -}}
{{- end -}}
{{- end -}}

{{/* Validate object cache and plugin settings */}}
{{- define "wordpress.validatePlugins" -}}
{{- if and (eq (include "wordpress.pluginsJobEnabled" .) "true") (not .Values.persistence.enabled) -}}
  {{- fail "plugins.installer.enabled requires persistence.enabled=true so installed plugins are written to the WordPress volume" -}}
{{- end -}}
{{- if .Values.objectCache.enabled -}}
  {{- if not .Values.plugins.enabled -}}
    {{- fail "plugins.enabled must be true when objectCache.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.plugins.installer.enabled -}}
    {{- fail "plugins.installer.enabled must be true when objectCache.enabled is true" -}}
  {{- end -}}
{{- end -}}
{{- range .Values.plugins.items -}}
  {{- if hasKey . "source" -}}
    {{- fail "plugins.items[].source is not supported; use official WordPress.org plugin slugs only" -}}
  {{- end -}}
  {{- if hasKey . "activateSlug" -}}
    {{- fail "plugins.items[].activateSlug is not supported; use official WordPress.org plugin slugs only" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.objectCache.enabled -}}
  {{- if ne .Values.objectCache.provider "redis-cache" -}}
    {{- fail "objectCache.provider currently supports only redis-cache" -}}
  {{- end -}}
  {{- if not (has .Values.objectCache.redis.mode (list "subchart" "external")) -}}
    {{- fail "objectCache.redis.mode must be subchart or external" -}}
  {{- end -}}
  {{- if and (eq .Values.objectCache.redis.mode "subchart") (not .Values.objectCache.redis.subchart.enabled) -}}
    {{- fail "objectCache.redis.subchart.enabled must be true when objectCache.redis.mode=subchart" -}}
  {{- end -}}
  {{- if and (eq .Values.objectCache.redis.mode "external") (not .Values.objectCache.redis.external.host) -}}
    {{- fail "objectCache.redis.external.host is required when objectCache.redis.mode=external" -}}
  {{- end -}}
  {{- if and .Values.objectCache.redis.auth.enabled (eq .Values.objectCache.redis.mode "external") (not .Values.objectCache.redis.auth.existingSecret) (not .Values.objectCache.redis.auth.password) -}}
    {{- fail "objectCache.redis.auth.existingSecret or objectCache.redis.auth.password is required when external Redis auth is enabled" -}}
  {{- end -}}
{{- end -}}
{{- range $i, $plugin := .Values.plugins.items }}
  {{- if not $plugin.slug -}}
    {{- fail (printf "plugins.items[%d].slug is required" $i) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* Validate Gateway API settings */}}
{{- define "wordpress.validateGatewayAPI" -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.parentRefs) -}}
{{- fail "gatewayAPI.parentRefs must contain at least one parentRef when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- end -}}
