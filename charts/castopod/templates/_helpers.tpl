{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "castopod.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "castopod.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "castopod.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "castopod.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "castopod.labels" -}}
helm.sh/chart: {{ include "castopod.chart" . }}
{{ include "castopod.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "castopod.selectorLabels" -}}
app.kubernetes.io/name: {{ include "castopod.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "castopod.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "castopod.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "castopod.validate" -}}
{{- $tag := toString .Values.image.tag -}}
{{- if or (not $tag) (has (lower $tag) (list "latest" "stable" "main" "develop" "edge" "nightly")) -}}
{{- fail "image.tag must be a pinned Castopod release; floating tags are not supported" -}}
{{- end -}}
{{- if and (not .Values.mariadb.enabled) (not .Values.database.external.host) -}}
{{- fail "database.external.host is required when mariadb.enabled is false" -}}
{{- end -}}
{{- if and (not .Values.mariadb.enabled) (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
{{- fail "database.external.password or database.external.existingSecret is required when mariadb.enabled is false" -}}
{{- end -}}
{{- if and .Values.redis.enabled (not (dig "auth" "enabled" true .Values.redis)) -}}
{{- fail "redis.auth.enabled must be true: Castopod refuses to use Redis without a password" -}}
{{- end -}}
{{- if .Values.castopod.admin.create -}}
{{- if or (not .Values.castopod.admin.username) (not .Values.castopod.admin.email) -}}
{{- fail "castopod.admin.username and castopod.admin.email are required when castopod.admin.create is true" -}}
{{- end -}}
{{- if and .Values.castopod.admin.password (lt (len .Values.castopod.admin.password) 8) -}}
{{- fail "castopod.admin.password must contain at least 8 characters" -}}
{{- end -}}
{{- end -}}
{{- $baseURL := include "castopod.baseURL" . -}}
{{- if not (regexMatch "^https?://[^/]+(/.*[^/])?$" $baseURL) -}}
{{- fail "castopod.baseURL must start with http:// or https:// and must not end with a slash" -}}
{{- end -}}
{{- if .Values.ingress.enabled -}}
{{- if not .Values.ingress.hosts -}}
{{- fail "ingress.enabled requires ingress.hosts to contain at least one host" -}}
{{- end -}}
{{- range $index, $host := .Values.ingress.hosts -}}
{{- if not $host.host -}}
{{- fail (printf "ingress.hosts[%d].host is required when ingress.enabled is true" $index) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (not .Values.gatewayAPI.httpRoutes) -}}
{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if .Values.gatewayAPI.enabled -}}
{{- range .Values.gatewayAPI.httpRoutes -}}
{{- if not .parentRefs -}}
{{- fail "every gatewayAPI.httpRoutes[] entry requires parentRefs" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if .Values.gatewayAPI.enabled -}}
{{- $routeNames := dict -}}
{{- range .Values.gatewayAPI.httpRoutes -}}
{{- $routeName := include "castopod.httpRouteName" (dict "root" $ "route" .) -}}
{{- if hasKey $routeNames $routeName -}}
{{- fail (printf "gatewayAPI.httpRoutes renders the HTTPRoute name %q twice; give every route a unique name" $routeName) -}}
{{- end -}}
{{- $_ := set $routeNames $routeName true -}}
{{- end -}}
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
{{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "castopod.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Full name of a HelmForge subchart, mirroring its own fullname logic */}}
{{- define "castopod.subchartFullname" -}}
{{- $root := index . "root" -}}
{{- $chart := index . "chart" -}}
{{- $values := index . "values" | default dict -}}
{{- $override := dig "fullnameOverride" "" $values -}}
{{- if $override -}}
{{- $override | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := dig "nameOverride" "" $values | default $chart -}}
{{- if contains $name $root.Release.Name -}}
{{- $root.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $root.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "castopod.mariadbFullname" -}}
{{- include "castopod.subchartFullname" (dict "root" . "chart" "mariadb" "values" .Values.mariadb) -}}
{{- end -}}

{{- define "castopod.redisFullname" -}}
{{- include "castopod.subchartFullname" (dict "root" . "chart" "redis" "values" .Values.redis) -}}
{{- end -}}

{{/* Database host */}}
{{- define "castopod.dbHost" -}}
{{- if .Values.mariadb.enabled -}}
{{- include "castopod.mariadbFullname" . -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "castopod.dbPort" -}}
{{- if .Values.mariadb.enabled -}}
{{- "3306" -}}
{{- else -}}
{{- .Values.database.external.port | default "3306" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "castopod.dbName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.database | default "castopod" -}}
{{- else -}}
{{- .Values.database.external.name | default "castopod" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "castopod.dbUsername" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.username | default "castopod" -}}
{{- else -}}
{{- .Values.database.external.username | default "castopod" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "castopod.dbSecretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- dig "auth" "existingSecret" "" .Values.mariadb | default (printf "%s-auth" (include "castopod.mariadbFullname" .)) -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "castopod.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "castopod.dbSecretPasswordKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- dig "auth" "existingSecretUserPasswordKey" "mariadb-user-password" .Values.mariadb -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Redis client Service of the HelmForge Redis subchart */}}
{{- define "castopod.redisHost" -}}
{{- printf "%s-client" (include "castopod.redisFullname" .) -}}
{{- end -}}

{{/* Redis password Secret of the subchart */}}
{{- define "castopod.redisSecretName" -}}
{{- dig "auth" "existingSecret" "" .Values.redis | default (printf "%s-auth" (include "castopod.redisFullname" .)) -}}
{{- end -}}

{{- define "castopod.redisSecretKey" -}}
{{- dig "auth" "existingSecretPasswordKey" "redis-password" .Values.redis -}}
{{- end -}}

{{/* Public base URL: explicit value, first Ingress host, first HTTPRoute hostname, or localhost */}}
{{- define "castopod.baseURL" -}}
{{- if .Values.castopod.baseURL -}}
{{- .Values.castopod.baseURL -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts (first .Values.ingress.hosts).host -}}
{{- printf "%s://%s" (ternary "https" "http" (not (empty .Values.ingress.tls))) (first .Values.ingress.hosts).host -}}
{{- else if and .Values.gatewayAPI.enabled .Values.gatewayAPI.httpRoutes (first .Values.gatewayAPI.httpRoutes).hostnames -}}
{{- printf "https://%s" (first (first .Values.gatewayAPI.httpRoutes).hostnames) -}}
{{- else -}}
{{- "http://localhost:8080" -}}
{{- end -}}
{{- end -}}

{{/* Superadmin password Secret */}}
{{- define "castopod.adminSecretName" -}}
{{- if .Values.castopod.admin.existingSecret -}}
{{- .Values.castopod.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "castopod.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "castopod.adminSecretKey" -}}
{{- if .Values.castopod.admin.existingSecret -}}
{{- .Values.castopod.admin.existingSecretPasswordKey | default "admin-password" -}}
{{- else -}}
{{- "admin-password" -}}
{{- end -}}
{{- end -}}

{{/* Value from an explicit setting, else the existing Secret, else a new random string */}}
{{- define "castopod.persistedSecretValue" -}}
{{- $existing := lookup "v1" "Secret" .root.Release.Namespace .name -}}
{{- if .value -}}
{{- .value -}}
{{- else if and $existing (index ($existing.data | default dict) .key) -}}
{{- index $existing.data .key | b64dec -}}
{{- else -}}
{{- randAlphaNum (.length | default 32) -}}
{{- end -}}
{{- end -}}

{{/* HTTPRoute name */}}
{{- define "castopod.httpRouteName" -}}
{{- $root := index . "root" -}}
{{- $route := index . "route" -}}
{{- $fullname := include "castopod.fullname" $root -}}
{{- $routeName := $route.name | default "" | trunc 32 | trimSuffix "-" -}}
{{- if $routeName -}}
{{- printf "%s-%s" ($fullname | trunc (int (sub 62 (len $routeName))) | trimSuffix "-") $routeName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $fullname -}}
{{- end -}}
{{- end -}}

{{/* Analytics salt secret name */}}
{{- define "castopod.analyticsSecretName" -}}
{{- if .Values.analytics.existingSecret -}}
{{- .Values.analytics.existingSecret -}}
{{- else -}}
{{- printf "%s-analytics" (include "castopod.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Analytics salt secret key */}}
{{- define "castopod.analyticsSecretKey" -}}
{{- if .Values.analytics.existingSecret -}}
{{- .Values.analytics.existingSecretKey | default "analytics-salt" -}}
{{- else -}}
{{- "analytics-salt" -}}
{{- end -}}
{{- end -}}

{{/* PVC name */}}
{{- define "castopod.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "castopod.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup — S3 secret name */}}
{{- define "castopod.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "castopod.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "castopod.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
true
{{- end -}}
{{- end -}}
