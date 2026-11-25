{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "grafana.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "grafana.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "grafana.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "grafana.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "grafana.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grafana.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "grafana.labels" -}}
helm.sh/chart: {{ include "grafana.chart" . }}
{{ include "grafana.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "grafana.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "grafana.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "grafana.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "grafana.adminSecretName" -}}{{- default (printf "%s-admin" (include "grafana.fullname" .)) .Values.admin.existingSecret -}}{{- end -}}
{{- define "grafana.databaseSecretName" -}}{{- default (printf "%s-database" (include "grafana.fullname" .)) .Values.database.existingSecret -}}{{- end -}}
{{- define "grafana.claimName" -}}{{- default (include "grafana.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "grafana.databasePort" -}}{{- if gt (int .Values.database.port) 0 -}}{{ .Values.database.port }}{{- else if eq .Values.database.type "postgres" -}}5432{{- else if eq .Values.database.type "mysql" -}}3306{{- else -}}0{{- end -}}{{- end -}}
{{- define "grafana.databaseHost" -}}{{- if eq .Values.database.type "sqlite3" -}}{{ "" }}{{- else -}}{{ printf "%s:%s" .Values.database.host (include "grafana.databasePort" .) }}{{- end -}}{{- end -}}
{{- define "grafana.httpRouteName" -}}{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "grafana.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "grafana.fullname" .root }}{{- end -}}{{- end -}}
{{- define "grafana.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "grafana.fullname" .root | trunc 45 | trimSuffix "-") (.item.name | default "credentials") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}

{{- define "grafana.renderAnnotations" -}}
{{- $root := .root -}}
{{- $specific := .specific | default dict -}}
{{- $merged := merge (deepCopy $specific) (deepCopy ($root.Values.commonAnnotations | default dict)) -}}
{{- with $merged }}
annotations:
{{ toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "grafana.validate" -}}
{{- range $key, $_ := .Values.podLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail "podLabels cannot override workload selector labels" }}{{- end -}}{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (eq .Values.database.type "sqlite3") -}}{{ fail "replicaCount greater than one requires database.type postgres or mysql; SQLite is not an HA database" }}{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.persistence.enabled (or (has "ReadWriteOnce" .Values.persistence.accessModes) (has "ReadWriteOncePod" .Values.persistence.accessModes)) -}}{{ fail "multiple replicas cannot share a ReadWriteOnce or ReadWriteOncePod data volume; disable persistence for externally stored HA metadata or use a shared ReadWriteMany volume" }}{{- end -}}
{{- if and (ne .Values.database.type "sqlite3") (not .Values.database.host) -}}{{ fail "database.host is required when database.type is postgres or mysql" }}{{- end -}}
{{- if and (ne .Values.database.type "sqlite3") (not (or .Values.database.password .Values.database.existingSecret)) -}}{{ fail "database.password or database.existingSecret is required for an external database" }}{{- end -}}
{{- if and .Values.database.password .Values.database.existingSecret -}}{{ fail "database.password and database.existingSecret are mutually exclusive" }}{{- end -}}
{{- if and .Values.admin.password .Values.admin.existingSecret -}}{{ fail "admin.password and admin.existingSecret are mutually exclusive" }}{{- end -}}
{{- if and .Values.pdb.enabled (le (int .Values.replicaCount) 1) -}}{{ fail "pdb.enabled requires replicaCount greater than one" }}{{- end -}}
{{- if and (ne (toString .Values.pdb.minAvailable) "") (ne (toString .Values.pdb.maxUnavailable) "") -}}{{ fail "set only one of pdb.minAvailable or pdb.maxUnavailable" }}{{- end -}}
{{- range .Values.grafana.extraEnv -}}{{- if regexMatch "^GF_(PATHS_|SERVER_HTTP_PORT$|SERVER_ROOT_URL$|SERVER_SERVE_FROM_SUB_PATH$|DATABASE_|SECURITY_ADMIN_|PLUGINS_PREINSTALL(_SYNC)?$)" .name -}}{{ fail (printf "grafana.extraEnv cannot override chart-managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- range .Values.plugins.preinstall -}}{{- if not (regexMatch "^[A-Za-z0-9._-]+@[A-Za-z0-9._+-]+$" .) -}}{{ fail (printf "plugins.preinstall entry %q must pin a version as plugin-id@version" .) }}{{- end -}}{{- end -}}
{{- range $name, $_ := .Values.provisioning.alerting -}}{{- if has $name (list "datasources" "dashboards") -}}{{ fail (printf "provisioning.alerting key %q is reserved by Grafana provisioning" $name) }}{{- end -}}{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must not be empty when externalSecrets.enabled is true" }}{{- end -}}
{{- end -}}

{{- define "grafana.ini" -}}
[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[server]
http_port = {{ .Values.grafana.port }}
{{- with .Values.grafana.rootUrl }}
root_url = {{ . }}
{{- end }}
serve_from_sub_path = {{ .Values.grafana.serveFromSubPath }}

[log]
level = {{ .Values.grafana.logLevel }}
mode = console

[analytics]
check_for_updates = false
check_for_plugin_updates = false
reporting_enabled = false

[plugins]
preinstall_auto_update = false

[security]
x_xss_protection = false
{{- range $section, $settings := .Values.grafana.ini }}

[{{ $section }}]
{{- range $key, $value := $settings }}
{{ $key }} = {{ $value }}
{{- end }}
{{- end }}
{{- end -}}
