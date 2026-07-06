{{/* SPDX-License-Identifier: Apache-2.0 */}}
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

{{- define "fastmcp-server.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
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

{{- define "fastmcp-server.validate" -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.parentRefs) -}}
{{- fail "gatewayAPI.parentRefs must contain at least one parentRef when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if .Values.gatewayAPI.enabled -}}
{{- range .Values.gatewayAPI.parentRefs }}
{{- if empty .name -}}
{{- fail "Each gatewayAPI.parentRefs entry must define a name" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and (eq .Values.auth.type "bearer") (not .Values.auth.bearer.token) (not .Values.auth.bearer.existingSecret) -}}
{{- fail "auth.type=bearer requires auth.bearer.token or auth.bearer.existingSecret" -}}
{{- end -}}
{{- if eq .Values.auth.type "jwt" -}}
{{- if or (empty .Values.auth.jwt.issuer) (empty .Values.auth.jwt.audience) (empty .Values.auth.jwt.jwksUri) -}}
{{- fail "auth.type=jwt requires auth.jwt.issuer, auth.jwt.audience, and auth.jwt.jwksUri" -}}
{{- end -}}
{{- end -}}
{{- if .Values.sources.s3.enabled -}}
{{- if empty .Values.sources.s3.bucket -}}
{{- fail "sources.s3.enabled requires sources.s3.bucket" -}}
{{- end -}}
{{- if and (empty .Values.sources.s3.existingSecret) (or (empty .Values.sources.s3.accessKey) (empty .Values.sources.s3.secretKey)) -}}
{{- fail "sources.s3.enabled requires sources.s3.existingSecret or both sources.s3.accessKey and sources.s3.secretKey" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.sources.git.enabled (empty .Values.sources.git.repository) -}}
{{- fail "sources.git.enabled requires sources.git.repository" -}}
{{- end -}}
{{- if .Values.autoscaling.enabled -}}
{{- if lt (int .Values.autoscaling.maxReplicas) (int .Values.autoscaling.minReplicas) -}}
{{- fail "autoscaling.maxReplicas must be greater than or equal to autoscaling.minReplicas" -}}
{{- end -}}
{{- if and (empty .Values.autoscaling.targetCPUUtilizationPercentage) (empty .Values.autoscaling.targetMemoryUtilizationPercentage) -}}
{{- fail "autoscaling.enabled requires at least one target metric" -}}
{{- end -}}
{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
{{- end -}}
