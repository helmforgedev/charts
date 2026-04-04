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
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "guacamole.guacdImage" -}}
{{- printf "%s:%s" .Values.guacd.image.repository .Values.guacd.image.tag -}}
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
{{- else -}}
{{- printf "%s-database" (include "guacamole.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "guacamole.dbSecretPasswordKey" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
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
