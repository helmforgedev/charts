{{- define "middleware.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "middleware.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "middleware.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "middleware.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "middleware.labels" -}}
helm.sh/chart: {{ include "middleware.chart" . }}
{{ include "middleware.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "middleware.selectorLabels" -}}
app.kubernetes.io/name: {{ include "middleware.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "middleware.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "middleware.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "middleware.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* PostgreSQL host */}}
{{- define "middleware.dbHost" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL port */}}
{{- define "middleware.dbPort" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.port | toString -}}
{{- else -}}
{{- "5432" -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL database name */}}
{{- define "middleware.dbName" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL user */}}
{{- define "middleware.dbUser" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.user -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL secret name */}}
{{- define "middleware.dbSecretName" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL secret password key */}}
{{- define "middleware.dbSecretPasswordKey" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.existingSecretPasswordKey | default "user-password" -}}
{{- else -}}
{{- "user-password" -}}
{{- end -}}
{{- end -}}

{{/* Redis host */}}
{{- define "middleware.redisHost" -}}
{{- if .Values.externalRedis.enabled -}}
{{- .Values.externalRedis.host -}}
{{- else -}}
{{- printf "%s-redis" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Redis port */}}
{{- define "middleware.redisPort" -}}
{{- if .Values.externalRedis.enabled -}}
{{- .Values.externalRedis.port | toString -}}
{{- else -}}
{{- "6379" -}}
{{- end -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "middleware.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "middleware.fullname" .) -}}
{{- end -}}
{{- end -}}
