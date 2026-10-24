{{/* SPDX-License-Identifier: Apache-2.0 */}}
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
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Fail fast on contradictory or unsafe values. */}}
{{- define "superset.validate" -}}
{{- if has .Values.image.tag (list "latest" "stable" "main" "master" "edge") -}}
{{- fail "image.tag must be an immutable release tag" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "subchart") (not .Values.postgresql.enabled) -}}
{{- fail "postgresql.enabled must be true when database.mode=subchart" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") .Values.postgresql.enabled -}}
{{- fail "postgresql.enabled must be false when database.mode=external" -}}
{{- end -}}
{{- if eq .Values.database.mode "external" -}}
  {{- if not .Values.database.external.host -}}
  {{- fail "database.external.host is required when database.mode=external" -}}
  {{- end -}}
  {{- if and (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
  {{- fail "database.external.password or database.external.existingSecret is required when database.mode=external" -}}
  {{- end -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "subchart") (not .Values.redis.enabled) -}}
{{- fail "redis.enabled must be true when redisConfig.mode=subchart" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redis.enabled -}}
{{- fail "redis.enabled must be false when redisConfig.mode=external" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "subchart") (not .Values.redis.auth.enabled) -}}
{{- fail "redis.auth.enabled must be true when redisConfig.mode=subchart" -}}
{{- end -}}
{{- if eq .Values.redisConfig.mode "external" -}}
  {{- if not .Values.redisConfig.external.host -}}
  {{- fail "redisConfig.external.host is required when redisConfig.mode=external" -}}
  {{- end -}}
  {{- if and (not .Values.redisConfig.external.existingSecret) (not .Values.redisConfig.external.password) -}}
  {{- fail "redisConfig.external.password or redisConfig.external.existingSecret is required when redisConfig.mode=external" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- range .Values.extraVolumes -}}
  {{- if has .name (list "superset-config" "runtime-tmp" "superset-home") -}}
  {{- fail (printf "extraVolumes name %q is reserved by the chart" .name) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* Python dependencies shared by web, worker, beat, and init. Values schema
restricts additional entries to shell-safe package names and version specifiers. */}}
{{- define "superset.pythonPackages" -}}
psycopg2-binary redis{{ range .Values.superset.extraPythonPackages }} {{ . }}{{ end }}
{{- end -}}

{{- define "superset.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "superset.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL subchart fullname, matching the dependency's naming contract. */}}
{{- define "superset.postgresqlFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Redis subchart fullname, matching the dependency's naming contract. */}}
{{- define "superset.redisFullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
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
{{- else if eq .Values.postgresql.architecture "replication" -}}
{{- printf "%s-primary" (include "superset.postgresqlFullname" .) -}}
{{- else -}}
{{- include "superset.postgresqlFullname" . -}}
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
{{- default (printf "%s-auth" (include "superset.postgresqlFullname" .)) .Values.postgresql.auth.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "superset.databaseSecretKey" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq .Values.database.mode "external" -}}
database-password
{{- else -}}
{{- .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" -}}
{{- end -}}
{{- end -}}

{{- define "superset.databasePasswordValue" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.password -}}
{{- else -}}
{{- .Values.postgresql.auth.password -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Redis
# =============================================================================

{{- define "superset.redisHost" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.host -}}
{{- else if eq .Values.redis.architecture "replication" -}}
{{- printf "%s-primary" (include "superset.redisFullname" .) -}}
{{- else -}}
{{- printf "%s-client" (include "superset.redisFullname" .) -}}
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

{{- define "superset.redisSecretName" -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.existingSecret -}}
{{- .Values.redisConfig.external.existingSecret -}}
{{- else if eq .Values.redisConfig.mode "external" -}}
{{- printf "%s-redis-ext" (include "superset.fullname" .) -}}
{{- else -}}
{{- default (printf "%s-auth" (include "superset.redisFullname" .)) .Values.redis.auth.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "superset.redisSecretKey" -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.existingSecret -}}
{{- .Values.redisConfig.external.existingSecretPasswordKey -}}
{{- else if eq .Values.redisConfig.mode "subchart" -}}
{{- .Values.redis.auth.existingSecretPasswordKey | default "redis-password" -}}
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
- name: DB_HOST
  value: {{ include "superset.databaseHost" . | quote }}
- name: DB_PORT
  value: {{ include "superset.databasePort" . | quote }}
- name: DB_NAME
  value: {{ include "superset.databaseName" . | quote }}
- name: DB_USERNAME
  value: {{ include "superset.databaseUsername" . | quote }}
- name: DB_SSLMODE
  value: {{ ternary .Values.database.external.sslMode "disable" (eq .Values.database.mode "external") | quote }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "superset.redisSecretName" . }}
      key: {{ include "superset.redisSecretKey" . }}
- name: REDIS_HOST
  value: {{ include "superset.redisHost" . | quote }}
- name: REDIS_PORT
  value: {{ include "superset.redisPort" . | quote }}
- name: REDIS_DB
  value: {{ include "superset.redisDb" . | quote }}
- name: REDIS_TLS
  value: {{ ternary "true" "false" (and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.tls) | quote }}
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
  image: docker.io/library/busybox:1.37.0
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 65532
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
  image: docker.io/library/busybox:1.37.0
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 65532
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

{{/*
wait-for-init initContainer: blocks the web/worker/beat pods until the init Job
(db upgrade + superset init) has completed, so they never race each other on
Flask-AppBuilder schema creation (which deadlocks in Postgres). Used ONLY by the
workload pods — never by the init Job itself.
*/}}
{{- define "superset.waitForInit" -}}
{{- if .Values.init.enabled -}}
- name: wait-for-init
  image: {{ .Values.init.waitImage | quote }}
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 65532
  command:
    - sh
    - -c
    - |
      job="{{ include "superset.fullname" . }}-init-{{ .Release.Revision }}"
      echo "Waiting for init job ${job} to be created..."
      until kubectl get job "${job}" >/dev/null 2>&1; do sleep 3; done
      echo "Waiting for init job ${job} to complete..."
      kubectl wait --for=condition=complete --timeout=600s job/"${job}"
      echo "Init job complete."
  {{- with .Values.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/* Ephemeral writable paths required with a read-only root filesystem. */}}
{{- define "superset.runtimeVolumeMounts" -}}
- name: runtime-tmp
  mountPath: /tmp
- name: superset-home
  mountPath: /app/superset_home
{{- end -}}

{{- define "superset.runtimeVolumes" -}}
- name: runtime-tmp
  emptyDir: {}
- name: superset-home
  emptyDir: {}
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
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.secretKey) -}}
    {{- fail "backup.s3.secretKey or backup.s3.existingSecret is required when backup.enabled is true" -}}
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
