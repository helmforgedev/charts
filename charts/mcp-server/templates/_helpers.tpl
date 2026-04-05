{{- define "mcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mcp-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "mcp-server.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mcp-server.labels" -}}
helm.sh/chart: {{ include "mcp-server.chart" . }}
{{ include "mcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mcp-server.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Auth secret name */}}
{{- define "mcp-server.authSecretName" -}}
{{- if eq .Values.auth.type "bearer" -}}
  {{- if .Values.auth.bearer.existingSecret -}}
    {{- .Values.auth.bearer.existingSecret -}}
  {{- else -}}
    {{- printf "%s-auth" (include "mcp-server.fullname" .) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* S3 secret name */}}
{{- define "mcp-server.s3SecretName" -}}
{{- if .Values.sources.s3.existingSecret -}}
  {{- .Values.sources.s3.existingSecret -}}
{{- else -}}
  {{- printf "%s-s3" (include "mcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Git secret name */}}
{{- define "mcp-server.gitSecretName" -}}
{{- if .Values.sources.git.existingSecret -}}
  {{- .Values.sources.git.existingSecret -}}
{{- else -}}
  {{- printf "%s-git" (include "mcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* PVC claim name */}}
{{- define "mcp-server.claimName" -}}
{{- if .Values.persistence.existingClaim -}}
  {{- .Values.persistence.existingClaim -}}
{{- else -}}
  {{- printf "%s-workspace" (include "mcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Check if any inline content exists */}}
{{- define "mcp-server.hasInlineTools" -}}
{{- if .Values.sources.inline.tools -}}true{{- end -}}
{{- end -}}

{{- define "mcp-server.hasInlineResources" -}}
{{- if .Values.sources.inline.resources -}}true{{- end -}}
{{- end -}}

{{- define "mcp-server.hasInlinePrompts" -}}
{{- if .Values.sources.inline.prompts -}}true{{- end -}}
{{- end -}}

{{- define "mcp-server.hasInlineKnowledge" -}}
{{- if .Values.sources.inline.knowledge -}}true{{- end -}}
{{- end -}}

{{- define "mcp-server.hasAnyInline" -}}
{{- if or (include "mcp-server.hasInlineTools" .) (include "mcp-server.hasInlineResources" .) (include "mcp-server.hasInlinePrompts" .) (include "mcp-server.hasInlineKnowledge" .) -}}true{{- end -}}
{{- end -}}
