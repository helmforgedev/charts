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
{{- if and (not .Values.mariadb.enabled) (not .Values.database.external.host) -}}
{{- fail "database.external.host is required when mariadb.enabled is false" -}}
{{- end -}}
{{- if and (not .Values.mariadb.enabled) (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
{{- fail "database.external.password or database.external.existingSecret is required when mariadb.enabled is false" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.enabled requires ingress.hosts to contain at least one host" -}}
{{- end -}}
{{- if .Values.ingress.enabled -}}
{{- range $index, $host := .Values.ingress.hosts -}}
{{- if not $host.host -}}
{{- fail (printf "ingress.hosts[%d].host is required when ingress.enabled is true" $index) -}}
{{- end -}}
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

{{/* Database host */}}
{{- define "castopod.dbHost" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
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
{{- printf "%s-mariadb-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "castopod.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "castopod.dbSecretPasswordKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- "mariadb-user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Redis host */}}
{{- define "castopod.redisHost" -}}
{{- printf "%s-redis" .Release.Name -}}
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
