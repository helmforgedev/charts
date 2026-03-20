{{- define "vaultwarden.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vaultwarden.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "vaultwarden.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vaultwarden.labels" -}}
helm.sh/chart: {{ include "vaultwarden.chart" . }}
{{ include "vaultwarden.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "vaultwarden.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vaultwarden.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "vaultwarden.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.smtpSecretName" -}}
{{- if .Values.smtp.existingSecret -}}
{{- .Values.smtp.existingSecret -}}
{{- else -}}
{{- printf "%s-smtp" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.adminEnabled" -}}
{{- if or .Values.admin.token .Values.admin.existingSecret -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.smtpPasswordEnabled" -}}
{{- if and .Values.smtp.enabled (or .Values.smtp.password .Values.smtp.existingSecret) -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.persistenceEnabled" -}}
{{- if .Values.data.persistence.enabled -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.persistenceClaimName" -}}
{{- if .Values.data.persistence.existingClaim -}}
{{- .Values.data.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.adminToken" -}}
{{- if .Values.admin.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- .Values.admin.token -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.smtpPassword" -}}
{{- if .Values.smtp.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- .Values.smtp.password -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseSecretName" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-database" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databasePasswordEnabled" -}}
{{- if and (eq (include "vaultwarden.databaseMode" .) "external") (or .Values.database.external.password .Values.database.external.existingSecret) -}}true{{- end -}}
{{- end -}}

{{- define "vaultwarden.databasePassword" -}}
{{- if .Values.database.external.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- .Values.database.external.password -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "sqlite" "external" "postgresql" "mysql")) -}}
{{- fail (printf "database.mode must be one of: auto, sqlite, external, postgresql, mysql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- $count := 0 -}}
  {{- if $hasExternal -}}{{- $count = add1 $count -}}{{- end -}}
  {{- if $hasPostgresql -}}{{- $count = add1 $count -}}{{- end -}}
  {{- if $hasMysql -}}{{- $count = add1 $count -}}{{- end -}}
  {{- if gt $count 1 -}}
    {{- fail "vaultwarden database selection is ambiguous: configure only one of database.external.host, postgresql.enabled, or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasPostgresql -}}postgresql
  {{- else if $hasMysql -}}mysql
  {{- else -}}sqlite
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}
  {{- end -}}
  {{- if and (eq $mode "postgresql") (not $hasPostgresql) -}}
    {{- fail "database.mode=postgresql requires postgresql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}
    {{- fail "database.mode=mysql requires mysql.enabled=true" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseVendor" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.vendor | default "postgres" -}}
{{- else if eq $mode "postgresql" -}}
postgres
{{- else if eq $mode "mysql" -}}
mysql
{{- else -}}
sqlite
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseHost" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.host -}}
{{- else if eq $mode "postgresql" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if eq $mode "mysql" -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databasePort" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- if .Values.database.external.port -}}
{{- .Values.database.external.port | toString -}}
{{- else if eq (.Values.database.external.vendor | default "postgres") "mysql" -}}
3306
{{- else -}}
5432
{{- end -}}
{{- else if eq $mode "postgresql" -}}
5432
{{- else if eq $mode "mysql" -}}
3306
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseName" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.name -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.database -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.database -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseUsername" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.username -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.username -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.username -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databasePasswordSecretName" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- include "vaultwarden.databaseSecretName" . -}}
{{- else -}}
{{- printf "%s-database" (include "vaultwarden.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databasePasswordSecretKey" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretUrlKey -}}
{{- else -}}
database-url
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databasePasswordValue" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.password -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.password -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.password -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseQuery" -}}
{{- if and (eq (include "vaultwarden.databaseMode" .) "external") .Values.database.external.parameters -}}
?{{ .Values.database.external.parameters }}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.databaseUrl" -}}
{{- $mode := include "vaultwarden.databaseMode" . -}}
{{- $vendor := include "vaultwarden.databaseVendor" . -}}
{{- if eq $mode "sqlite" -}}
/data/db.sqlite3
{{- else -}}
  {{- $username := include "vaultwarden.databaseUsername" . -}}
  {{- $password := include "vaultwarden.databasePasswordValue" . -}}
  {{- $host := include "vaultwarden.databaseHost" . -}}
  {{- $port := include "vaultwarden.databasePort" . -}}
  {{- $name := include "vaultwarden.databaseName" . -}}
  {{- if not $password -}}
    {{- fail (printf "vaultwarden database mode %s requires an application password value to build DATABASE_URL" $mode) -}}
  {{- end -}}
  {{- if eq $vendor "mysql" -}}
{{ printf "mysql://%s:%s@%s:%s/%s%s" ($username | urlquery) ($password | urlquery) $host $port $name (include "vaultwarden.databaseQuery" .) }}
  {{- else -}}
{{ printf "postgresql://%s:%s@%s:%s/%s%s" ($username | urlquery) ($password | urlquery) $host $port $name (include "vaultwarden.databaseQuery" .) }}
  {{- end -}}
{{- end -}}
{{- end -}}
