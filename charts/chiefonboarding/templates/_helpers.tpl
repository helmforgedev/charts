{{- define "chiefonboarding.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "chiefonboarding.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "chiefonboarding.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "chiefonboarding.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "chiefonboarding.labels" -}}
helm.sh/chart: {{ include "chiefonboarding.chart" . }}
{{ include "chiefonboarding.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "chiefonboarding.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chiefonboarding.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "chiefonboarding.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "chiefonboarding.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "chiefonboarding.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Database host */}}
{{- define "chiefonboarding.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{/* Database port */}}
{{- define "chiefonboarding.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- "5432" -}}
{{- else -}}
{{- .Values.database.external.port | default "5432" -}}
{{- end -}}
{{- end -}}

{{/* Database name */}}
{{- define "chiefonboarding.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "chiefonboarding" -}}
{{- else -}}
{{- .Values.database.external.name | default "chiefonboarding" -}}
{{- end -}}
{{- end -}}

{{/* Database username */}}
{{- define "chiefonboarding.dbUsername" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "chiefonboarding" -}}
{{- else -}}
{{- .Values.database.external.username | default "chiefonboarding" -}}
{{- end -}}
{{- end -}}

{{/* Database secret name for password */}}
{{- define "chiefonboarding.dbSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "chiefonboarding.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Database secret password key */}}
{{- define "chiefonboarding.dbSecretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- "user-password" -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{/* DATABASE_URL connection string */}}
{{- define "chiefonboarding.databaseUrl" -}}
{{- printf "postgres://%s:$(DATABASE_PASSWORD)@%s:%s/%s" (include "chiefonboarding.dbUsername" .) (include "chiefonboarding.dbHost" .) (include "chiefonboarding.dbPort" .) (include "chiefonboarding.dbName" .) -}}
{{- end -}}

{{/* App secret name */}}
{{- define "chiefonboarding.appSecretName" -}}
{{- if .Values.chiefonboarding.existingSecret -}}
{{- .Values.chiefonboarding.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "chiefonboarding.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* App secret key */}}
{{- define "chiefonboarding.appSecretKey" -}}
{{- if .Values.chiefonboarding.existingSecret -}}
{{- .Values.chiefonboarding.existingSecretKey | default "secret-key" -}}
{{- else -}}
{{- "secret-key" -}}
{{- end -}}
{{- end -}}
