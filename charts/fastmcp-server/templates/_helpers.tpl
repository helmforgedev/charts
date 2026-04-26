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

{{/* Validation rules that need Helm context */}}
{{- define "fastmcp-server.validateValues" -}}
{{- $env := lower (toString .Values.server.environment) -}}
{{- if and (has $env (list "prod" "production" "staging")) (eq .Values.auth.type "none") (not .Values.auth.allowNoAuth) -}}
{{- fail "Production-like environments require auth.type other than 'none', or set auth.allowNoAuth=true for an explicit exception." -}}
{{- end -}}
{{- if and (or (eq .Values.auth.type "bearer") (and (eq .Values.auth.type "multi") (has "bearer" .Values.auth.providers))) (not .Values.auth.bearer.token) (not .Values.auth.bearer.existingSecret) -}}
{{- fail "Bearer auth requires auth.bearer.token or auth.bearer.existingSecret." -}}
{{- end -}}
{{- if and .Values.sources.s3.enabled (not .Values.sources.s3.bucket) -}}
{{- fail "S3 source requires sources.s3.bucket when sources.s3.enabled=true." -}}
{{- end -}}
{{- if and .Values.sources.git.enabled (not .Values.sources.git.repository) -}}
{{- fail "Git source requires sources.git.repository when sources.git.enabled=true." -}}
{{- end -}}
{{- if and .Values.sources.oci.enabled (not .Values.sources.oci.registry) -}}
{{- fail "OCI source requires sources.oci.registry when sources.oci.enabled=true." -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}
{{- fail "ServiceMonitor requires metrics.enabled=true." -}}
{{- end -}}
{{- if and .Values.gateway.enabled (not .Values.gateway.rawMountServersJson) (empty .Values.gateway.mountServers) -}}
{{- fail "Gateway mode requires gateway.mountServers or gateway.rawMountServersJson." -}}
{{- end -}}
{{- end -}}

{{/* Auth secret name */}}
{{- define "fastmcp-server.authSecretName" -}}
  {{- if .Values.auth.bearer.existingSecret -}}
    {{- .Values.auth.bearer.existingSecret -}}
  {{- else -}}
    {{- printf "%s-auth" (include "fastmcp-server.fullname" .) -}}
  {{- end -}}
{{- end -}}

{{/* JWT public key secret name */}}
{{- define "fastmcp-server.jwtSecretName" -}}
{{- if .Values.auth.jwt.publicKeyExistingSecret -}}
  {{- .Values.auth.jwt.publicKeyExistingSecret -}}
{{- else -}}
  {{- printf "%s-jwt" (include "fastmcp-server.fullname" .) -}}
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

{{/* OCI secret name */}}
{{- define "fastmcp-server.ociSecretName" -}}
{{- if .Values.sources.oci.existingSecret -}}
  {{- .Values.sources.oci.existingSecret -}}
{{- else -}}
  {{- printf "%s-oci" (include "fastmcp-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* MCP mount servers JSON */}}
{{- define "fastmcp-server.mountServersJson" -}}
{{- if .Values.gateway.rawMountServersJson -}}
{{- .Values.gateway.rawMountServersJson -}}
{{- else -}}
{{- .Values.gateway.mountServers | toJson -}}
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
