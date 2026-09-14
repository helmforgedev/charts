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
{{- define "nextcloud.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- define "nextcloud.secretName" -}}{{ default (printf "%s-auth" (include "nextcloud.fullname" .)) .Values.nextcloud.existingSecret }}{{- end -}}
{{- define "nextcloud.backupName" -}}{{ printf "%s-backup" (include "nextcloud.fullname" . | trunc 45 | trimSuffix "-") }}{{- end -}}
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
{{- if and .Values.backup.enabled .Values.restore.enabled -}}{{ fail "backup.enabled and restore.enabled cannot both be true" }}{{- end -}}
{{- if or .Values.backup.enabled .Values.restore.enabled -}}
{{- if not .Values.persistence.enabled -}}{{ fail "backup and restore require persistence.enabled=true" }}{{- end -}}
{{- if or (not .Values.backup.s3.bucket) (not .Values.backup.s3.existingSecret) -}}{{ fail "backup.s3.bucket and backup.s3.existingSecret are required" }}{{- end -}}
{{- end -}}
{{- if and .Values.restore.enabled (not .Values.restore.backupPath) -}}{{ fail "restore.backupPath is required" }}{{- end -}}
{{- if and .Values.restore.enabled (not .Values.nextcloud.existingSecret) (not .Values.nextcloud.adminPassword) -}}{{ fail "restore requires the original administrator credentials through nextcloud.existingSecret or nextcloud.adminPassword" }}{{- end -}}
{{- if and .Values.smtp.enabled (not .Values.smtp.host) -}}{{ fail "smtp.host is required" }}{{- end -}}
{{- if and .Values.smtp.enabled .Values.smtp.username (not .Values.smtp.existingSecret) -}}{{ fail "smtp.existingSecret is required for authenticated SMTP" }}{{- end -}}
{{- if not .Values.postgresql.enabled -}}
{{- if or (not .Values.externalDatabase.host) (not .Values.externalDatabase.existingSecret) -}}{{ fail "externalDatabase.host and externalDatabase.existingSecret are required when postgresql.enabled=false" }}{{- end -}}
{{- end -}}
{{- if not .Values.redis.enabled -}}
{{- if or (not .Values.externalRedis.host) (not .Values.externalRedis.existingSecret) -}}{{ fail "externalRedis.host and externalRedis.existingSecret are required when redis.enabled=false" }}{{- end -}}
{{- else if ne .Values.redis.architecture "standalone" -}}{{ fail "nextcloud requires standalone Redis; Sentinel and Redis Cluster are not supported" }}
{{- end -}}
{{- if not .Values.nextcloud.trustedDomains -}}{{ fail "nextcloud.trustedDomains must contain at least one host" }}{{- end -}}
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
