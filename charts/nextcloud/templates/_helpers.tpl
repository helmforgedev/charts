{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "nextcloud.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "nextcloud.fullname" -}}
{{- if .Values.fullnameOverride -}}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if contains (include "nextcloud.name" .) .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name (include "nextcloud.name" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- define "nextcloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nextcloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "nextcloud.labels" -}}
{{ include "nextcloud.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{/* Merge chart-wide annotations with resource-specific annotations; resource values win. */}}
{{- define "nextcloud.annotations" -}}
{{- $common := deepCopy (.root.Values.commonAnnotations | default dict) -}}
{{- $specific := .specific | default dict -}}
{{- $merged := mergeOverwrite $common $specific -}}
{{- if $merged -}}{{ toYaml $merged }}{{- end -}}
{{- end -}}
{{- define "nextcloud.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- define "nextcloud.secretName" -}}{{ default (printf "%s-auth" (include "nextcloud.fullname" .)) .Values.nextcloud.existingSecret }}{{- end -}}
{{- define "nextcloud.backupName" -}}{{ printf "%s-backup" (include "nextcloud.fullname" . | trunc 45 | trimSuffix "-") }}{{- end -}}
{{- define "nextcloud.backupServiceAccountName" -}}
{{- if .Values.backup.serviceAccount.create -}}
{{- default (include "nextcloud.backupName" .) .Values.backup.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.backup.serviceAccount.name -}}
{{- end -}}
{{- end -}}
{{- define "nextcloud.primaryObjectStoreServiceAccountName" -}}
{{- if .Values.primaryObjectStore.serviceAccount.create -}}
{{- default (printf "%s-primary-object-store" (include "nextcloud.fullname" . | trunc 42 | trimSuffix "-")) .Values.primaryObjectStore.serviceAccount.name -}}
{{- else -}}
{{- .Values.primaryObjectStore.serviceAccount.name -}}
{{- end -}}
{{- end -}}
{{- define "nextcloud.primaryObjectStoreGuardName" -}}{{ printf "%s-primary-object-store-guard" (include "nextcloud.fullname" . | trunc 36 | trimSuffix "-") }}{{- end -}}
{{- define "nextcloud.primaryObjectStoreHost" -}}
{{- $endpoint := trimSuffix "/" .Values.primaryObjectStore.endpoint -}}
{{- $endpoint = regexReplaceAll "^https?://" $endpoint "" -}}
{{- $endpoint -}}
{{- end -}}
{{- define "nextcloud.primaryObjectStoreConfiguration" -}}
{{- $store := .Values.primaryObjectStore -}}
{{- dict
  "autocreate" $store.autocreate
  "bucket" $store.bucket
  "credentialsFromPodIdentity" $store.credentialsFromPodIdentity
  "endpoint" (include "nextcloud.primaryObjectStoreHost" .)
  "existingSecret" $store.existingSecret
  "existingSecretAccessKeyKey" $store.existingSecretAccessKeyKey
  "existingSecretSecretKeyKey" $store.existingSecretSecretKeyKey
  "legacyAuth" $store.legacyAuth
  "objectPrefix" $store.objectPrefix
  "port" $store.port
  "provider" $store.provider
  "region" $store.region
  "storageClass" $store.storageClass
  "usePathStyle" $store.usePathStyle
  "useSsl" $store.useSsl
  | toJson -}}
{{- end -}}
{{- define "nextcloud.cronName" -}}{{ printf "%s-cron" (include "nextcloud.fullname" . | trunc 47 | trimSuffix "-") }}{{- end -}}
{{- define "nextcloud.restoreName" -}}{{ printf "%s-restore" (include "nextcloud.fullname" . | trunc 55 | trimSuffix "-") }}{{- end -}}
{{- define "nextcloud.dbHost" -}}
{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}
{{- else -}}{{ .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "nextcloud.dbName" -}}{{ if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.database }}{{ else }}{{ .Values.externalDatabase.database }}{{ end }}{{- end -}}
{{- define "nextcloud.dbUser" -}}{{ if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.username }}{{ else }}{{ .Values.externalDatabase.username }}{{ end }}{{- end -}}
{{- define "nextcloud.dbSecret" -}}{{ if .Values.postgresql.enabled }}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{ else }}{{ .Values.externalDatabase.existingSecret }}{{ end }}{{- end -}}
{{- define "nextcloud.dbKey" -}}{{ if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{ else }}{{ .Values.externalDatabase.existingSecretPasswordKey }}{{ end }}{{- end -}}
{{- define "nextcloud.redisHost" -}}{{ if .Values.redis.enabled }}{{ include "redis.clientServiceName" .Subcharts.redis }}{{ else }}{{ .Values.externalRedis.host }}{{ end }}{{- end -}}
{{- define "nextcloud.redisSecret" -}}{{ if .Values.redis.enabled }}{{ include "redis.secretName" .Subcharts.redis }}{{ else }}{{ .Values.externalRedis.existingSecret }}{{ end }}{{- end -}}
{{- define "nextcloud.redisKey" -}}{{ if .Values.redis.enabled }}{{ .Values.redis.auth.existingSecretPasswordKey }}{{ else }}{{ .Values.externalRedis.existingSecretPasswordKey }}{{ end }}{{- end -}}
{{- define "nextcloud.validate" -}}
{{- $claimAccessModes := .Values.persistence.accessModes -}}
{{- if .Values.persistence.existingClaim -}}
{{- $claimAccessModes = .Values.persistence.existingClaimAccessModes -}}
{{- if and (or .Values.cron.enabled .Values.backup.enabled) (empty $claimAccessModes) -}}{{ fail "persistence.existingClaimAccessModes must declare the existing PVC access modes when cron.enabled or backup.enabled is true" }}{{- end -}}
{{- end -}}
{{- if and .Values.cron.enabled (not .Values.persistence.enabled) -}}{{ fail "cron.enabled requires persistence.enabled=true so the CronJob can execute the installed application" }}{{- end -}}
{{- if and .Values.cron.enabled (has "ReadWriteOncePod" $claimAccessModes) -}}{{ fail "cron.enabled is incompatible with ReadWriteOncePod because the application and CronJob must mount the PVC from separate Pods" }}{{- end -}}
{{- if and .Values.backup.enabled (has "ReadWriteOncePod" $claimAccessModes) -}}{{ fail "backup.enabled is incompatible with ReadWriteOncePod because the application and backup Job must mount the PVC from separate Pods" }}{{- end -}}
{{- if and .Values.backup.enabled .Values.restore.enabled -}}{{ fail "backup.enabled and restore.enabled cannot both be true" }}{{- end -}}
{{- if or .Values.backup.enabled .Values.restore.enabled -}}
{{- if not .Values.persistence.enabled -}}{{ fail "backup and restore require persistence.enabled=true" }}{{- end -}}
{{- if not .Values.backup.s3.bucket -}}{{ fail "backup.s3.bucket is required" }}{{- end -}}
{{- if and (not .Values.backup.s3.credentialsFromPodIdentity) (not .Values.backup.s3.existingSecret) -}}{{ fail "backup.s3.existingSecret is required when backup.s3.credentialsFromPodIdentity=false" }}{{- end -}}
{{- if and (not .Values.backup.serviceAccount.create) (not .Values.backup.serviceAccount.name) -}}{{ fail "backup.serviceAccount.name is required when backup.serviceAccount.create=false" }}{{- end -}}
{{- end -}}
{{- if and .Values.restore.enabled (not .Values.restore.backupPath) -}}{{ fail "restore.backupPath is required" }}{{- end -}}
{{- if and .Values.restore.enabled (not .Values.nextcloud.existingSecret) (not .Values.nextcloud.adminPassword) -}}{{ fail "restore requires the original administrator credentials through nextcloud.existingSecret or nextcloud.adminPassword" }}{{- end -}}
{{- if and .Values.smtp.enabled (not .Values.smtp.host) -}}{{ fail "smtp.host is required" }}{{- end -}}
{{- if and .Values.smtp.enabled .Values.smtp.username (not .Values.smtp.existingSecret) -}}{{ fail "smtp.existingSecret is required for authenticated SMTP" }}{{- end -}}
{{- if .Values.primaryObjectStore.enabled -}}
{{- $store := .Values.primaryObjectStore -}}
{{- if ne $store.provider "s3" -}}{{ fail "primaryObjectStore.provider must be s3" }}{{- end -}}
{{- if not $store.endpoint -}}{{ fail "primaryObjectStore.endpoint is required when primaryObjectStore.enabled=true" }}{{- end -}}
{{- if not $store.bucket -}}{{ fail "primaryObjectStore.bucket is required when primaryObjectStore.enabled=true" }}{{- end -}}
{{- $host := include "nextcloud.primaryObjectStoreHost" . -}}
{{- if contains "/" $host -}}{{ fail "primaryObjectStore.endpoint must not contain a path" }}{{- end -}}
{{- if and (hasPrefix "http://" $store.endpoint) $store.useSsl -}}{{ fail "primaryObjectStore.endpoint uses http:// but primaryObjectStore.useSsl=true" }}{{- end -}}
{{- if and (hasPrefix "https://" $store.endpoint) (not $store.useSsl) -}}{{ fail "primaryObjectStore.endpoint uses https:// but primaryObjectStore.useSsl=false" }}{{- end -}}
{{- if and (not $store.credentialsFromPodIdentity) (not $store.existingSecret) -}}{{ fail "primaryObjectStore.existingSecret is required when primaryObjectStore.credentialsFromPodIdentity=false" }}{{- end -}}
{{- if and $store.credentialsFromPodIdentity (not $store.serviceAccount.create) (not $store.serviceAccount.name) -}}{{ fail "primaryObjectStore.serviceAccount.name is required when workload identity is enabled and ServiceAccount creation is disabled" }}{{- end -}}
{{- if and .Values.networkPolicy.enabled (empty $store.networkPolicyEgress) -}}{{ fail "primaryObjectStore.networkPolicyEgress is required when primary object storage and NetworkPolicy are enabled" }}{{- end -}}
{{- if and .Values.backup.enabled (eq $store.bucket .Values.backup.s3.bucket) -}}{{ fail "primaryObjectStore.bucket and backup.s3.bucket must be different" }}{{- end -}}
{{- end -}}
{{- $guard := lookup "v1" "Secret" .Release.Namespace (include "nextcloud.primaryObjectStoreGuardName" .) -}}
{{- if and $guard $guard.data (eq ((index $guard.data "state") | default "" | b64dec) "enabled") -}}
{{- $previous := (index $guard.data "configuration") | default "" | b64dec -}}
{{- $current := ternary (include "nextcloud.primaryObjectStoreConfiguration" .) "disabled" .Values.primaryObjectStore.enabled -}}
{{- if ne $previous $current -}}
{{- $requiredHash := sha256sum $previous -}}
{{- if ne .Values.primaryObjectStore.protection.acknowledgePreviousConfigurationHash $requiredHash -}}
{{- fail (printf "primary object storage is already enabled; refusing to change or disable it without primaryObjectStore.protection.acknowledgePreviousConfigurationHash=%s" $requiredHash) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not .Values.postgresql.enabled -}}
{{- if or (not .Values.externalDatabase.host) (not .Values.externalDatabase.existingSecret) -}}{{ fail "externalDatabase.host and externalDatabase.existingSecret are required when postgresql.enabled=false" }}{{- end -}}
{{- end -}}
{{- if not .Values.redis.enabled -}}
{{- if or (not .Values.externalRedis.host) (not .Values.externalRedis.existingSecret) -}}{{ fail "externalRedis.host and externalRedis.existingSecret are required when redis.enabled=false" }}{{- end -}}
{{- else if ne .Values.redis.architecture "standalone" -}}{{ fail "nextcloud requires standalone Redis; Sentinel and Redis Cluster are not supported" }}
{{- end -}}
{{- if not .Values.nextcloud.trustedDomains -}}{{ fail "nextcloud.trustedDomains must contain at least one host" }}{{- end -}}
{{- if and (hasPrefix "http://" .Values.backup.s3.endpoint) (not .Values.backup.s3.allowInsecureHTTP) -}}{{ fail "HTTP S3 endpoints require backup.s3.allowInsecureHTTP=true on a trusted isolated network" }}{{- end -}}
{{- end -}}
{{- define "nextcloud.httpRouteName" -}}{{ default (include "nextcloud.fullname" .root) .route.name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "nextcloud.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride }}
{{- else if .item.name -}}{{ printf "%s-%s" (include "nextcloud.fullname" .root) .item.name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ include "nextcloud.secretName" .root }}{{- end -}}
{{- end -}}
{{- define "nextcloud.authManagedByESO" -}}
{{- $managed := false -}}
{{- if .Values.externalSecrets.enabled -}}
{{- range .Values.externalSecrets.items -}}
{{- $target := dig "spec" "target" "name" "" . | default (include "nextcloud.externalSecretName" (dict "root" $ "item" .)) -}}
{{- if eq $target (include "nextcloud.secretName" $) -}}{{- $managed = true -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- if $managed -}}true{{- end -}}
{{- end -}}

{{- define "nextcloud.primaryObjectStoreEnv" -}}
{{- if .Values.primaryObjectStore.enabled }}
- name: OBJECTSTORE_S3_BUCKET
  value: {{ .Values.primaryObjectStore.bucket | quote }}
- name: OBJECTSTORE_S3_REGION
  value: {{ .Values.primaryObjectStore.region | quote }}
- name: OBJECTSTORE_S3_HOST
  value: {{ include "nextcloud.primaryObjectStoreHost" . | quote }}
- name: OBJECTSTORE_S3_PORT
  value: {{ .Values.primaryObjectStore.port | quote }}
- name: OBJECTSTORE_S3_STORAGE_CLASS
  value: {{ .Values.primaryObjectStore.storageClass | quote }}
- name: OBJECTSTORE_S3_OBJECT_PREFIX
  value: {{ .Values.primaryObjectStore.objectPrefix | quote }}
- name: OBJECTSTORE_S3_SSL
  value: {{ .Values.primaryObjectStore.useSsl | quote }}
- name: OBJECTSTORE_S3_USEPATH_STYLE
  value: {{ .Values.primaryObjectStore.usePathStyle | quote }}
- name: OBJECTSTORE_S3_LEGACYAUTH
  value: {{ .Values.primaryObjectStore.legacyAuth | quote }}
- name: OBJECTSTORE_S3_AUTOCREATE
  value: {{ .Values.primaryObjectStore.autocreate | quote }}
{{- if not .Values.primaryObjectStore.credentialsFromPodIdentity }}
- name: OBJECTSTORE_S3_KEY_FILE
  value: /var/run/nextcloud-primary-object-store/access-key
- name: OBJECTSTORE_S3_SECRET_FILE
  value: /var/run/nextcloud-primary-object-store/secret-key
{{- end }}
{{- end }}
{{- end -}}

{{- define "nextcloud.backendEnv" -}}
- name: POSTGRES_HOST
  value: {{ printf "%s:%v" (include "nextcloud.dbHost" .) (ternary 5432 .Values.externalDatabase.port .Values.postgresql.enabled) | quote }}
- name: POSTGRES_DB
  value: {{ include "nextcloud.dbName" . | quote }}
- name: POSTGRES_USER
  value: {{ include "nextcloud.dbUser" . | quote }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "nextcloud.dbSecret" . }}
      key: {{ include "nextcloud.dbKey" . }}
- name: REDIS_HOST
  value: {{ include "nextcloud.redisHost" . | quote }}
- name: REDIS_HOST_PORT
  value: {{ ternary 6379 .Values.externalRedis.port .Values.redis.enabled | quote }}
- name: REDIS_HOST_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "nextcloud.redisSecret" . }}
      key: {{ include "nextcloud.redisKey" . }}
{{- end -}}
