{{- define "ckan.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ckan.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ckan.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ckan.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ckan.labels" -}}
helm.sh/chart: {{ include "ckan.chart" . }}
{{ include "ckan.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ckan.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ckan.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ckan.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{- define "ckan.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ckan.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Secret
# =============================================================================

{{- define "ckan.secretName" -}}
{{- if .Values.ckan.existingSecret -}}
{{- .Values.ckan.existingSecret -}}
{{- else -}}
{{- include "ckan.fullname" . -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Database
# =============================================================================

{{- define "ckan.databaseHost" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "ckan.databasePort" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.port | toString -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{- define "ckan.databaseName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.ckanDatabase -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "ckan.databaseUsername" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "ckan.databaseSecretName" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq .Values.database.mode "external" -}}
{{- printf "%s-database" (include "ckan.fullname" .) -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "ckan.databaseSecretKey" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq .Values.database.mode "external" -}}
database-password
{{- else -}}
user-password
{{- end -}}
{{- end -}}

{{/*
CKAN_SQLALCHEMY_URL template — password injected at runtime via shell export.
*/}}
{{- define "ckan.sqlalchemyUrlTemplate" -}}
postgresql://{{ include "ckan.databaseUsername" . }}:__DB_PASSWORD__@{{ include "ckan.databaseHost" . }}:{{ include "ckan.databasePort" . }}/{{ include "ckan.databaseName" . }}
{{- end -}}

# =============================================================================
# Redis
# =============================================================================

{{- define "ckan.redisUrlTemplate" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.url -}}
{{- else -}}
redis://:__REDIS_PASSWORD__@{{ printf "%s-redis-client" .Release.Name }}:6379/0
{{- end -}}
{{- end -}}

{{- define "ckan.redisSecretName" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- "" -}}
{{- else -}}
{{- printf "%s-redis-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Solr
# =============================================================================

{{- define "ckan.solrUrl" -}}
{{- if .Values.solr.enabled -}}
http://{{ include "ckan.fullname" . }}-solr:{{ .Values.solr.port }}/solr/ckan
{{- else -}}
{{- .Values.solr.externalUrl -}}
{{- end -}}
{{- end -}}

# =============================================================================
# DataPusher
# =============================================================================

{{- define "ckan.datapusherUrl" -}}
{{- if .Values.datapusher.enabled -}}
http://{{ include "ckan.fullname" . }}-datapusher:{{ .Values.datapusher.port }}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Common env vars
# =============================================================================

{{- define "ckan.commonEnv" -}}
- name: CKAN_SITE_URL
  value: {{ .Values.ckan.siteUrl | quote }}
- name: CKAN_SITE_TITLE
  value: {{ .Values.ckan.siteTitle | quote }}
- name: CKAN_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.databaseSecretName" . }}
      key: {{ include "ckan.databaseSecretKey" . }}
- name: CKAN_SQLALCHEMY_URL_TEMPLATE
  value: {{ include "ckan.sqlalchemyUrlTemplate" . | quote }}
{{- if and (ne .Values.redisConfig.mode "external") .Values.redis.enabled }}
- name: CKAN_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.redisSecretName" . }}
      key: redis-password
{{- end }}
- name: CKAN_REDIS_URL_TEMPLATE
  value: {{ include "ckan.redisUrlTemplate" . | quote }}
- name: CKAN_SOLR_URL
  value: {{ include "ckan.solrUrl" . | quote }}
{{- if .Values.datapusher.enabled }}
- name: CKAN_DATAPUSHER_URL
  value: {{ include "ckan.datapusherUrl" . | quote }}
{{- end }}
- name: CKAN___BEAKER__SESSION__SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.secretName" . }}
      key: {{ .Values.ckan.existingSecretSessionKey | default "session-secret" }}
- name: CKAN___API_TOKEN__JWT__ENCODE__SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.secretName" . }}
      key: {{ .Values.ckan.existingSecretJwtKey | default "jwt-secret" }}
- name: CKAN___API_TOKEN__JWT__DECODE__SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.secretName" . }}
      key: {{ .Values.ckan.existingSecretJwtKey | default "jwt-secret" }}
- name: CKAN__PLUGINS
  value: {{ .Values.ckan.plugins | quote }}
{{- with .Values.ckan.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

# =============================================================================
# Startup command that injects passwords into URLs before exec
# =============================================================================

{{- define "ckan.startupCommand" -}}
export CKAN_SQLALCHEMY_URL=$(echo "$CKAN_SQLALCHEMY_URL_TEMPLATE" | sed "s|__DB_PASSWORD__|$CKAN_DB_PASSWORD|g")
export CKAN_REDIS_URL=$(echo "$CKAN_REDIS_URL_TEMPLATE" | sed "s|__REDIS_PASSWORD__|${CKAN_REDIS_PASSWORD:-}|g")
INI=${CKAN_INI:-/srv/app/ckan.ini}
ckan config-tool $INI "sqlalchemy.url = $CKAN_SQLALCHEMY_URL"
ckan config-tool $INI "ckan.redis.url = $CKAN_REDIS_URL"
ckan config-tool $INI "solr_url = $CKAN_SOLR_URL"
ckan config-tool $INI "ckan.plugins = $CKAN__PLUGINS"
{{- if .Values.datapusher.enabled }}
ckan config-tool $INI "ckan.datapusher.url = $CKAN_DATAPUSHER_URL"
{{- end }}
exec /srv/app/start_ckan.sh
{{- end -}}

# =============================================================================
# Init containers
# =============================================================================

{{- define "ckan.initContainers" -}}
- name: wait-for-postgresql
  image: docker.io/library/busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ include "ckan.databaseHost" . }}:{{ include "ckan.databasePort" . }} ..."
      until nc -z -w2 {{ include "ckan.databaseHost" . }} {{ include "ckan.databasePort" . }}; do
        sleep 2
      done
      echo "PostgreSQL is reachable."
{{- if .Values.solr.enabled }}
- name: wait-for-solr
  image: docker.io/library/busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ include "ckan.fullname" . }}-solr:{{ .Values.solr.port }} ..."
      until nc -z -w2 {{ include "ckan.fullname" . }}-solr {{ .Values.solr.port }}; do
        sleep 2
      done
      echo "Solr is reachable."
{{- end }}
{{- if and (ne .Values.redisConfig.mode "external") .Values.redis.enabled }}
- name: wait-for-redis
  image: docker.io/library/busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ printf "%s-redis-client" .Release.Name }}:6379 ..."
      until nc -z -w2 {{ printf "%s-redis-client" .Release.Name }} 6379; do
        sleep 2
      done
      echo "Redis is reachable."
{{- end }}
{{- end -}}

{{/* Backup — S3 secret name */}}
{{- define "ckan.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "ckan.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "ckan.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.accessKey) -}}
    {{- fail "backup.s3.accessKey or backup.s3.existingSecret is required when backup.enabled is true" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{/* Backup — database host */}}
{{- define "ckan.backupDbHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "ckan.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database port */}}
{{- define "ckan.backupDbPort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "ckan.databasePort" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database name */}}
{{- define "ckan.backupDbName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "ckan.databaseName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database username */}}
{{- define "ckan.backupDbUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "ckan.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret name */}}
{{- define "ckan.backupDbPasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "ckan.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret key */}}
{{- define "ckan.backupDbPasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "ckan.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}
