{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "countly.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "countly.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "countly.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "countly.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "countly.labels" -}}
helm.sh/chart: {{ include "countly.chart" . }}
{{ include "countly.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "countly.selectorLabels" -}}
app.kubernetes.io/name: {{ include "countly.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "countly.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "countly.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "countly.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "countly.validate" -}}
{{- if and .Values.externalMongodb.enabled (not .Values.externalMongodb.uri) (not .Values.externalMongodb.existingSecret) -}}
{{- fail "externalMongodb.uri or externalMongodb.existingSecret is required when externalMongodb.enabled=true" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one rule when ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.gateway.enabled (not .Values.gateway.parentRefs) -}}
{{- fail "gateway.enabled requires gateway.parentRefs to be populated to create a valid HTTPRoute." -}}
{{- end -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.externalMongodb.enabled -}}
    {{- fail "externalSecrets.enabled requires externalMongodb.enabled=true; the Deployment only mounts the MongoDB secret when external MongoDB is active." -}}
  {{- end -}}
  {{- if not .Values.externalMongodb.existingSecret -}}
    {{- fail "externalSecrets.enabled requires externalMongodb.existingSecret to be set to prevent credential drift between the chart-managed Secret and the ExternalSecret." -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.data -}}
    {{- fail "externalSecrets.data must not be empty when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- $uriKey := .Values.externalMongodb.existingSecretUriKey | default "mongodb-uri" -}}
  {{- $hasUri := false -}}
  {{- range .Values.externalSecrets.data -}}
    {{- if eq .secretKey $uriKey }}{{ $hasUri = true }}{{ end -}}
  {{- end -}}
  {{- if not $hasUri -}}
    {{- fail (printf "externalSecrets.data must include a mapping for key '%s' (MongoDB connection URI)" $uriKey) -}}
  {{- end -}}
{{- end -}}
{{- if .Values.backup.enabled -}}
  {{- $_ := include "countly.backupEnabled" . -}}
  {{- $_ := include "countly.backupMongodbUri" . -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* MongoDB host */}}
{{- define "countly.mongodbHost" -}}
{{- if .Values.mongodb.enabled -}}
{{- if contains "mongodb" .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-mongodb" .Release.Name -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* MongoDB URI */}}
{{- define "countly.mongodbUri" -}}
{{- if .Values.externalMongodb.enabled -}}
{{- .Values.externalMongodb.uri -}}
{{- else -}}
{{- printf "mongodb://root:$(MONGODB_ROOT_PASSWORD)@%s-mongodb:27017/countly?authSource=admin" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* MongoDB secret name */}}
{{- define "countly.mongodbSecretName" -}}
{{- if .Values.externalMongodb.enabled -}}
{{- .Values.externalMongodb.existingSecret -}}
{{- else -}}
{{- printf "%s-mongodb" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Backup - S3 secret name */}}
{{- define "countly.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "countly.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup - validate required fields */}}
{{- define "countly.backupEnabled" -}}
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

{{/* Backup - MongoDB URI (hardcoded password for non-interactive dump) */}}
{{- define "countly.backupMongodbUri" -}}
{{- if .Values.backup.database.uri -}}
{{- .Values.backup.database.uri -}}
{{- else if .Values.externalMongodb.enabled -}}
{{- if and .Values.externalMongodb.existingSecret (not .Values.externalMongodb.uri) -}}
  {{- fail "backup requires backup.database.uri when externalMongodb.existingSecret is set and externalMongodb.uri is empty (the URI is in the secret and cannot be injected into mongodump)" -}}
{{- end -}}
{{- .Values.externalMongodb.uri -}}
{{- else -}}
{{- printf "mongodb://root:$(MONGODB_ROOT_PASSWORD)@%s-mongodb:27017/countly?authSource=admin" .Release.Name -}}
{{- end -}}
{{- end -}}
