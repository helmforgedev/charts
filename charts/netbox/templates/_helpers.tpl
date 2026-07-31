{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "netbox.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "netbox.fullname" -}}
{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- $name := default .Chart.Name .Values.nameOverride -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- end -}}
{{- define "netbox.namespace" -}}{{- .Values.namespaceOverride | default .Release.Namespace -}}{{- end -}}
{{- define "netbox.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "netbox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbox.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
{{- define "netbox.componentSelectorLabels" -}}
{{ include "netbox.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
{{- define "netbox.labels" -}}
helm.sh/chart: {{ include "netbox.chart" . }}
{{ include "netbox.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "netbox.suffixedName" -}}{{- $max := int (max 1 (sub 63 (len .suffix))) -}}{{- printf "%s%s" (.base | trunc $max | trimSuffix "-") .suffix | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "netbox.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "netbox.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "netbox.secretName" -}}{{- default (include "netbox.fullname" .) .Values.auth.existingSecret -}}{{- end -}}
{{- define "netbox.superuserSecretName" -}}{{- default (include "netbox.suffixedName" (dict "base" (include "netbox.fullname" .) "suffix" "-superuser")) .Values.auth.superuser.existingSecret -}}{{- end -}}
{{- define "netbox.databaseMode" -}}{{- $m := .Values.database.mode -}}{{- if eq $m "auto" -}}{{- if .Values.postgresql.enabled -}}postgresql{{- else -}}external{{- end -}}{{- else -}}{{- $m -}}{{- end -}}{{- end -}}
{{- define "netbox.databaseHost" -}}{{- if eq (include "netbox.databaseMode" .) "postgresql" -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ .Values.database.external.host }}{{- end -}}{{- end -}}
{{- define "netbox.databasePort" -}}{{- if eq (include "netbox.databaseMode" .) "postgresql" -}}5432{{- else -}}{{ .Values.database.external.port }}{{- end -}}{{- end -}}
{{- define "netbox.databaseName" -}}{{- if eq (include "netbox.databaseMode" .) "postgresql" -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.database.external.name }}{{- end -}}{{- end -}}
{{- define "netbox.databaseUser" -}}{{- if eq (include "netbox.databaseMode" .) "postgresql" -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.database.external.username }}{{- end -}}{{- end -}}
{{- define "netbox.databaseSecretName" -}}{{- if eq (include "netbox.databaseMode" .) "postgresql" -}}{{ printf "%s-postgresql-auth" .Release.Name }}{{- else if .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecret }}{{- else -}}{{ include "netbox.suffixedName" (dict "base" (include "netbox.fullname" .) "suffix" "-database") }}{{- end -}}{{- end -}}
{{- define "netbox.databaseSecretKey" -}}{{- if eq (include "netbox.databaseMode" .) "postgresql" -}}user-password{{- else if .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecretPasswordKey }}{{- else -}}password{{- end -}}{{- end -}}
{{- define "netbox.cacheMode" -}}{{- $m := .Values.cache.mode -}}{{- if eq $m "auto" -}}{{- if .Values.redis.enabled -}}redis{{- else -}}external{{- end -}}{{- else -}}{{- $m -}}{{- end -}}{{- end -}}
{{- define "netbox.cacheHost" -}}{{- if eq (include "netbox.cacheMode" .) "redis" -}}{{ printf "%s-redis-client" .Release.Name }}{{- else -}}{{ .Values.cache.external.host }}{{- end -}}{{- end -}}
{{- define "netbox.cachePort" -}}{{- if eq (include "netbox.cacheMode" .) "redis" -}}6379{{- else -}}{{ .Values.cache.external.port }}{{- end -}}{{- end -}}
{{- define "netbox.cacheSecretName" -}}{{- if eq (include "netbox.cacheMode" .) "redis" -}}{{ printf "%s-redis-auth" .Release.Name }}{{- else if .Values.cache.external.existingSecret -}}{{ .Values.cache.external.existingSecret }}{{- else -}}{{ include "netbox.suffixedName" (dict "base" (include "netbox.fullname" .) "suffix" "-cache") }}{{- end -}}{{- end -}}
{{- define "netbox.cacheSecretKey" -}}{{- if eq (include "netbox.cacheMode" .) "redis" -}}redis-password{{- else if .Values.cache.external.existingSecret -}}{{ .Values.cache.external.existingSecretPasswordKey }}{{- else -}}password{{- end -}}{{- end -}}
{{- define "netbox.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- define "netbox.mediaClaim" -}}{{ default (include "netbox.suffixedName" (dict "base" (include "netbox.fullname" .) "suffix" "-media")) .Values.persistence.existingClaim }}{{- end -}}
{{- define "netbox.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{- .item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .item.name -}}{{- include "netbox.suffixedName" (dict "base" (include "netbox.fullname" .root) "suffix" (printf "-%s" .item.name)) -}}
{{- else -}}{{- include "netbox.suffixedName" (dict "base" (include "netbox.fullname" .root) "suffix" (printf "-external-%d" .index)) -}}{{- end -}}
{{- end -}}
{{- define "netbox.stableSecretValue" -}}
{{- if .provided -}}{{- .provided -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" (include "netbox.namespace" .root) .name -}}
{{- if and $existing $existing.data (hasKey $existing.data .key) -}}{{- index $existing.data .key | b64dec -}}
{{- else -}}{{- randAlphaNum (.length | default 64) -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- define "netbox.commonEnv" -}}
- name: ALLOWED_HOSTS
  value: {{ join " " .Values.netbox.allowedHosts | quote }}
- name: DB_HOST
  value: {{ include "netbox.databaseHost" . | quote }}
- name: DB_PORT
  value: {{ include "netbox.databasePort" . | quote }}
- name: DB_NAME
  value: {{ include "netbox.databaseName" . | quote }}
- name: DB_USER
  value: {{ include "netbox.databaseUser" . | quote }}
- name: DB_SSLMODE
  value: {{ .Values.database.external.sslMode | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "netbox.databaseSecretName" . }}
      key: {{ include "netbox.databaseSecretKey" . }}
- name: REDIS_HOST
  value: {{ include "netbox.cacheHost" . | quote }}
- name: REDIS_PORT
  value: {{ include "netbox.cachePort" . | quote }}
- name: REDIS_DATABASE
  value: {{ .Values.cache.tasksDatabase | quote }}
- name: REDIS_CACHE_HOST
  value: {{ include "netbox.cacheHost" . | quote }}
- name: REDIS_CACHE_PORT
  value: {{ include "netbox.cachePort" . | quote }}
- name: REDIS_CACHE_DATABASE
  value: {{ .Values.cache.cacheDatabase | quote }}
- name: REDIS_SSL
  value: {{ .Values.cache.external.ssl | quote }}
- name: REDIS_CACHE_SSL
  value: {{ .Values.cache.external.ssl | quote }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "netbox.cacheSecretName" . }}
      key: {{ include "netbox.cacheSecretKey" . }}
- name: REDIS_CACHE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "netbox.cacheSecretName" . }}
      key: {{ include "netbox.cacheSecretKey" . }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "netbox.secretName" . }}
      key: {{ .Values.auth.secretKeyKey }}
- name: API_TOKEN_PEPPER_1
  valueFrom:
    secretKeyRef:
      name: {{ include "netbox.secretName" . }}
      key: {{ .Values.auth.apiTokenPepperKey }}
- name: TIME_ZONE
  value: {{ .Values.netbox.timeZone | quote }}
- name: ISOLATED_DEPLOYMENT
  value: {{ .Values.netbox.isolatedDeployment | quote }}
- name: METRICS_ENABLED
  value: {{ .Values.netbox.metricsEnabled | quote }}
- name: COPILOT_ENABLED
  value: {{ .Values.netbox.copilotEnabled | quote }}
{{- with .Values.netbox.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "netbox.validate" -}}
{{- if has .Values.image.tag (list "latest" "stable" "main" "master" "edge") -}}{{ fail "image.tag must be an immutable release tag" }}{{- end -}}
{{- if not (has .Values.database.mode (list "auto" "postgresql" "external")) -}}{{ fail "database.mode must be auto, postgresql, or external" }}{{- end -}}
{{- if not (has .Values.cache.mode (list "auto" "redis" "external")) -}}{{ fail "cache.mode must be auto, redis, or external" }}{{- end -}}
{{- if and (eq (include "netbox.databaseMode" .) "external") (empty .Values.database.external.host) -}}{{ fail "external database mode requires database.external.host" }}{{- end -}}
{{- if and (eq (include "netbox.databaseMode" .) "external") (empty .Values.database.external.existingSecret) (empty .Values.database.external.password) -}}{{ fail "external database mode requires database.external.password or database.external.existingSecret" }}{{- end -}}
{{- if and (eq (include "netbox.cacheMode" .) "external") (empty .Values.cache.external.host) -}}{{ fail "external cache mode requires cache.external.host" }}{{- end -}}
{{- if and (eq (include "netbox.cacheMode" .) "external") (empty .Values.cache.external.existingSecret) (empty .Values.cache.external.password) -}}{{ fail "external cache mode requires cache.external.password or cache.external.existingSecret" }}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{ fail "ingress.hosts must not be empty when ingress.enabled=true" }}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}{{ fail "gatewayAPI.httpRoutes must not be empty when gatewayAPI.enabled=true" }}{{- end -}}
{{- range $i, $route := .Values.gatewayAPI.httpRoutes }}
{{- if and $.Values.gatewayAPI.enabled (empty $route.parentRefs) -}}{{ fail (printf "gatewayAPI.httpRoutes[%d].parentRefs must not be empty" $i) }}{{- end -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.netbox.metricsEnabled) -}}{{ fail "netbox.metricsEnabled must be true when ServiceMonitor is enabled" }}{{- end -}}
{{- if and .Values.persistence.enabled (empty .Values.persistence.existingClaim) (gt (int .Values.web.replicaCount) 1) (not (has "ReadWriteMany" .Values.persistence.accessModes)) -}}{{ fail "web.replicaCount > 1 requires persistence.accessModes to include ReadWriteMany" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must not be empty when enabled" }}{{- end -}}
{{- range $i, $item := .Values.externalSecrets.items }}
{{- if and $.Values.externalSecrets.enabled (empty $item.spec.secretStoreRef) (empty $item.spec.sourceRef) -}}{{ fail (printf "externalSecrets.items[%d].spec requires secretStoreRef or sourceRef" $i) }}{{- end -}}
{{- if and $.Values.externalSecrets.enabled (empty $item.spec.data) (empty $item.spec.dataFrom) -}}{{ fail (printf "externalSecrets.items[%d].spec requires data or dataFrom" $i) }}{{- end -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{ fail "podLabels must not override app.kubernetes.io/name" }}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{ fail "podLabels must not override app.kubernetes.io/instance" }}{{- end -}}
{{- end -}}
