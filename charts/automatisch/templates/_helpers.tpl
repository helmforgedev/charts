{{- define "automatisch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "automatisch.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "automatisch.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "automatisch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "automatisch.labels" -}}
helm.sh/chart: {{ include "automatisch.chart" . }}
{{ include "automatisch.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "automatisch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "automatisch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "automatisch.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "automatisch.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "automatisch.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* ======================================================================= */}}
{{/* Database helpers                                                         */}}
{{/* ======================================================================= */}}

{{/* Database host */}}
{{- define "automatisch.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "automatisch.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "automatisch.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "automatisch" -}}
{{- else -}}
{{- .Values.database.external.name | default "automatisch" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "automatisch.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "automatisch" -}}
{{- else -}}
{{- .Values.database.external.username | default "automatisch" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "automatisch.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "automatisch.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "automatisch.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- "user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* ======================================================================= */}}
{{/* Redis helpers                                                            */}}
{{/* ======================================================================= */}}

{{/* Redis host */}}
{{- define "automatisch.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis-master" .Release.Name -}}
{{- else -}}
{{- .Values.redis_config.external.host -}}
{{- end -}}
{{- end -}}

{{/* Redis port */}}
{{- define "automatisch.redisPort" -}}
{{- if .Values.redis.enabled -}}
{{- "6379" -}}
{{- else -}}
{{- .Values.redis_config.external.port | default "6379" -}}
{{- end -}}
{{- end -}}

{{/* ======================================================================= */}}
{{/* App secret helpers                                                       */}}
{{/* ======================================================================= */}}

{{/* App secret name */}}
{{- define "automatisch.appSecretName" -}}
{{- printf "%s-app" (include "automatisch.fullname" .) -}}
{{- end -}}
