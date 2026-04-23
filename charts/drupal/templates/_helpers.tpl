{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "drupal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "drupal.fullname" -}}
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
{{- define "drupal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "drupal.labels" -}}
helm.sh/chart: {{ include "drupal.chart" . }}
{{ include "drupal.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: drupal
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "drupal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "drupal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "drupal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "drupal.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image string.
*/}}
{{- define "drupal.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{/*
Database mode detection (auto | external | mysql | sqlite).
Auto precedence:
  1. database.external.host -> external
  2. mysql.enabled -> mysql
  3. sqlite
*/}}
{{- define "drupal.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "mysql" "sqlite")) -}}
{{- fail (printf "database.mode must be one of: auto, external, mysql, sqlite (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := ne (.Values.database.external.host | default "") "" -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasMysql -}}
    {{- fail "drupal database selection is ambiguous: configure only one of database.external.host or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external
  {{- else if $hasMysql -}}mysql
  {{- else -}}sqlite
  {{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}
    {{- fail "database.mode=external requires database.external.host" -}}
  {{- end -}}
  {{- if and (eq $mode "external") $hasMysql -}}
    {{- fail "database.mode=external cannot be combined with mysql.enabled" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}
    {{- fail "database.mode=mysql requires mysql.enabled=true" -}}
  {{- end -}}
  {{- if and (eq $mode "mysql") $hasExternal -}}
    {{- fail "database.mode=mysql cannot be combined with database.external.host" -}}
  {{- end -}}
  {{- if and (eq $mode "sqlite") (or $hasMysql $hasExternal) -}}
    {{- fail "database.mode=sqlite cannot be combined with mysql.enabled or database.external.host" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{/*
Database host string for docs and NOTES.
*/}}
{{- define "drupal.databaseHost" -}}
{{- $mode := include "drupal.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.host -}}
{{- else if eq $mode "mysql" -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- print "sqlite" -}}
{{- end -}}
{{- end -}}

{{/*
Database port string for docs and NOTES.
*/}}
{{- define "drupal.databasePort" -}}
{{- $mode := include "drupal.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.port | default 3306 | toString -}}
{{- else if eq $mode "mysql" -}}
{{- print "3306" -}}
{{- else -}}
{{- print "" -}}
{{- end -}}
{{- end -}}

{{/*
Database name string for docs and NOTES.
*/}}
{{- define "drupal.databaseName" -}}
{{- $mode := include "drupal.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.name -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.database -}}
{{- else -}}
{{- .Values.drupal.sqlitePath -}}
{{- end -}}
{{- end -}}

{{/*
Database username string for docs and NOTES.
*/}}
{{- define "drupal.databaseUsername" -}}
{{- $mode := include "drupal.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.username -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.username -}}
{{- else -}}
{{- print "" -}}
{{- end -}}
{{- end -}}

{{/*
Sites claim name.
*/}}
{{- define "drupal.sitesClaimName" -}}
{{- default (include "drupal.fullname" .) .Values.persistence.existingClaim -}}
{{- end -}}

{{/*
ConfigMap name for php.ini.
*/}}
{{- define "drupal.configMapName" -}}
{{- printf "%s-config" (include "drupal.fullname" .) -}}
{{- end -}}

{{/*
MySQL password secret name for installer guidance.
*/}}
{{- define "drupal.mysqlPasswordSecretName" -}}
{{- if .Values.mysql.auth.existingSecret -}}
{{- .Values.mysql.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-mysql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
MySQL password secret key for installer guidance.
*/}}
{{- define "drupal.mysqlPasswordSecretKey" -}}
{{- if .Values.mysql.auth.existingSecret -}}
{{- .Values.mysql.auth.existingSecretUserPasswordKey | default "mysql-user-password" -}}
{{- else -}}
{{- print "mysql-user-password" -}}
{{- end -}}
{{- end -}}
