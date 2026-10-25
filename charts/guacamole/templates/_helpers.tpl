{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "guacamole.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "guacamole.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "guacamole.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "guacamole.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "guacamole.labels" -}}
helm.sh/chart: {{ include "guacamole.chart" . }}
{{ include "guacamole.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "guacamole.selectorLabels" -}}
app.kubernetes.io/name: {{ include "guacamole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "guacamole.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "guacamole.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "guacamole.image" -}}
{{- $image := printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $image .Values.image.digest -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end -}}

{{- define "guacamole.guacdImage" -}}
{{- $image := printf "%s:%s" .Values.guacd.image.repository .Values.guacd.image.tag -}}
{{- if .Values.guacd.image.digest -}}
{{- printf "%s@%s" $image .Values.guacd.image.digest -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end -}}

{{/* ========== Database helpers ========== */}}

{{/* Resolved database type */}}
{{- define "guacamole.dbType" -}}
{{- .Values.database.type -}}
{{- end -}}

{{/* Database host */}}
{{- define "guacamole.dbHost" -}}
{{- if .Values.database.external.host -}}
{{- .Values.database.external.host -}}
{{- else if and (eq (include "guacamole.dbType" .) "postgresql") .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if and (eq (include "guacamole.dbType" .) "mysql") .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "guacamole.dbPort" -}}
{{- if .Values.database.external.port -}}
{{- .Values.database.external.port -}}
{{- else if eq (include "guacamole.dbType" .) "postgresql" -}}
{{- "5432" -}}
{{- else -}}
{{- "3306" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "guacamole.dbName" -}}
{{- if .Values.database.external.host -}}
{{- .Values.database.external.name -}}
{{- else if and (eq (include "guacamole.dbType" .) "postgresql") .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database -}}
{{- else if and (eq (include "guacamole.dbType" .) "mysql") .Values.mysql.enabled -}}
{{- .Values.mysql.auth.database -}}
{{- else -}}
{{- .Values.database.external.name -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "guacamole.dbUsername" -}}
{{- if .Values.database.external.host -}}
{{- .Values.database.external.username -}}
{{- else if and (eq (include "guacamole.dbType" .) "postgresql") .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username -}}
{{- else if and (eq (include "guacamole.dbType" .) "mysql") .Values.mysql.enabled -}}
{{- .Values.mysql.auth.username -}}
{{- else -}}
{{- .Values.database.external.username -}}
{{- end -}}
{{- end -}}

{{/* Database secret name */}}
{{- define "guacamole.dbSecretName" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if and (eq (include "guacamole.dbType" .) "postgresql") .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if and (eq (include "guacamole.dbType" .) "mysql") .Values.mysql.enabled -}}
{{- printf "%s-mysql-auth" .Release.Name -}}
{{- else -}}
{{- printf "%s-database" (include "guacamole.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "guacamole.dbSecretPasswordKey" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if and (eq (include "guacamole.dbType" .) "postgresql") .Values.postgresql.enabled -}}
{{- "user-password" -}}
{{- else if and (eq (include "guacamole.dbType" .) "mysql") .Values.mysql.enabled -}}
{{- "mysql-user-password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* Database password value (for secret creation) */}}
{{- define "guacamole.dbPassword" -}}
{{- if .Values.database.external.host -}}
{{- .Values.database.external.password -}}
{{- else if and (eq (include "guacamole.dbType" .) "postgresql") .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.password -}}
{{- else if and (eq (include "guacamole.dbType" .) "mysql") .Values.mysql.enabled -}}
{{- .Values.mysql.auth.password -}}
{{- else -}}
{{- .Values.database.external.password -}}
{{- end -}}
{{- end -}}

{{/* OIDC redirect URI — auto-detect from ingress */}}
{{- define "guacamole.oidcRedirectUri" -}}
{{- if .Values.oidc.redirectUri -}}
{{- .Values.oidc.redirectUri -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- $host := (index .Values.ingress.hosts 0).host -}}
{{- if .Values.ingress.tls -}}
{{- printf "https://%s/" $host -}}
{{- else -}}
{{- printf "http://%s/" $host -}}
{{- end -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/* SAML callback URL — auto-detect from ingress */}}
{{- define "guacamole.samlCallbackUrl" -}}
{{- if .Values.saml.callbackUrl -}}
{{- .Values.saml.callbackUrl -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- $host := (index .Values.ingress.hosts 0).host -}}
{{- if .Values.ingress.tls -}}
{{- printf "https://%s/" $host -}}
{{- else -}}
{{- printf "http://%s/" $host -}}
{{- end -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/* SAML entity ID — auto-detect from ingress */}}
{{- define "guacamole.samlEntityId" -}}
{{- if .Values.saml.entityId -}}
{{- .Values.saml.entityId -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- $host := (index .Values.ingress.hosts 0).host -}}
{{- if .Values.ingress.tls -}}
{{- printf "https://%s" $host -}}
{{- else -}}
{{- printf "http://%s" $host -}}
{{- end -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/* Backup S3 secret name */}}
{{- define "guacamole.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup-s3" (include "guacamole.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "guacamole.backupSecretAccessKeyKey" -}}
{{- .Values.backup.s3.existingSecretAccessKeyKey | default "access-key" -}}
{{- end -}}

{{- define "guacamole.backupSecretSecretKeyKey" -}}
{{- .Values.backup.s3.existingSecretSecretKeyKey | default "secret-key" -}}
{{- end -}}

{{/* ========== Validation helper ========== */}}
{{/*
Compile all validation warnings and errors into a single message.
*/}}
{{- define "guacamole.validate" -}}
{{- $messages := list -}}
{{- if and .Values.postgresql.enabled .Values.mysql.enabled -}}
  {{- $messages = append $messages "Both postgresql.enabled and mysql.enabled are set to true. Please select only one database subchart." -}}
{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not .Values.mysql.enabled) -}}
  {{- if not .Values.database.external.host -}}
    {{- $messages = append $messages "When both postgresql and mysql subcharts are disabled, database.external.host must be specified." -}}
  {{- end -}}
  {{- if and (not .Values.database.external.existingSecret) (not (include "guacamole.dbPassword" .)) -}}
    {{- $messages = append $messages "When using an external database, either database.external.existingSecret or database.external.password must be provided." -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.items) -}}
  {{- $messages = append $messages "externalSecrets.enabled is true, but externalSecrets.items is empty." -}}
{{- end -}}
{{- if and .Values.oidc.enabled (or (not .Values.oidc.authorizationEndpoint) (not .Values.oidc.clientId) (not .Values.oidc.jwksEndpoint) (not .Values.oidc.issuer)) -}}
  {{- $messages = append $messages "oidc.enabled is true, but one or more required endpoints (authorizationEndpoint, clientId, jwksEndpoint, issuer) are missing." -}}
{{- end -}}
{{- if and .Values.saml.enabled (or (and (not .Values.saml.idpMetadataUrl) (not .Values.saml.idpUrl)) (and (not .Values.saml.entityId) (not .Values.ingress.enabled))) -}}
  {{- $messages = append $messages "saml.enabled is true, but idpMetadataUrl/idpUrl or entityId is missing." -}}
{{- end -}}
{{- if $messages -}}
  {{- $leader := "\n\n================================================================================\nCHART CONFIGURATION VALIDATION ERRORS:\n================================================================================\n" -}}
  {{- $trailer := "\n================================================================================\n" -}}
  {{- $errorList := join "\n - " $messages -}}
  {{- printf "%s - %s%s" $leader $errorList $trailer | fail -}}
{{- end -}}
{{- end -}}
