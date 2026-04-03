{{- define "alfio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "alfio.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "alfio.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "alfio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "alfio.labels" -}}
helm.sh/chart: {{ include "alfio.chart" . }}
{{ include "alfio.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "alfio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "alfio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "alfio.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "alfio.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "alfio.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Database host */}}
{{- define "alfio.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "alfio.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "alfio.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "alfio" -}}
{{- else -}}
{{- .Values.database.external.name | default "alfio" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "alfio.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "alfio" -}}
{{- else -}}
{{- .Values.database.external.username | default "alfio" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "alfio.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "alfio.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "alfio.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- "user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* JDBC URL connection string */}}
{{- define "alfio.jdbcUrl" -}}
{{- printf "jdbc:postgresql://%s:%s/%s" (include "alfio.dbHost" .) (include "alfio.dbPort" .) (include "alfio.dbName" .) -}}
{{- end -}}
