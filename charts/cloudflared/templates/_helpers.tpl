{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "cloudflared.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloudflared.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "cloudflared.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "cloudflared.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloudflared.labels" -}}
helm.sh/chart: {{ include "cloudflared.chart" . }}
{{ include "cloudflared.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "cloudflared.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudflared.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "cloudflared.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "cloudflared.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "cloudflared.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "cloudflared.validate" -}}
{{- if and (not .Values.tunnel.quickTunnel.enabled) (not .Values.tunnel.token) (not .Values.tunnel.existingSecret) -}}
{{- fail "tunnel.token or tunnel.existingSecret is required when tunnel.quickTunnel.enabled is false" -}}
{{- end -}}
{{- if and .Values.tunnel.quickTunnel.enabled (not .Values.tunnel.quickTunnel.helloWorld) (not .Values.tunnel.quickTunnel.url) -}}
{{- fail "tunnel.quickTunnel.url is required when tunnel.quickTunnel.enabled=true and helloWorld=false" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.tunnel.existingSecret) -}}
{{- fail "externalSecrets.enabled requires tunnel.existingSecret to be set to prevent credential drift between the chart-managed Secret and the ExternalSecret." -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.data) -}}
{{- fail "externalSecrets.data must not be empty when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.serviceMonitor.enabled (not .Values.metrics.enabled) -}}
{{- fail "metrics.enabled must be true when serviceMonitor.enabled is true" -}}
{{- end -}}
{{- if and .Values.pdb.enabled (lt (int .Values.replicaCount) (int .Values.pdb.minAvailable)) -}}
{{- fail "replicaCount must be greater than or equal to pdb.minAvailable when pdb.enabled is true" -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if or (eq $key "app.kubernetes.io/name") (eq $key "app.kubernetes.io/instance") -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Tunnel token secret name */}}
{{- define "cloudflared.tunnelSecretName" -}}
{{- if .Values.tunnel.existingSecret -}}
{{- .Values.tunnel.existingSecret -}}
{{- else -}}
{{- printf "%s-tunnel" (include "cloudflared.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Tunnel token secret key */}}
{{- define "cloudflared.tunnelSecretKey" -}}
{{- .Values.tunnel.existingSecretKey | default "token" -}}
{{- end -}}
