{{- define "karakeep.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "karakeep.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "karakeep.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "karakeep.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "karakeep.labels" -}}
helm.sh/chart: {{ include "karakeep.chart" . }}
{{ include "karakeep.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "karakeep.selectorLabels" -}}
app.kubernetes.io/name: {{ include "karakeep.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "karakeep.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "karakeep.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "karakeep.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "karakeep.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "karakeep.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Secret name */}}
{{- define "karakeep.secretName" -}}
{{- printf "%s-secret" (include "karakeep.fullname" .) -}}
{{- end -}}

{{/*
Generate NEXTAUTH_SECRET: lookup existing secret or generate a new one.
This ensures the value is preserved across upgrades.
*/}}
{{- define "karakeep.nextAuthSecret" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "karakeep.secretName" .) -}}
{{- if and $existing $existing.data (index $existing.data "nextauth-secret") -}}
{{- index $existing.data "nextauth-secret" | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}

{{/*
Generate MEILI_MASTER_KEY: lookup existing secret or generate a new one.
*/}}
{{- define "karakeep.meiliMasterKey" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "karakeep.secretName" .) -}}
{{- if and $existing $existing.data (index $existing.data "meili-master-key") -}}
{{- index $existing.data "meili-master-key" | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
