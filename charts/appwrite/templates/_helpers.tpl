{{- define "appwrite.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "appwrite.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "appwrite.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "appwrite.labels" -}}
helm.sh/chart: {{ include "appwrite.chart" . }}
{{ include "appwrite.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "appwrite.selectorLabels" -}}
app.kubernetes.io/name: {{ include "appwrite.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Component-specific selector labels.
Usage: {{ include "appwrite.componentLabels" (dict "root" . "component" "api") }}
*/}}
{{- define "appwrite.componentLabels" -}}
{{ include "appwrite.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "appwrite.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "appwrite.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{- define "appwrite.consoleImage" -}}
{{- printf "%s:%s" .Values.console.image.repository .Values.console.image.tag -}}
{{- end -}}

{{/* ---- Secret name ---- */}}
{{- define "appwrite.secretName" -}}
{{- if .Values.appwrite.existingSecret -}}
{{- .Values.appwrite.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "appwrite.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ---- Database helpers ---- */}}
{{- define "appwrite.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasSubchart := .Values.mariadb.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasSubchart -}}
    {{- fail "appwrite database selection is ambiguous: configure only one of database.external.* or mariadb.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasSubchart -}}subchart
  {{- else -}}{{- fail "appwrite requires MariaDB: enable mariadb.enabled or configure database.external.host" -}}
  {{- end -}}
{{- else if eq $mode "external" -}}
  {{- if not $hasExternal -}}
    {{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}
  {{- end -}}
external
{{- else -}}
  {{- fail (printf "database.mode must be one of: auto, external (got %s)" $mode) -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.databaseHost" -}}
{{- if eq (include "appwrite.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.databasePort" -}}
{{- if eq (include "appwrite.databaseMode" .) "external" -}}
{{- .Values.database.external.port | default 3306 | toString -}}
{{- else -}}
3306
{{- end -}}
{{- end -}}

{{- define "appwrite.databaseName" -}}
{{- if eq (include "appwrite.databaseMode" .) "external" -}}
{{- .Values.database.external.name | default "appwrite" -}}
{{- else -}}
{{- .Values.mariadb.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.databaseRootUser" -}}
{{- if eq (include "appwrite.databaseMode" .) "external" -}}
{{- .Values.database.external.rootUser | default "root" -}}
{{- else -}}
root
{{- end -}}
{{- end -}}

{{- define "appwrite.databaseSecretName" -}}
{{- if and (eq (include "appwrite.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "appwrite.databaseMode" .) "external" -}}
{{- printf "%s-database" (include "appwrite.fullname" .) -}}
{{- else -}}
{{- printf "%s-mariadb-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.databaseSecretKey" -}}
{{- if and (eq (include "appwrite.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "mariadb-root-password" -}}
{{- else -}}
mariadb-root-password
{{- end -}}
{{- end -}}

{{/* Appwrite uses mysql:// DSN scheme */}}
{{- define "appwrite.databaseDsn" -}}
mysql://$(DB_USER):$(DB_PASS)@{{ include "appwrite.databaseHost" . }}:{{ include "appwrite.databasePort" . }}/{{ include "appwrite.databaseName" . }}
{{- end -}}

{{/* ---- Redis helpers ---- */}}
{{- define "appwrite.cacheMode" -}}
{{- $hasExternal := or (ne (.Values.cache.external.host | default "") "") (ne (.Values.cache.external.existingSecret | default "") "") -}}
{{- $hasSubchart := .Values.redis.enabled | default false -}}
{{- if and $hasExternal $hasSubchart -}}
{{- fail "appwrite cache selection is ambiguous: configure only one of cache.external.* or redis.enabled" -}}
{{- end -}}
{{- if $hasExternal -}}external
{{- else if $hasSubchart -}}subchart
{{- else -}}{{- fail "appwrite requires Redis: enable redis.enabled or configure cache.external.host" -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.redisHost" -}}
{{- if eq (include "appwrite.cacheMode" .) "external" -}}
{{- .Values.cache.external.host -}}
{{- else -}}
{{- printf "%s-redis-client" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.redisPort" -}}
{{- if eq (include "appwrite.cacheMode" .) "external" -}}
{{- .Values.cache.external.port | default 6379 | toString -}}
{{- else -}}
6379
{{- end -}}
{{- end -}}

{{- define "appwrite.redisSecretName" -}}
{{- if and (eq (include "appwrite.cacheMode" .) "external") .Values.cache.external.existingSecret -}}
{{- .Values.cache.external.existingSecret -}}
{{- else if eq (include "appwrite.cacheMode" .) "external" -}}
{{- printf "%s-redis" (include "appwrite.fullname" .) -}}
{{- else -}}
{{- printf "%s-redis-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "appwrite.redisSecretKey" -}}
{{- if and (eq (include "appwrite.cacheMode" .) "external") .Values.cache.external.existingSecret -}}
{{- .Values.cache.external.existingSecretPasswordKey | default "redis-password" -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{/*
Appwrite Redis URL: redis://:password@host:port
*/}}
{{- define "appwrite.redisUrl" -}}
redis://:$(REDIS_PASS)@{{ include "appwrite.redisHost" . }}:{{ include "appwrite.redisPort" . }}
{{- end -}}

{{/* ---- Domain ---- */}}
{{- define "appwrite.domain" -}}
{{- if .Values.appwrite.domain -}}
{{- .Values.appwrite.domain -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- (index .Values.ingress.hosts 0).host -}}
{{- else -}}
localhost
{{- end -}}
{{- end -}}

{{/* ---- Shared env block for all Appwrite containers ---- */}}
{{- define "appwrite.commonEnv" -}}
- name: _APP_ENV
  value: production
- name: _APP_LOCALE
  value: {{ .Values.appwrite.locale | default "en" | quote }}
- name: _APP_DOMAIN
  value: {{ include "appwrite.domain" . | quote }}
- name: _APP_DOMAIN_TARGET
  value: {{ include "appwrite.domain" . | quote }}
- name: _APP_DOMAIN_FUNCTIONS
  value: {{ include "appwrite.domain" . | quote }}
- name: _APP_CONSOLE_WHITELIST_ROOT
  value: "enabled"
- name: _APP_OPENSSL_KEY_V1
  valueFrom:
    secretKeyRef:
      name: {{ include "appwrite.secretName" . }}
      key: {{ .Values.appwrite.existingSecretOpenSslKey | default "appwrite-openssl-key" }}
- name: _APP_REDIS_HOST
  value: {{ include "appwrite.redisHost" . | quote }}
- name: _APP_REDIS_PORT
  value: {{ include "appwrite.redisPort" . | quote }}
- name: REDIS_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "appwrite.redisSecretName" . }}
      key: {{ include "appwrite.redisSecretKey" . }}
- name: _APP_REDIS_PASS
  value: "$(REDIS_PASS)"
- name: DB_USER
  value: {{ include "appwrite.databaseRootUser" . | quote }}
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "appwrite.databaseSecretName" . }}
      key: {{ include "appwrite.databaseSecretKey" . }}
- name: _APP_DB_HOST
  value: {{ include "appwrite.databaseHost" . | quote }}
- name: _APP_DB_PORT
  value: {{ include "appwrite.databasePort" . | quote }}
- name: _APP_DB_SCHEMA
  value: {{ include "appwrite.databaseName" . | quote }}
- name: _APP_DB_USER
  value: "$(DB_USER)"
- name: _APP_DB_PASS
  value: "$(DB_PASS)"
- name: _APP_USAGE_STATS
  value: {{ .Values.appwrite.usageStats | default "enabled" | quote }}
- name: _APP_GRAPHQL_MAX_BATCH_SIZE
  value: "10"
- name: _APP_GRAPHQL_MAX_COMPLEXITY
  value: "250"
- name: _APP_GRAPHQL_MAX_DEPTH
  value: "3"
{{- if .Values.appwrite.logging.provider }}
- name: _APP_LOGGING_PROVIDER
  value: {{ .Values.appwrite.logging.provider | quote }}
{{- end }}
{{- if .Values.appwrite.logging.sentryDsn }}
- name: _APP_LOGGING_CONFIG
  value: {{ .Values.appwrite.logging.sentryDsn | quote }}
{{- end }}
{{- if .Values.appwrite.smtp.host }}
- name: _APP_SMTP_HOST
  value: {{ .Values.appwrite.smtp.host | quote }}
- name: _APP_SMTP_PORT
  value: {{ .Values.appwrite.smtp.port | default "" | quote }}
- name: _APP_SMTP_SECURE
  value: {{ .Values.appwrite.smtp.secure | default "" | quote }}
- name: _APP_SMTP_USERNAME
  value: {{ .Values.appwrite.smtp.username | default "" | quote }}
{{- if or .Values.appwrite.smtp.password .Values.appwrite.smtp.existingSecret }}
- name: _APP_SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.appwrite.smtp.existingSecret }}{{ .Values.appwrite.smtp.existingSecret }}{{ else }}{{ include "appwrite.secretName" . }}{{ end }}
      key: {{ .Values.appwrite.smtp.existingSecretPasswordKey | default "smtp-password" }}
{{- end }}
{{- end }}
- name: _APP_STORAGE_LIMIT
  value: {{ .Values.appwrite.storage.limit | default 30000000 | toString | quote }}
- name: _APP_STORAGE_ANTIVIRUS
  value: {{ .Values.appwrite.storage.antivirus | default "disabled" | quote }}
- name: _APP_FUNCTIONS_TIMEOUT
  value: {{ .Values.appwrite.functions.timeout | default 900 | toString | quote }}
{{- if .Values.appwrite.functions.runtimes }}
- name: _APP_FUNCTIONS_RUNTIMES
  value: {{ .Values.appwrite.functions.runtimes | quote }}
{{- end }}
{{- with .Values.appwrite.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* ---- Shared volume mounts for pods that need data access ---- */}}
{{- define "appwrite.sharedVolumeMounts" -}}
- name: uploads
  mountPath: /storage/uploads
- name: cache
  mountPath: /storage/cache
- name: certificates
  mountPath: /storage/certificates
- name: functions
  mountPath: /storage/functions
- name: builds
  mountPath: /storage/builds
- name: sites
  mountPath: /storage/sites
{{- with .Values.extraVolumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* ---- Shared volumes ---- */}}
{{- define "appwrite.sharedVolumes" -}}
{{- if .Values.persistence.enabled }}
- name: uploads
  persistentVolumeClaim:
    claimName: {{ include "appwrite.fullname" . }}-uploads
- name: cache
  persistentVolumeClaim:
    claimName: {{ include "appwrite.fullname" . }}-cache
- name: certificates
  persistentVolumeClaim:
    claimName: {{ include "appwrite.fullname" . }}-certificates
- name: functions
  persistentVolumeClaim:
    claimName: {{ include "appwrite.fullname" . }}-functions
- name: builds
  persistentVolumeClaim:
    claimName: {{ include "appwrite.fullname" . }}-builds
- name: sites
  persistentVolumeClaim:
    claimName: {{ include "appwrite.fullname" . }}-sites
{{- else }}
- name: uploads
  emptyDir: {}
- name: cache
  emptyDir: {}
- name: certificates
  emptyDir: {}
- name: functions
  emptyDir: {}
- name: builds
  emptyDir: {}
- name: sites
  emptyDir: {}
{{- end }}
{{- with .Values.extraVolumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* ---- Probes for HTTP services (api, realtime) ---- */}}
{{- define "appwrite.httpLivenessProbe" -}}
{{- if .Values.livenessProbe.enabled }}
livenessProbe:
  tcpSocket:
    port: http
  initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
{{- end }}
{{- end -}}

{{- define "appwrite.httpReadinessProbe" -}}
{{- if .Values.readinessProbe.enabled }}
readinessProbe:
  tcpSocket:
    port: http
  initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
{{- end }}
{{- end -}}

{{- define "appwrite.httpStartupProbe" -}}
{{- if .Values.startupProbe.enabled }}
startupProbe:
  tcpSocket:
    port: http
  initialDelaySeconds: {{ .Values.startupProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.startupProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.startupProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.startupProbe.failureThreshold }}
{{- end }}
{{- end -}}
