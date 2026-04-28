{{- define "gophish.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gophish.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "gophish.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "gophish.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gophish.labels" -}}
helm.sh/chart: {{ include "gophish.chart" . }}
{{ include "gophish.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "gophish.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gophish.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "gophish.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "gophish.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "gophish.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "gophish.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "gophish.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "gophish.configSecretName" -}}
{{- if .Values.gophish.config.existingSecret -}}
{{- .Values.gophish.config.existingSecret -}}
{{- else -}}
{{- printf "%s-config" (include "gophish.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "gophish.sqliteDirectory" -}}
{{- dir .Values.database.sqlite.path -}}
{{- end -}}

{{- define "gophish.effectiveDatabaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if eq $mode "auto" -}}
  {{- if or .Values.database.external.existingSecret .Values.database.external.host -}}
external
  {{- else if .Values.mysql.enabled -}}
mysql
  {{- else -}}
sqlite
  {{- end -}}
{{- else -}}
{{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "gophish.databaseName" -}}
{{- $mode := include "gophish.effectiveDatabaseMode" . | trim -}}
{{- if eq $mode "sqlite" -}}
sqlite3
{{- else -}}
mysql
{{- end -}}
{{- end -}}

{{- define "gophish.mysqlServiceName" -}}
{{- if .Values.mysql.fullnameOverride -}}
{{- .Values.mysql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "mysql" .Values.mysql.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "gophish.mysqlSecretName" -}}
{{- if .Values.mysql.auth.existingSecret -}}
{{- .Values.mysql.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "gophish.mysqlServiceName" .) -}}
{{- end -}}
{{- end -}}

{{- define "gophish.databasePath" -}}
{{- $mode := include "gophish.effectiveDatabaseMode" . | trim -}}
{{- if eq $mode "sqlite" -}}
{{- .Values.database.sqlite.path -}}
{{- else if and (eq $mode "external") (not .Values.database.external.existingSecret) -}}
{{- printf "%s:%s@(%s:%v)/%s?%s" .Values.database.external.username .Values.database.external.password .Values.database.external.host .Values.database.external.port .Values.database.external.name .Values.database.external.parameters -}}
{{- else -}}
__GOPHISH_DATABASE_DSN__
{{- end -}}
{{- end -}}

{{- define "gophish.needsRuntimeDsn" -}}
{{- $mode := include "gophish.effectiveDatabaseMode" . | trim -}}
{{- if or (eq $mode "mysql") (and (eq $mode "external") .Values.database.external.existingSecret) -}}true{{- end -}}
{{- end -}}

{{- define "gophish.backupImage" -}}
{{- printf "%s:%s" .Values.backup.images.archive.repository .Values.backup.images.archive.tag -}}
{{- end -}}

{{- define "gophish.backupUploaderImage" -}}
{{- printf "%s:%s" .Values.backup.images.uploader.repository .Values.backup.images.uploader.tag -}}
{{- end -}}

{{- define "gophish.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "gophish.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "gophish.validateAll" -}}
{{- $mode := include "gophish.effectiveDatabaseMode" . | trim -}}
{{- $externalSignal := or .Values.database.external.existingSecret .Values.database.external.host -}}
{{- if and (eq .Values.database.mode "auto") .Values.mysql.enabled $externalSignal -}}
{{- fail "database.mode=auto cannot select safely when both mysql.enabled and database.external.* are set. Choose database.mode=mysql or database.mode=external explicitly." -}}
{{- end -}}
{{- if and (eq $mode "sqlite") (gt (.Values.replicaCount | int) 1) -}}
{{- fail "SQLite mode requires replicaCount=1. Configure database.mode=external or database.mode=mysql for multi-replica experiments after validating shared database behavior, or set replicaCount to 1." -}}
{{- end -}}
{{- if and (eq $mode "sqlite") (not .Values.persistence.enabled) (not .Values.persistence.existingClaim) -}}
{{- fail "SQLite mode requires persistence.enabled=true or persistence.existingClaim to avoid losing Gophish state." -}}
{{- end -}}
{{- if and (eq .Values.database.mode "sqlite") .Values.mysql.enabled -}}
{{- fail "database.mode=sqlite cannot be combined with mysql.enabled=true. Disable mysql.enabled or set database.mode=mysql." -}}
{{- end -}}
{{- if and (eq .Values.database.mode "external") .Values.mysql.enabled -}}
{{- fail "database.mode=external cannot be combined with mysql.enabled=true. Use external database values or embedded MySQL, not both." -}}
{{- end -}}
{{- if and (eq .Values.database.mode "mysql") (or .Values.database.external.host .Values.database.external.existingSecret) -}}
{{- fail "database.mode=mysql cannot be combined with database.external.*. Remove external database values or set database.mode=external." -}}
{{- end -}}
{{- if and (eq $mode "external") (not .Values.database.external.existingSecret) (not .Values.database.external.host) -}}
{{- fail "database.mode=external requires database.external.host or database.external.existingSecret." -}}
{{- end -}}
{{- if and (eq $mode "external") .Values.database.external.host (not .Values.database.external.existingSecret) (not .Values.database.external.password) -}}
{{- fail "database.external.password is required when database.external.host is used without database.external.existingSecret." -}}
{{- end -}}
{{- if and (eq $mode "external") .Values.database.external.password (not .Values.database.external.allowInlinePassword) -}}
{{- fail "Inline external database passwords require database.external.allowInlinePassword=true and are intended only for local tests. Use database.external.existingSecret for production." -}}
{{- end -}}
{{- if and .Values.adminIngress.enabled (not .Values.adminIngress.hosts) -}}
{{- fail "adminIngress.enabled=true requires at least one adminIngress.hosts entry." -}}
{{- end -}}
{{- if and .Values.adminIngress.enabled (not .Values.adminIngress.tls) -}}
{{- fail "adminIngress.enabled=true requires adminIngress.tls because the admin UI is privileged. Use port-forward for private access or configure TLS explicitly." -}}
{{- end -}}
{{- if and .Values.phishIngress.enabled (not .Values.phishIngress.hosts) -}}
{{- fail "phishIngress.enabled=true requires at least one phishIngress.hosts entry." -}}
{{- end -}}
{{- if .Values.backup.enabled -}}
  {{- if ne $mode "sqlite" -}}
  {{- fail "backup.enabled currently supports only SQLite mode. Use the MySQL dependency backup or external database backup tooling for MySQL modes." -}}
  {{- end -}}
  {{- if not .Values.backup.s3.endpoint -}}
  {{- fail "backup.s3.endpoint is required when backup.enabled=true." -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
  {{- fail "backup.s3.bucket is required when backup.enabled=true." -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
  {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey." -}}
  {{- end -}}
{{- end -}}
{{- end -}}
