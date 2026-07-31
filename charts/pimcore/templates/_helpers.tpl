{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "pimcore.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "pimcore.fullname" -}}
{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- $name := default .Chart.Name .Values.nameOverride -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- end -}}
{{- define "pimcore.namespace" -}}{{- .Values.namespaceOverride | default .Release.Namespace -}}{{- end -}}
{{- define "pimcore.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "pimcore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pimcore.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
{{- define "pimcore.componentSelectorLabels" -}}
{{ include "pimcore.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
{{- define "pimcore.labels" -}}
helm.sh/chart: {{ include "pimcore.chart" . }}
{{ include "pimcore.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "pimcore.suffixedName" -}}{{- $max := int (max 1 (sub 63 (len .suffix))) -}}{{- printf "%s%s" (.base | trunc $max | trimSuffix "-") .suffix | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "pimcore.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "pimcore.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "pimcore.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- define "pimcore.runtimeImage" -}}{{ printf "%s:%s" .Values.project.runtimeImage.repository .Values.project.runtimeImage.tag }}{{- end -}}
{{- define "pimcore.waitImage" -}}{{ printf "%s:%s" .Values.waitForDependencies.image.repository .Values.waitForDependencies.image.tag }}{{- end -}}
{{- define "pimcore.nginxImage" -}}{{ printf "%s:%s" .Values.nginx.image.repository .Values.nginx.image.tag }}{{- end -}}
{{- define "pimcore.mercureImage" -}}{{ printf "%s:%s" .Values.mercure.image.repository .Values.mercure.image.tag }}{{- end -}}
{{- define "pimcore.secretName" -}}{{- default (include "pimcore.fullname" .) .Values.auth.existingSecret -}}{{- end -}}
{{- define "pimcore.projectClaim" -}}{{- default (include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .) "suffix" "-project")) .Values.project.persistence.existingClaim -}}{{- end -}}
{{- define "pimcore.assetsClaim" -}}{{- default (include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .) "suffix" "-assets")) .Values.assets.persistence.existingClaim -}}{{- end -}}

{{- define "pimcore.databaseHost" -}}{{- if eq .Values.database.mode "mariadb" -}}{{ printf "%s-mariadb" .Release.Name }}{{- else -}}{{ .Values.database.external.host }}{{- end -}}{{- end -}}
{{- define "pimcore.databasePort" -}}{{- if eq .Values.database.mode "mariadb" -}}3306{{- else -}}{{ .Values.database.external.port }}{{- end -}}{{- end -}}
{{- define "pimcore.databaseName" -}}{{- if eq .Values.database.mode "mariadb" -}}{{ .Values.mariadb.auth.database }}{{- else -}}{{ .Values.database.external.name }}{{- end -}}{{- end -}}
{{- define "pimcore.databaseUser" -}}{{- if eq .Values.database.mode "mariadb" -}}{{ .Values.mariadb.auth.username }}{{- else -}}{{ .Values.database.external.username }}{{- end -}}{{- end -}}
{{- define "pimcore.databaseSecretName" -}}{{- if eq .Values.database.mode "mariadb" -}}{{ printf "%s-mariadb-auth" .Release.Name }}{{- else if .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecret }}{{- else -}}{{ include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .) "suffix" "-database") }}{{- end -}}{{- end -}}
{{- define "pimcore.databaseSecretKey" -}}{{- if eq .Values.database.mode "mariadb" -}}mariadb-user-password{{- else if .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecretPasswordKey }}{{- else -}}password{{- end -}}{{- end -}}

