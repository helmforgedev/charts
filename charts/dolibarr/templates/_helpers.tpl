{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "dolibarr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "dolibarr.fullname" -}}
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
{{- define "dolibarr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "dolibarr.labels" -}}
helm.sh/chart: {{ include "dolibarr.chart" . }}
{{ include "dolibarr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: dolibarr
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "dolibarr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dolibarr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "dolibarr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dolibarr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image string with tag fallback to appVersion.
*/}}
{{- define "dolibarr.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{/*
Database mode detection (auto | external | mysql).
*/}}
{{- define "dolibarr.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "mysql")) -}}
{{- fail (printf "database.mode must be one of: auto, external, mysql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasMysql -}}
    {{- fail "dolibarr database selection is ambiguous: configure only one of database.external.host or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasMysql -}}mysql
  {{- else -}}
    {{- fail "dolibarr requires a database: set database.external.host or mysql.enabled=true" -}}
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

{{- define "dolibarr.databaseHost" -}}
{{- if eq (include "dolibarr.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.databasePort" -}}
{{- if eq (include "dolibarr.databaseMode" .) "external" -}}
{{- .Values.database.external.port | default 3306 | toString -}}
{{- else -}}
3306
{{- end -}}
{{- end -}}

{{- define "dolibarr.databaseName" -}}
{{- if eq (include "dolibarr.databaseMode" .) "external" -}}
{{- .Values.database.external.name -}}
{{- else -}}
{{- .Values.mysql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.databaseUsername" -}}
{{- if eq (include "dolibarr.databaseMode" .) "external" -}}
{{- .Values.database.external.username -}}
{{- else -}}
{{- .Values.mysql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.databaseSsl" -}}
{{- if eq (include "dolibarr.databaseMode" .) "external" -}}
{{ ternary "1" "0" (.Values.database.external.ssl | default false) }}
{{- else -}}
0
{{- end -}}
{{- end -}}

{{- define "dolibarr.databaseSecretName" -}}
{{- if and (eq (include "dolibarr.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "dolibarr.databaseMode" .) "mysql" -}}
{{- printf "%s-mysql-auth" .Release.Name -}}
{{- else -}}
{{- printf "%s-database" (include "dolibarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.databaseSecretKey" -}}
{{- if and (eq (include "dolibarr.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq (include "dolibarr.databaseMode" .) "mysql" -}}
mysql-user-password
{{- else -}}
database-password
{{- end -}}
{{- end -}}

{{- define "dolibarr.databasePasswordValue" -}}
{{- if eq (include "dolibarr.databaseMode" .) "external" -}}
{{- .Values.database.external.password -}}
{{- else -}}
{{- .Values.mysql.auth.password -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "dolibarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.adminSecretKey" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecretPasswordKey -}}
{{- else -}}
admin-password
{{- end -}}
{{- end -}}

{{- define "dolibarr.runtimeSecretName" -}}
{{- if .Values.runtime.existingSecret -}}
{{- .Values.runtime.existingSecret -}}
{{- else -}}
{{- printf "%s-runtime" (include "dolibarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.runtimeInstanceUniqueIdKey" -}}
{{- if .Values.runtime.existingSecret -}}
{{- .Values.runtime.existingSecretInstanceUniqueIdKey -}}
{{- else -}}
instance-unique-id
{{- end -}}
{{- end -}}

{{- define "dolibarr.urlRoot" -}}
{{- if .Values.dolibarr.siteUrl -}}
{{- .Values.dolibarr.siteUrl -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- $host := (index .Values.ingress.hosts 0).host -}}
{{- $scheme := ternary "https" "http" (gt (len .Values.ingress.tls) 0) -}}
{{- printf "%s://%s" $scheme $host -}}
{{- else -}}
{{- print "" -}}
{{- end -}}
{{- end -}}

{{- define "dolibarr.documentsPvcName" -}}
{{- default (printf "%s-documents" (include "dolibarr.fullname" .)) .Values.persistence.documents.existingClaim -}}
{{- end -}}

{{- define "dolibarr.customPvcName" -}}
{{- default (printf "%s-custom" (include "dolibarr.fullname" .)) .Values.persistence.custom.existingClaim -}}
{{- end -}}

{{/*
Backup S3 secret name.
Uses backup.s3.existingSecret when set, otherwise <fullname>-backup.
*/}}
{{- define "dolibarr.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "dolibarr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup enabled validation.
Returns "true" only when backup is enabled and required S3 fields are set.
*/}}
{{- define "dolibarr.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- $hasEndpoint := ne (.Values.backup.s3.endpoint | default "") "" -}}
  {{- $hasBucket := ne (.Values.backup.s3.bucket | default "") "" -}}
  {{- $hasCredentials := or (ne (.Values.backup.s3.existingSecret | default "") "") (and (ne (.Values.backup.s3.accessKey | default "") "") (ne (.Values.backup.s3.secretKey | default "") "")) -}}
  {{- if and $hasEndpoint $hasBucket $hasCredentials -}}
true
  {{- else -}}
    {{- fail "backup.enabled requires backup.s3.endpoint, backup.s3.bucket, and either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
