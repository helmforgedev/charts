{{/* SPDX-License-Identifier: Apache-2.0 */}}
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
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "ckan.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ckan.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ckan.validate" -}}
{{- if has .Values.image.tag (list "latest" "stable" "main" "master" "edge") -}}
{{- fail "image.tag must be pinned and must not use a floating tag" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "subchart") (not .Values.postgresql.enabled) -}}
{{- fail "postgresql.enabled must be true when database.mode is subchart" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") .Values.postgresql.enabled -}}
{{- fail "postgresql.enabled must be false when database.mode is external" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") (not .Values.database.external.host) -}}
{{- fail "database.external.host is required when database.mode is external" -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
{{- fail "database.external.password or database.external.existingSecret is required when database.mode is external" -}}
{{- end -}}
{{- $plugins := splitList " " .Values.ckan.plugins -}}
{{- if and (has "datastore" $plugins) (ne .Values.database.mode "external") -}}
{{- fail "the datastore plugin requires database.mode=external and pre-provisioned DataStore roles" -}}
{{- end -}}
{{- if and (has "datastore" $plugins) (not .Values.database.external.existingSecret) (not .Values.database.external.datastoreReadPassword) -}}
{{- fail "database.external.datastoreReadPassword or database.external.existingSecret is required when the datastore plugin is enabled" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "external") (not .Values.redisConfig.external.host) -}}
{{- fail "redisConfig.external.host is required when redisConfig.mode is external" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "external") (not .Values.redisConfig.external.existingSecret) (not .Values.redisConfig.external.password) -}}
{{- fail "redisConfig.external.password or redisConfig.external.existingSecret is required when redisConfig.mode is external" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "subchart") (not .Values.redis.enabled) -}}
{{- fail "redis.enabled must be true when redisConfig.mode is subchart" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redis.enabled -}}
{{- fail "redis.enabled must be false when redisConfig.mode is external" -}}
{{- end -}}
{{- if and (eq .Values.redisConfig.mode "subchart") (not .Values.redis.auth.enabled) -}}
{{- fail "redis.auth.enabled must be true when redisConfig.mode is subchart" -}}
{{- end -}}
{{- if and (not .Values.solr.enabled) (not .Values.solr.externalUrl) -}}
{{- fail "solr.externalUrl is required when solr.enabled is false" -}}
{{- end -}}

{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.enabled requires ingress.hosts to contain at least one rule" -}}
{{- end -}}
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
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") (eq $key "app.kubernetes.io/component") -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- if .Values.datapusher.enabled -}}
{{- range $key, $_ := .Values.datapusher.podLabels -}}
{{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") (eq $key "app.kubernetes.io/component") -}}
{{- fail (printf "datapusher.podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL subchart fullname, matching the dependency naming contract. */}}
{{- define "ckan.postgresqlFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Redis subchart fullname, matching the dependency naming contract. */}}
{{- define "ckan.redisFullname" -}}
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
{{- else if eq .Values.postgresql.architecture "replication" -}}
{{- printf "%s-primary" (include "ckan.postgresqlFullname" . | trunc 55 | trimSuffix "-") -}}
{{- else -}}
{{- include "ckan.postgresqlFullname" . -}}
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
{{- default (printf "%s-auth" (include "ckan.postgresqlFullname" .)) .Values.postgresql.auth.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "ckan.databaseSecretKey" -}}
{{- if and (eq .Values.database.mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq .Values.database.mode "external" -}}
database-password
{{- else -}}
{{- .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" -}}
{{- end -}}
{{- end -}}

{{- define "ckan.databaseSslMode" -}}
{{- if eq .Values.database.mode "external" -}}
{{- .Values.database.external.sslMode -}}
{{- else -}}
disable
{{- end -}}
{{- end -}}

{{- define "ckan.datastoreReadSecretKey" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretDatastoreReadPasswordKey -}}
{{- else -}}
datastore-read-password
{{- end -}}
{{- end -}}

# =============================================================================
# Redis
# =============================================================================

{{- define "ckan.redisHost" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.host -}}
{{- else if eq .Values.redis.architecture "replication" -}}
{{- printf "%s-primary" (include "ckan.redisFullname" .) -}}
{{- else -}}
{{- printf "%s-client" (include "ckan.redisFullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "ckan.redisPort" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.port | toString -}}
{{- else -}}
6379
{{- end -}}
{{- end -}}

{{- define "ckan.redisDatabase" -}}
{{- if eq .Values.redisConfig.mode "external" -}}
{{- .Values.redisConfig.external.database | toString -}}
{{- else -}}
0
{{- end -}}
{{- end -}}

{{- define "ckan.redisSecretName" -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.existingSecret -}}
{{- .Values.redisConfig.external.existingSecret -}}
{{- else if eq .Values.redisConfig.mode "external" -}}
{{- printf "%s-redis" (include "ckan.fullname" .) -}}
{{- else -}}
{{- default (printf "%s-auth" (include "ckan.redisFullname" .)) .Values.redis.auth.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "ckan.redisSecretKey" -}}
{{- if and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.existingSecret -}}
{{- .Values.redisConfig.external.existingSecretPasswordKey -}}
{{- else if eq .Values.redisConfig.mode "external" -}}
redis-password
{{- else -}}
{{- .Values.redis.auth.existingSecretPasswordKey | default "redis-password" -}}
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
- name: UWSGI_OPTS
  value: {{ printf "--socket /tmp/uwsgi.sock --wsgi-file /srv/app/wsgi.py --module wsgi:application --http [::]:%v --master --enable-threads --lazy-apps -p %v -L -b 32768 --vacuum --harakiri %v" .Values.ckan.containerPort .Values.ckan.uwsgiProcesses .Values.ckan.uwsgiHarakiri | quote }}
- name: HELMFORGE_CKAN_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.databaseSecretName" . }}
      key: {{ include "ckan.databaseSecretKey" . }}
- name: HELMFORGE_CKAN_DB_HOST
  value: {{ include "ckan.databaseHost" . | quote }}
- name: HELMFORGE_CKAN_DB_PORT
  value: {{ include "ckan.databasePort" . | quote }}
- name: HELMFORGE_CKAN_DB_NAME
  value: {{ include "ckan.databaseName" . | quote }}
- name: HELMFORGE_CKAN_DB_USERNAME
  value: {{ include "ckan.databaseUsername" . | quote }}
- name: HELMFORGE_CKAN_DB_SSLMODE
  value: {{ include "ckan.databaseSslMode" . | quote }}
{{- if has "datastore" (splitList " " .Values.ckan.plugins) }}
- name: HELMFORGE_CKAN_DATASTORE_DB_NAME
  value: {{ .Values.database.external.datastoreDatabase | quote }}
- name: HELMFORGE_CKAN_DATASTORE_READ_USERNAME
  value: {{ .Values.database.external.datastoreReadUsername | quote }}
- name: HELMFORGE_CKAN_DATASTORE_READ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.databaseSecretName" . }}
      key: {{ include "ckan.datastoreReadSecretKey" . }}
{{- end }}
- name: HELMFORGE_CKAN_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ckan.redisSecretName" . }}
      key: {{ include "ckan.redisSecretKey" . }}
- name: HELMFORGE_CKAN_REDIS_HOST
  value: {{ include "ckan.redisHost" . | quote }}
- name: HELMFORGE_CKAN_REDIS_PORT
  value: {{ include "ckan.redisPort" . | quote }}
- name: HELMFORGE_CKAN_REDIS_DATABASE
  value: {{ include "ckan.redisDatabase" . | quote }}
- name: HELMFORGE_CKAN_REDIS_TLS
  value: {{ ternary "true" "false" (and (eq .Values.redisConfig.mode "external") .Values.redisConfig.external.tls) | quote }}
- name: HELMFORGE_CKAN_REDIS_SSL_CERT_REQS
  value: {{ .Values.redisConfig.external.sslCertReqs | quote }}
- name: HELMFORGE_CKAN_REDIS_SSL_CA_CERTS
  value: {{ .Values.redisConfig.external.sslCaCerts | quote }}
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
INI=${CKAN_INI:-/srv/app/ckan.ini}
ckan config-tool "$INI" "solr_url = $CKAN_SOLR_URL"
ckan config-tool "$INI" "ckan.plugins = $CKAN__PLUGINS"
{{- if .Values.datapusher.enabled }}
ckan config-tool "$INI" "ckan.datapusher.url = $CKAN_DATAPUSHER_URL"
{{- end }}
export PGPASSFILE=/tmp/helmforge-pgpass
python3 -c 'import os; from pathlib import Path; esc = lambda value: value.replace("\\", "\\\\").replace(":", "\\:"); main = (os.environ["HELMFORGE_CKAN_DB_HOST"], os.environ["HELMFORGE_CKAN_DB_PORT"], os.environ["HELMFORGE_CKAN_DB_NAME"], os.environ["HELMFORGE_CKAN_DB_USERNAME"], os.environ["HELMFORGE_CKAN_DB_PASSWORD"]); datastore = [(os.environ["HELMFORGE_CKAN_DB_HOST"], os.environ["HELMFORGE_CKAN_DB_PORT"], os.environ["HELMFORGE_CKAN_DATASTORE_DB_NAME"], os.environ["HELMFORGE_CKAN_DB_USERNAME"], os.environ["HELMFORGE_CKAN_DB_PASSWORD"]), (os.environ["HELMFORGE_CKAN_DB_HOST"], os.environ["HELMFORGE_CKAN_DB_PORT"], os.environ["HELMFORGE_CKAN_DATASTORE_DB_NAME"], os.environ["HELMFORGE_CKAN_DATASTORE_READ_USERNAME"], os.environ["HELMFORGE_CKAN_DATASTORE_READ_PASSWORD"])] if os.environ.get("HELMFORGE_CKAN_DATASTORE_DB_NAME") else []; path = Path(os.environ["PGPASSFILE"]); path.write_text("".join(":".join(esc(value) for value in row) + "\n" for row in [main, *datastore]), encoding="utf-8"); os.chmod(path, 0o600)'
HELMFORGE_CKAN_SQLALCHEMY_URL="$(python3 -c 'import os; from urllib.parse import quote; print("postgresql://{}@{}:{}/{}?sslmode={}".format(quote(os.environ["HELMFORGE_CKAN_DB_USERNAME"], safe=""), os.environ["HELMFORGE_CKAN_DB_HOST"], os.environ["HELMFORGE_CKAN_DB_PORT"], quote(os.environ["HELMFORGE_CKAN_DB_NAME"], safe=""), quote(os.environ["HELMFORGE_CKAN_DB_SSLMODE"], safe="")))')"
HELMFORGE_CKAN_REDIS_URL="$(python3 -c 'import os; from urllib.parse import quote, urlencode; scheme = "rediss" if os.environ["HELMFORGE_CKAN_REDIS_TLS"] == "true" else "redis"; params = {"ssl_cert_reqs": os.environ["HELMFORGE_CKAN_REDIS_SSL_CERT_REQS"]}; ca = os.environ["HELMFORGE_CKAN_REDIS_SSL_CA_CERTS"]; params.update({"ssl_ca_certs": ca}) if ca else None; query = "?" + urlencode(params) if scheme == "rediss" else ""; uri = "{}://:{}@{}:{}/{}{}".format(scheme, quote(os.environ["HELMFORGE_CKAN_REDIS_PASSWORD"], safe=""), os.environ["HELMFORGE_CKAN_REDIS_HOST"], os.environ["HELMFORGE_CKAN_REDIS_PORT"], os.environ["HELMFORGE_CKAN_REDIS_DATABASE"], query); print(uri.replace("%", "%%"))')"
ckan config-tool "$INI" "sqlalchemy.url = $HELMFORGE_CKAN_SQLALCHEMY_URL"
ckan config-tool "$INI" "ckan.redis.url = $HELMFORGE_CKAN_REDIS_URL"
{{- if has "datastore" (splitList " " .Values.ckan.plugins) }}
export CKAN_DATASTORE_WRITE_URL="$(python3 -c 'import os; from urllib.parse import quote; print("postgresql://{}@{}:{}/{}?sslmode={}".format(quote(os.environ["HELMFORGE_CKAN_DB_USERNAME"], safe=""), os.environ["HELMFORGE_CKAN_DB_HOST"], os.environ["HELMFORGE_CKAN_DB_PORT"], quote(os.environ["HELMFORGE_CKAN_DATASTORE_DB_NAME"], safe=""), quote(os.environ["HELMFORGE_CKAN_DB_SSLMODE"], safe="")))')"
export CKAN_DATASTORE_READ_URL="$(python3 -c 'import os; from urllib.parse import quote; print("postgresql://{}@{}:{}/{}?sslmode={}".format(quote(os.environ["HELMFORGE_CKAN_DATASTORE_READ_USERNAME"], safe=""), os.environ["HELMFORGE_CKAN_DB_HOST"], os.environ["HELMFORGE_CKAN_DB_PORT"], quote(os.environ["HELMFORGE_CKAN_DATASTORE_DB_NAME"], safe=""), quote(os.environ["HELMFORGE_CKAN_DB_SSLMODE"], safe="")))')"
{{- end }}
exec /srv/app/start_ckan.sh
{{- end -}}

# =============================================================================
# Init containers
# =============================================================================

{{- define "ckan.initContainers" -}}
- name: wait-for-postgresql
  image: docker.io/library/postgres:18.6-trixie
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
  env:
    - name: WAIT_DB_HOST
      value: {{ include "ckan.databaseHost" . | quote }}
    - name: WAIT_DB_PORT
      value: {{ include "ckan.databasePort" . | quote }}
    - name: WAIT_DB_USERNAME
      value: {{ include "ckan.databaseUsername" . | quote }}
    - name: WAIT_DB_NAME
      value: {{ include "ckan.databaseName" . | quote }}
  command:
    - sh
    - -c
    - |
      echo "Waiting for ${WAIT_DB_HOST}:${WAIT_DB_PORT} ..."
      ready_checks=0
      while [ "$ready_checks" -lt 5 ]; do
        if pg_isready \
          --host="${WAIT_DB_HOST}" \
          --port="${WAIT_DB_PORT}" \
          --username="${WAIT_DB_USERNAME}" \
          --dbname="${WAIT_DB_NAME}"; then
          ready_checks=$((ready_checks + 1))
        else
          ready_checks=0
        fi
        sleep 2
      done
      echo "PostgreSQL is accepting connections."
{{- if .Values.solr.enabled }}
- name: wait-for-solr
  image: docker.io/library/busybox:1.37.0
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
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
{{- if or (eq .Values.redisConfig.mode "external") .Values.redis.enabled }}
- name: wait-for-redis
  image: docker.io/library/busybox:1.37.0
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
  env:
    - name: WAIT_REDIS_HOST
      value: {{ include "ckan.redisHost" . | quote }}
    - name: WAIT_REDIS_PORT
      value: {{ include "ckan.redisPort" . | quote }}
  command:
    - sh
    - -c
    - |
      echo "Waiting for ${WAIT_REDIS_HOST}:${WAIT_REDIS_PORT} ..."
      until nc -z -w2 "${WAIT_REDIS_HOST}" "${WAIT_REDIS_PORT}"; do
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

{{- define "ckan.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
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
