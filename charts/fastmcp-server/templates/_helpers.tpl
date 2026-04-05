{{- define "fastmcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fastmcp-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "fastmcp-server.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "fastmcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fastmcp-server.labels" -}}
helm.sh/chart: {{ include "fastmcp-server.chart" . }}
{{ include "fastmcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "fastmcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fastmcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "fastmcp-server.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Auth secret name */}}
{{- define "fastmcp-server.authSecretName" -}}
{{- if eq .Values.auth.type "bearer" -}}
  {{- if .Values.auth.bearer.existingSecret -}}
    {{- .Values.auth.bearer.existingSecret -}}
  {{- else -}}
    {{- printf "%s-auth" (include "fastmcp-server.fullname" .) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* S3 secret name */}}
{{- define "fastmcp-server.s3SecretName" -}}
{{- if .Values.sources.s3.existingSecret -}}
  {{- .Values.sources.s3.existingSecret -}}
{{- else -}}
  {{- printf "%s-s3" (include "fastmcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Git secret name */}}
{{- define "fastmcp-server.gitSecretName" -}}
{{- if .Values.sources.git.existingSecret -}}
  {{- .Values.sources.git.existingSecret -}}
{{- else -}}
  {{- printf "%s-git" (include "fastmcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* PVC claim name */}}
{{- define "fastmcp-server.claimName" -}}
{{- if .Values.persistence.existingClaim -}}
  {{- .Values.persistence.existingClaim -}}
{{- else -}}
  {{- printf "%s-workspace" (include "fastmcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Check if any inline content exists */}}
{{- define "fastmcp-server.hasInlineTools" -}}
{{- if .Values.sources.inline.tools -}}true{{- end -}}
{{- end -}}

{{- define "fastmcp-server.hasInlineResources" -}}
{{- if .Values.sources.inline.resources -}}true{{- end -}}
{{- end -}}

{{- define "fastmcp-server.hasInlinePrompts" -}}
{{- if .Values.sources.inline.prompts -}}true{{- end -}}
{{- end -}}

{{- define "fastmcp-server.hasInlineKnowledge" -}}
{{- if .Values.sources.inline.knowledge -}}true{{- end -}}
{{- end -}}

{{- define "fastmcp-server.hasAnyInline" -}}
{{- if or (include "fastmcp-server.hasInlineTools" .) (include "fastmcp-server.hasInlineResources" .) (include "fastmcp-server.hasInlinePrompts" .) (include "fastmcp-server.hasInlineKnowledge" .) -}}true{{- end -}}
{{- end -}}
