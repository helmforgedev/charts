{{- define "superset.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "superset.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "superset.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "superset.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "superset.labels" -}}
helm.sh/chart: {{ include "superset.chart" . }}
{{ include "superset.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "superset.selectorLabels" -}}
app.kubernetes.io/name: {{ include "superset.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "superset.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{- define "superset.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "superset.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Secret
# =============================================================================

{{- define "superset.secretName" -}}
{{- if .Values.superset.existingSecret -}}
{{- .Values.superset.existingSecret -}}
{{- else -}}
{{- include "superset.fullname" . -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Database
# =============================================================================

{{- define "superset.databaseHost" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "superset.databasePort" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.port | toString -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{- define "superset.databaseName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "superset.databaseUsername" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "superset.databaseSecretName" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq .Values.database.mode "external" -}}
{{- printf "%s-database" (include "superset.fullname" .) -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "superset.databaseSecretKey" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq .Values.database.mode "external" -}}
database-password
{{- else -}}
user-password
{{- end -}}
{{- end -}}

{{- define "superset.databasePasswordValue" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.password -}}
{{- else -}}
{{- .Values.postgresql.auth.password -}}
{{- end -}}
{{- end -}}

{{/*
SQLALCHEMY_DATABASE_URI built at runtime using $(DB_PASSWORD) interpolation.
The actual password is injected as DB_PASSWORD env var from the secret.
*/}}
{{- define "superset.sqlalchemyUri" -}}
postgresql+psycopg2://{{ include "superset.databaseUsername" . }}:$(DB_PASSWORD)@{{ include "superset.databaseHost" . }}:{{ include "superset.databasePort" . }}/{{ include "superset.databaseName" . }}
{{- end -}}

# =============================================================================
# Redis
# =============================================================================

{{- define "superset.redisHost" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.host -}}
{{- else -}}
{{- printf "%s-redis-client" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "superset.redisPort" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.port | toString -}}
{{- else -}}
6379
{{- end -}}
{{- end -}}

{{- define "superset.redisDb" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.db | toString -}}
{{- else -}}
0
{{- end -}}
{{- end -}}

{{/*
Redis URL for Celery broker: redis://:password@host:port/db
The password is injected at runtime via $(REDIS_PASSWORD) interpolation.
*/}}
{{- define "superset.redisUrl" -}}
redis://:$(REDIS_PASSWORD)@{{ include "superset.redisHost" . }}:{{ include "superset.redisPort" . }}/{{ include "superset.redisDb" . }}
{{- end -}}

{{- define "superset.redisSecretName" -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.existingSecret -}}
{{- .Values.redisConfig.external.existingSecret -}}
{{- else if eq .Values.redisConfig.mode "external" -}}
{{- printf "%s-redis-ext" (include "superset.fullname" .) -}}
{{- else -}}
{{- printf "%s-redis-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "superset.redisSecretKey" -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.existingSecret -}}
{{- .Values.redisConfig.external.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{- define "superset.redisPasswordValue" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.password -}}
{{- else -}}
{{- .Values.redis.auth.password -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Common env vars shared across web, worker, beat, and init
# =============================================================================

{{- define "superset.commonEnv" -}}
- name: SUPERSET_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "superset.secretName" . }}
      key: {{ .Values.superset.existingSecretSecretKeyKey | default "secret-key" }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "superset.databaseSecretName" . }}
      key: {{ include "superset.databaseSecretKey" . }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "superset.redisSecretName" . }}
      key: {{ include "superset.redisSecretKey" . }}
- name: SQLALCHEMY_DATABASE_URI
  value: {{ include "superset.sqlalchemyUri" . | quote }}
- name: REDIS_URL
  value: {{ include "superset.redisUrl" . | quote }}
- name: SUPERSET_LOAD_EXAMPLES
  value: {{ ternary "yes" "no" .Values.superset.loadExamples | quote }}
{{- with .Values.superset.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

# =============================================================================
# Init containers
# =============================================================================

{{- define "superset.initContainers" -}}
- name: wait-for-postgresql
  image: docker.io/library/busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ include "superset.databaseHost" . }}:{{ include "superset.databasePort" . }} ..."
      until nc -z -w2 {{ include "superset.databaseHost" . }} {{ include "superset.databasePort" . }}; do
        sleep 2
      done
      echo "PostgreSQL is reachable."
- name: wait-for-redis
  image: docker.io/library/busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ include "superset.redisHost" . }}:{{ include "superset.redisPort" . }} ..."
      until nc -z -w2 {{ include "superset.redisHost" . }} {{ include "superset.redisPort" . }}; do
        sleep 2
      done
      echo "Redis is reachable."
{{- end -}}

{{/* Backup — S3 secret name */}}
{{- define "superset.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "superset.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — validate required fields */}}
{{- define "superset.backupEnabled" -}}
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
{{- define "superset.backupDbHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "superset.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database port */}}
{{- define "superset.backupDbPort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "superset.databasePort" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database name */}}
{{- define "superset.backupDbName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "superset.databaseName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database username */}}
{{- define "superset.backupDbUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "superset.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret name */}}
{{- define "superset.backupDbPasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "superset.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{/* Backup — database password secret key */}}
{{- define "superset.backupDbPasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "superset.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}