{{- define "pimcore.queueHost" -}}{{- if eq .Values.queue.mode "rabbitmq" -}}{{ printf "%s-rabbitmq" .Release.Name }}{{- else -}}{{ .Values.queue.external.host }}{{- end -}}{{- end -}}
{{- define "pimcore.queuePort" -}}{{- if eq .Values.queue.mode "rabbitmq" -}}5672{{- else -}}{{ .Values.queue.external.port }}{{- end -}}{{- end -}}
{{- define "pimcore.queueUser" -}}{{- if eq .Values.queue.mode "rabbitmq" -}}{{ .Values.rabbitmq.auth.username }}{{- else -}}{{ .Values.queue.external.username }}{{- end -}}{{- end -}}
{{- define "pimcore.queueVhost" -}}{{- if eq .Values.queue.mode "rabbitmq" -}}{{ urlquery .Values.rabbitmq.auth.vhost }}{{- else -}}{{ .Values.queue.external.vhost }}{{- end -}}{{- end -}}
{{- define "pimcore.queueSecretName" -}}{{- if eq .Values.queue.mode "rabbitmq" -}}{{ printf "%s-rabbitmq-auth" .Release.Name }}{{- else if .Values.queue.external.existingSecret -}}{{ .Values.queue.external.existingSecret }}{{- else -}}{{ include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .) "suffix" "-queue") }}{{- end -}}{{- end -}}
{{- define "pimcore.queueSecretKey" -}}{{- if eq .Values.queue.mode "rabbitmq" -}}rabbitmq-password{{- else if .Values.queue.external.existingSecret -}}{{ .Values.queue.external.existingSecretPasswordKey }}{{- else -}}password{{- end -}}{{- end -}}

{{- define "pimcore.cacheHost" -}}{{- if eq .Values.cache.mode "redis" -}}{{ printf "%s-redis-client" .Release.Name }}{{- else -}}{{ .Values.cache.external.host }}{{- end -}}{{- end -}}
{{- define "pimcore.cachePort" -}}{{- if eq .Values.cache.mode "redis" -}}6379{{- else -}}{{ .Values.cache.external.port }}{{- end -}}{{- end -}}
{{- define "pimcore.cacheTLS" -}}{{- if eq .Values.cache.mode "redis" -}}false{{- else -}}{{ .Values.cache.external.tls }}{{- end -}}{{- end -}}
{{- define "pimcore.cacheSecretName" -}}{{- if eq .Values.cache.mode "redis" -}}{{ printf "%s-redis-auth" .Release.Name }}{{- else if .Values.cache.external.existingSecret -}}{{ .Values.cache.external.existingSecret }}{{- else -}}{{ include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .) "suffix" "-cache") }}{{- end -}}{{- end -}}
{{- define "pimcore.cacheSecretKey" -}}{{- if eq .Values.cache.mode "redis" -}}redis-password{{- else if .Values.cache.external.existingSecret -}}{{ .Values.cache.external.existingSecretPasswordKey }}{{- else -}}password{{- end -}}{{- end -}}

{{- define "pimcore.mercureURL" -}}{{- if .Values.pimcore.mercureURL -}}{{ .Values.pimcore.mercureURL }}{{- else -}}{{ printf "http://%s/hub" (include "pimcore.fullname" .) }}{{- end -}}{{- end -}}
{{- define "pimcore.mercureServerURL" -}}{{- if .Values.mercure.enabled -}}{{ printf "http://%s-mercure/.well-known/mercure" (include "pimcore.fullname" .) }}{{- else -}}{{ include "pimcore.mercureURL" . }}{{- end -}}{{- end -}}
{{- define "pimcore.httpRouteName" -}}
{{- if .route.name -}}
{{- .route.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $suffix := printf "-%d" .index -}}
{{- printf "%s%s" (.fullname | trunc (int (sub 63 (len $suffix))) | trimSuffix "-") $suffix -}}
{{- end -}}
{{- end -}}

