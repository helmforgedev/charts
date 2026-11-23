{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "kubernetes-mcp-server.renderAnnotations" -}}
{{- $common := deepCopy (.root.Values.commonAnnotations | default dict) -}}
{{- $specific := .specific | default dict -}}
{{- $annotations := mergeOverwrite $common $specific -}}
{{- with $annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
{{- define "kubernetes-mcp-server.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "kubernetes-mcp-server.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "kubernetes-mcp-server.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "kubernetes-mcp-server.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "kubernetes-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubernetes-mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "kubernetes-mcp-server.labels" -}}
helm.sh/chart: {{ include "kubernetes-mcp-server.chart" . }}
{{ include "kubernetes-mcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "kubernetes-mcp-server.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "kubernetes-mcp-server.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "kubernetes-mcp-server.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "kubernetes-mcp-server.baseConfigToml" -}}
port = "{{ .Values.app.port }}"
bind_address = "0.0.0.0"
log_level = {{ .Values.mcp.logLevel | default 0 }}
list_output = "{{ .Values.mcp.listOutput | default "table" }}"
stateless = {{ .Values.mcp.stateless | default false }}
read_only = {{ .Values.mcp.readOnly | default false }}
disable_destructive = {{ .Values.mcp.disableDestructive | default false }}
{{- with .Values.mcp.clusterProvider }}
cluster_provider_strategy = "{{ . }}"
{{- end }}
{{- if .Values.mcp.toolsets }}
toolsets = [
{{- range $i, $t := .Values.mcp.toolsets }}
  {{- if $i }}, {{ end }}"{{ $t }}"
{{- end }}
]
{{- end }}
{{- end -}}

{{- define "kubernetes-mcp-server.validate" -}}
{{- if and (not .Values.mcp.readOnly) (not .Values.mcp.disableDestructive) (not .Values.mcp.allowUnsafeWriteAccess) -}}
{{- fail "write access with destructive tools requires mcp.allowUnsafeWriteAccess=true" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.persistence.enabled (not .Values.persistence.existingClaim) (not (has "ReadWriteMany" .Values.persistence.accessModes)) -}}
{{- fail "replicaCount > 1 with persistence.enabled requires persistence.accessModes to include ReadWriteMany or persistence.enabled=false" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- if hasKey $podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey $podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
