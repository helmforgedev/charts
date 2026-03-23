{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "wordpress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "wordpress.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "wordpress.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "wordpress.labels" -}}
helm.sh/chart: {{ include "wordpress.chart" . }}
{{ include "wordpress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: wordpress
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "wordpress.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wordpress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "wordpress.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "wordpress.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image string with tag fallback to appVersion.
*/}}
{{- define "wordpress.image" -}}
{{- $tag := default (printf "%s-apache" .Chart.AppVersion) .Values.image.tag }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Database mode detection (auto | external | mysql).
Auto precedence:
  1. database.external.host or database.external.existingSecret → external
  2. mysql.enabled → mysql
  3. fail (WordPress requires a database)
*/}}
{{- define "wordpress.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "mysql")) -}}
{{- fail (printf "database.mode must be one of: auto, external, mysql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasMysql -}}
    {{- fail "wordpress database selection is ambiguous: configure only one of database.external.host or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasMysql -}}mysql
  {{- else -}}
    {{- fail "wordpress requires a database: set database.external.host or mysql.enabled=true" -}}
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}
  {{- end -}}
  {{- if and (eq $mode "external") $hasMysql -}}
    {{- fail "database.mode=external cannot be combined with mysql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}
    {{- fail "database.mode=mysql requires mysql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") $hasExternal -}}
    {{- fail "database.mode=mysql cannot be combined with database.external" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{/*
Database host.
*/}}
{{- define "wordpress.databaseHost" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Database port.
*/}}
{{- define "wordpress.databasePort" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.port | default 3306 | toString -}}
{{- else -}}
{{- print "3306" -}}
{{- end -}}
{{- end -}}

{{/*
Database name.
*/}}
{{- define "wordpress.databaseName" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.mysql.auth.database -}}
{{- end -}}
{{- end -}}

{{/*
Database username.
*/}}
{{- define "wordpress.databaseUsername" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.mysql.auth.username -}}
{{- end -}}
{{- end -}}

{{/*
Database password secret name.
*/}}
{{- define "wordpress.databaseSecretName" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Database password secret key.
*/}}
{{- define "wordpress.databaseSecretKey" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else -}}
{{- print "database-password" -}}
{{- end -}}
{{- end -}}

{{/*
Database password value (for generating secrets).
*/}}
{{- define "wordpress.databasePasswordValue" -}}
{{- $mode := include "wordpress.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.password -}}
{{- else -}}
{{- .Values.mysql.auth.password -}}
{{- end -}}
{{- end -}}

{{/*
Admin secret name.
*/}}
{{- define "wordpress.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Admin secret key.
*/}}
{{- define "wordpress.adminSecretKey" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecretPasswordKey -}}
{{- else -}}
{{- print "admin-password" -}}
{{- end -}}
{{- end -}}

{{/*
Backup enabled (with validation).
*/}}
{{- define "wordpress.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{/*
Backup S3 secret name.
*/}}
{{- define "wordpress.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "wordpress.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup database host (override or fallback to app).
*/}}
{{- define "wordpress.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "wordpress.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database port.
*/}}
{{- define "wordpress.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "wordpress.databasePort" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database name.
*/}}
{{- define "wordpress.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "wordpress.databaseName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database username.
*/}}
{{- define "wordpress.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "wordpress.databaseUsername" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret name.
*/}}
{{- define "wordpress.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else -}}
{{- include "wordpress.databaseSecretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret key.
*/}}
{{- define "wordpress.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey -}}
{{- else -}}
{{- include "wordpress.databaseSecretKey" . -}}
{{- end -}}
{{- end -}}

{{/*
ConfigMap name.
*/}}
{{- define "wordpress.configMapName" -}}
{{- printf "%s-config" (include "wordpress.fullname" .) -}}
{{- end -}}
