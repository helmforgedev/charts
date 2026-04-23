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
Desired replica count before validations.
*/}}
{{- define "drupal.desiredReplicasRaw" -}}
{{- if .Values.autoscaling.enabled -}}
{{- .Values.autoscaling.minReplicas | int -}}
{{- else -}}
{{- .Values.replicaCount | int -}}
{{- end -}}
{{- end -}}

{{/*
Validated desired replica count.
*/}}
{{- define "drupal.replicaCount" -}}
{{- $replicas := (include "drupal.desiredReplicasRaw" . | int) -}}
{{- $dbMode := include "drupal.databaseMode" . -}}
{{- if and (eq $dbMode "sqlite") (not (hasPrefix "sites/" .Values.drupal.sqlitePath)) -}}
{{- fail "database.mode=sqlite requires drupal.sqlitePath to stay under sites/ so persistence and backup cover the database file" -}}
{{- end -}}
{{- if gt $replicas 1 -}}
  {{- if eq $dbMode "sqlite" -}}
    {{- fail "Multi-replica Drupal requires a MySQL-compatible database. SQLite is supported only for single-replica deployments." -}}
  {{- end -}}
  {{- if not .Values.persistence.enabled -}}
    {{- fail "Multi-replica Drupal requires persistence.enabled=true so uploaded files and installer state are shared across replicas." -}}
  {{- end -}}
  {{- if ne (.Values.persistence.accessMode | default "ReadWriteOnce") "ReadWriteMany" -}}
    {{- fail "Multi-replica Drupal requires persistence.accessMode=ReadWriteMany so /var/www/html/sites can be shared safely." -}}
  {{- end -}}
{{- end -}}
{{- $replicas -}}
{{- end -}}

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

{{/*
Whether backup is enabled, with validation.
*/}}
{{- define "drupal.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.persistence.enabled -}}
    {{- fail "backup.enabled requires persistence.enabled=true so Drupal sites files are included in each backup." -}}
  {{- end -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
  {{- $dbMode := include "drupal.databaseMode" . -}}
  {{- if and (eq $dbMode "sqlite") (not (hasPrefix "sites/" .Values.drupal.sqlitePath)) -}}
    {{- fail "backup.enabled with database.mode=sqlite requires drupal.sqlitePath to stay under sites/" -}}
  {{- end -}}
  {{- if and (ne $dbMode "sqlite") (eq (.Values.backup.database.existingSecret | default "") "") (eq (.Values.backup.database.password | default "") "") (eq $dbMode "external") -}}
    {{- fail "backup.enabled with database.mode=external requires backup.database.existingSecret or backup.database.password so mysqldump can authenticate." -}}
  {{- end -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Whether autoscaling is enabled, with validation.
*/}}
{{- define "drupal.autoscalingEnabled" -}}
{{- if .Values.autoscaling.enabled -}}
  {{- if lt (.Values.autoscaling.maxReplicas | int) (.Values.autoscaling.minReplicas | int) -}}
    {{- fail "autoscaling.maxReplicas must be greater than or equal to autoscaling.minReplicas" -}}
  {{- end -}}
  {{- if not (or .Values.autoscaling.targetCPUUtilizationPercentage .Values.autoscaling.targetMemoryUtilizationPercentage) -}}
    {{- fail "autoscaling.enabled requires at least one target metric" -}}
  {{- end -}}
  {{- $_ := include "drupal.replicaCount" . -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Backup S3 secret name.
*/}}
{{- define "drupal.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "drupal.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret name.
*/}}
{{- define "drupal.backupDatabasePasswordSecretName" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecret -}}
{{- else if .Values.backup.database.password -}}
{{- printf "%s-backup-db" (include "drupal.fullname" .) -}}
{{- else -}}
{{- include "drupal.mysqlPasswordSecretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database password secret key.
*/}}
{{- define "drupal.backupDatabasePasswordSecretKey" -}}
{{- if .Values.backup.database.existingSecret -}}
{{- .Values.backup.database.existingSecretPasswordKey | default "database-password" -}}
{{- else if .Values.backup.database.password -}}
database-password
{{- else -}}
{{- include "drupal.mysqlPasswordSecretKey" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database host.
*/}}
{{- define "drupal.backupDatabaseHost" -}}
{{- if .Values.backup.database.host -}}
{{- .Values.backup.database.host -}}
{{- else -}}
{{- include "drupal.databaseHost" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database port.
*/}}
{{- define "drupal.backupDatabasePort" -}}
{{- if .Values.backup.database.port -}}
{{- .Values.backup.database.port | toString -}}
{{- else -}}
{{- include "drupal.databasePort" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database name.
*/}}
{{- define "drupal.backupDatabaseName" -}}
{{- if .Values.backup.database.name -}}
{{- .Values.backup.database.name -}}
{{- else -}}
{{- include "drupal.databaseName" . -}}
{{- end -}}
{{- end -}}

{{/*
Backup database username.
*/}}
{{- define "drupal.backupDatabaseUsername" -}}
{{- if .Values.backup.database.username -}}
{{- .Values.backup.database.username -}}
{{- else -}}
{{- include "drupal.databaseUsername" . -}}
{{- end -}}
{{- end -}}
