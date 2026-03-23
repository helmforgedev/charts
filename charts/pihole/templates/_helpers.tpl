{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "pihole.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "pihole.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "pihole.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "pihole.labels" -}}
helm.sh/chart: {{ include "pihole.chart" . }}
{{ include "pihole.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: pihole
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "pihole.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pihole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "pihole.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pihole.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Secret name for admin password.
*/}}
{{- define "pihole.secretName" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecret }}
{{- else }}
{{- include "pihole.fullname" . }}
{{- end }}
{{- end }}

{{/*
Secret key for admin password.
*/}}
{{- define "pihole.secretKey" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecretKey }}
{{- else }}
{{- print "password" }}
{{- end }}
{{- end }}

{{/*
Image string with tag fallback to appVersion.
*/}}
{{- define "pihole.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Upstream DNS value. When unbound is enabled, override to local sidecar.
*/}}
{{- define "pihole.upstreamDns" -}}
{{- if .Values.unbound.enabled }}
{{- printf "127.0.0.1#%d" (int .Values.unbound.port) }}
{{- else }}
{{- .Values.pihole.upstreamDns }}
{{- end }}
{{- end }}

{{/*
ConfigMap name for custom DNS and dnsmasq config.
*/}}
{{- define "pihole.configMapName" -}}
{{- printf "%s-config" (include "pihole.fullname" .) }}
{{- end }}