{{- define "pimcore.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{- .item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .item.name -}}{{- include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .root) "suffix" (printf "-%s" .item.name)) -}}
{{- else -}}{{- include "pimcore.suffixedName" (dict "base" (include "pimcore.fullname" .root) "suffix" (printf "-external-%d" .index)) -}}{{- end -}}
{{- end -}}
{{- define "pimcore.stableSecretValue" -}}
{{- if .provided -}}{{- .provided -}}
{{- else -}}{{- $existing := lookup "v1" "Secret" (include "pimcore.namespace" .root) .name -}}
{{- if and $existing $existing.data (hasKey $existing.data .key) -}}{{- index $existing.data .key | b64dec -}}{{- else -}}{{- randAlphaNum (.length | default 48) -}}{{- end -}}{{- end -}}
{{- end -}}

{{- define "pimcore.registrationEnv" -}}
- name: APPLICATION_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.secretName" . }}
      key: {{ .Values.auth.applicationSecretKey }}
- name: PIMCORE_ADMIN_USER
  value: {{ .Values.auth.adminUser | quote }}
- name: PIMCORE_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.secretName" . }}
      key: {{ .Values.auth.adminPasswordKey }}
- name: PIMCORE_PRODUCT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.secretName" . }}
      key: {{ .Values.auth.productKeyKey }}
- name: PIMCORE_INSTANCE_IDENTIFIER
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.secretName" . }}
      key: {{ .Values.auth.instanceIdentifierKey }}
- name: PIMCORE_ENCRYPTION_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.secretName" . }}
      key: {{ .Values.auth.encryptionSecretKey }}
- name: MERCURE_JWT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.secretName" . }}
      key: {{ .Values.auth.mercureJWTKey }}
{{- end -}}

{{- define "pimcore.commonEnv" -}}
- name: APP_ENV
  value: {{ .Values.pimcore.environment | quote }}
- name: APP_DEBUG
  value: {{ .Values.pimcore.debug | quote }}
- name: PIMCORE_DEV_MODE
  value: "false"
- name: TRUSTED_PROXIES
  value: {{ .Values.pimcore.trustedProxies | quote }}
{{- with .Values.pimcore.trustedHosts }}
- name: TRUSTED_HOSTS
  value: {{ . | quote }}
{{- end }}
- name: DB_HOST
  value: {{ include "pimcore.databaseHost" . | quote }}
- name: DB_PORT
  value: {{ include "pimcore.databasePort" . | quote }}
- name: DB_NAME
  value: {{ include "pimcore.databaseName" . | quote }}
- name: DB_USER
  value: {{ include "pimcore.databaseUser" . | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.databaseSecretName" . }}
      key: {{ include "pimcore.databaseSecretKey" . }}
- name: RABBITMQ_HOST
  value: {{ include "pimcore.queueHost" . | quote }}
- name: RABBITMQ_PORT
  value: {{ include "pimcore.queuePort" . | quote }}
- name: RABBITMQ_USER
  value: {{ include "pimcore.queueUser" . | quote }}
- name: RABBITMQ_VHOST
  value: {{ include "pimcore.queueVhost" . | quote }}
- name: RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.queueSecretName" . }}
      key: {{ include "pimcore.queueSecretKey" . }}
- name: MERCURE_URL
  value: {{ include "pimcore.mercureURL" . | quote }}
- name: MERCURE_SERVER_URL
  value: {{ include "pimcore.mercureServerURL" . | quote }}
{{- with .Values.pimcore.opensearchDSN }}
- name: PIMCORE_OPENSEARCH_DSN
  value: {{ . | quote }}
{{- end }}
{{ include "pimcore.registrationEnv" . }}
{{- if .Values.cache.enabled }}
- name: REDIS_HOST
  value: {{ include "pimcore.cacheHost" . | quote }}
- name: REDIS_PORT
  value: {{ include "pimcore.cachePort" . | quote }}
- name: REDIS_TLS
  value: {{ include "pimcore.cacheTLS" . | quote }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "pimcore.cacheSecretName" . }}
      key: {{ include "pimcore.cacheSecretKey" . }}
{{- end }}
{{- with .Values.pimcore.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "pimcore.command" -}}
set -eu
export DATABASE_URL="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?serverVersion={{ .Values.database.serverVersion }}&charset=utf8mb4"
export PIMCORE_MESSENGER_TRANSPORT_DSN_PREFIX="amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}/"
exec "$@"
{{- end -}}

{{- define "pimcore.validate" -}}
{{- range $tag := list .Values.image.tag .Values.project.runtimeImage.tag .Values.waitForDependencies.image.tag .Values.nginx.image.tag .Values.mercure.image.tag -}}
{{- if has $tag (list "latest" "stable" "main" "master" "edge") -}}{{ fail "all image tags must be immutable release tags" }}{{- end -}}
{{- end -}}
{{- if not (has .Values.database.mode (list "mariadb" "external")) -}}{{ fail "database.mode must be mariadb or external" }}{{- end -}}
{{- if and (eq .Values.database.mode "mariadb") (not .Values.mariadb.enabled) -}}{{ fail "mariadb.enabled must be true when database.mode=mariadb" }}{{- end -}}
{{- if and (eq .Values.database.mode "external") (or (empty .Values.database.external.host) (and (empty .Values.database.external.existingSecret) (empty .Values.database.external.password))) -}}{{ fail "external database requires host and password or existingSecret" }}{{- end -}}
{{- if not (has .Values.queue.mode (list "rabbitmq" "external")) -}}{{ fail "queue.mode must be rabbitmq or external" }}{{- end -}}
{{- if and (eq .Values.queue.mode "rabbitmq") (not .Values.rabbitmq.enabled) -}}{{ fail "rabbitmq.enabled must be true when queue.mode=rabbitmq" }}{{- end -}}
{{- if and (eq .Values.queue.mode "external") (or (empty .Values.queue.external.host) (and (empty .Values.queue.external.existingSecret) (empty .Values.queue.external.password))) -}}{{ fail "external queue requires host and password or existingSecret" }}{{- end -}}
{{- if and .Values.cache.enabled (eq .Values.cache.mode "redis") (not .Values.redis.enabled) -}}{{ fail "redis.enabled must be true when cache.enabled=true and cache.mode=redis" }}{{- end -}}
{{- if and .Values.cache.enabled (eq .Values.cache.mode "external") (or (empty .Values.cache.external.host) (and (empty .Values.cache.external.existingSecret) (empty .Values.cache.external.password))) -}}{{ fail "external cache requires host and password or existingSecret" }}{{- end -}}
{{- if and .Values.install.enabled (empty .Values.auth.existingSecret) (or (empty .Values.auth.productKey) (empty .Values.auth.instanceIdentifier) (empty .Values.auth.encryptionSecret)) -}}{{ fail "install.enabled requires auth.existingSecret or productKey, instanceIdentifier, and encryptionSecret" }}{{- end -}}
{{- if ne (int .Values.mercure.replicaCount) 1 -}}{{ fail "mercure.replicaCount must remain 1 unless a clustered Mercure transport is implemented" }}{{- end -}}
{{- if and (not .Values.mercure.enabled) (empty .Values.pimcore.mercureURL) -}}{{ fail "pimcore.mercureURL is required when bundled Mercure is disabled" }}{{- end -}}
{{- if and .Values.project.bootstrap.enabled (not .Values.project.persistence.enabled) -}}{{ fail "project.bootstrap.enabled requires project.persistence.enabled" }}{{- end -}}
{{- if and .Values.project.persistence.enabled (empty .Values.project.persistence.existingClaim) (gt (int .Values.web.replicaCount) 1) (not (has "ReadWriteMany" .Values.project.persistence.accessModes)) -}}{{ fail "web.replicaCount > 1 requires project persistence with ReadWriteMany or an immutable project image" }}{{- end -}}
{{- if and .Values.assets.persistence.enabled (empty .Values.assets.persistence.existingClaim) (gt (int .Values.web.replicaCount) 1) (not (has "ReadWriteMany" .Values.assets.persistence.accessModes)) -}}{{ fail "web.replicaCount > 1 requires assets.persistence.accessModes to include ReadWriteMany" }}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{ fail "ingress.hosts must not be empty when ingress.enabled=true" }}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}{{ fail "gatewayAPI.httpRoutes must not be empty when enabled" }}{{- end -}}
{{- range $i, $route := .Values.gatewayAPI.httpRoutes }}{{- if and $.Values.gatewayAPI.enabled (empty $route.parentRefs) -}}{{ fail (printf "gatewayAPI.httpRoutes[%d].parentRefs must not be empty" $i) }}{{- end -}}{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must not be empty when enabled" }}{{- end -}}
{{- range $i, $item := .Values.externalSecrets.items }}
{{- if and $.Values.externalSecrets.enabled (empty $item.spec.secretStoreRef) (empty $item.spec.sourceRef) -}}{{ fail (printf "externalSecrets.items[%d].spec requires secretStoreRef or sourceRef" $i) }}{{- end -}}
{{- if and $.Values.externalSecrets.enabled (empty $item.spec.data) (empty $item.spec.dataFrom) -}}{{ fail (printf "externalSecrets.items[%d].spec requires data or dataFrom" $i) }}{{- end -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{ fail "podLabels must not override app.kubernetes.io/name" }}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{ fail "podLabels must not override app.kubernetes.io/instance" }}{{- end -}}
{{- end -}}
