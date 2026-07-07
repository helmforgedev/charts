{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ghost.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ghost.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ghost.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghost.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ghost.labels" -}}
helm.sh/chart: {{ include "ghost.chart" . }}
{{ include "ghost.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ghost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ghost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ghost.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ghost.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ghost.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "ghost.validate" -}}
{{/* Triggers backup validation failures through ghost.backupEnabled; the return value is unused. */}}
{{- $backupEnabled := include "ghost.backupEnabled" . -}}
{{- if and (not .Values.mysql.enabled) (not .Values.database.external.host) -}}
{{- fail "database.external.host is required when mysql.enabled is false" -}}
{{- end -}}
{{- if and (not .Values.mysql.enabled) (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
{{- fail "database.external.password or database.external.existingSecret is required when mysql.enabled is false" -}}
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
{{- if and .Values.gateway.enabled (not .Values.gateway.parentRefs) -}}
{{- fail "gateway.parentRefs must contain at least one parentRef when gateway.enabled is true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.database.external.existingSecret) -}}
{{- fail "database.external.existingSecret is required when externalSecrets.enabled is true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled is true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.data) -}}
{{- fail "externalSecrets.data must contain at least one entry when externalSecrets.enabled is true" -}}
{{- end -}}
{{- end -}}

{{/* Content PVC claim name */}}
{{- define "ghost.contentClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-content" (include "ghost.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database host */}}
{{- define "ghost.dbHost" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "ghost.dbPort" -}}
{{- if .Values.mysql.enabled -}}
{{- "3306" -}}
{{- else -}}
{{- .Values.database.external.port | default "3306" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "ghost.dbName" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.database | default "ghost" -}}
{{- else -}}
{{- .Values.database.external.name | default "ghost" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "ghost.dbUsername" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.username | default "ghost" -}}
{{- else -}}
{{- .Values.database.external.username | default "ghost" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "ghost.dbSecretName" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "ghost.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "ghost.dbSecretPasswordKey" -}}
{{- if .Values.mysql.enabled -}}
{{- "mysql-user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Backup - S3 secret name */}}
{{- define "ghost.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "ghost.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup - validate required fields */}}
{{- define "ghost.backupEnabled" -}}
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
