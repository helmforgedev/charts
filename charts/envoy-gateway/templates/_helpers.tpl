{{/*
Expand the name of the chart.
*/}}
{{- define "envoy-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "envoy-gateway.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "envoy-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "envoy-gateway.labels" -}}
helm.sh/chart: {{ include "envoy-gateway.chart" . }}
{{ include "envoy-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "envoy-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "envoy-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Controller labels
*/}}
{{- define "envoy-gateway.controller.labels" -}}
{{ include "envoy-gateway.labels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Controller selector labels
*/}}
{{- define "envoy-gateway.controller.selectorLabels" -}}
{{ include "envoy-gateway.selectorLabels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Proxy labels
*/}}
{{- define "envoy-gateway.proxy.labels" -}}
{{ include "envoy-gateway.labels" . }}
app.kubernetes.io/component: proxy
{{- end }}

{{/*
Proxy selector labels
*/}}
{{- define "envoy-gateway.proxy.selectorLabels" -}}
{{ include "envoy-gateway.selectorLabels" . }}
app.kubernetes.io/component: proxy
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "envoy-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "envoy-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - controller replica count
*/}}
{{- define "envoy-gateway.controller.replicaCount" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "dev" }}
{{- 1 }}
{{- else if eq $profile "staging" }}
{{- 2 }}
{{- else if eq $profile "production-ha" }}
{{- 2 }}
{{- else }}
{{- .Values.controller.replicaCount | default 1 }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - proxy mode (Deployment or DaemonSet)
*/}}
{{- define "envoy-gateway.proxy.mode" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "production-ha" }}
{{- "DaemonSet" }}
{{- else }}
{{- .Values.proxy.mode | default "Deployment" }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - proxy replica count (only for Deployment mode)
*/}}
{{- define "envoy-gateway.proxy.replicaCount" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- $mode := include "envoy-gateway.proxy.mode" . }}
{{- if eq $mode "DaemonSet" }}
{{- 0 }}
{{- else if eq $profile "dev" }}
{{- 1 }}
{{- else if eq $profile "staging" }}
{{- 2 }}
{{- else }}
{{- .Values.proxy.replicaCount | default 1 }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - controller resources
*/}}
{{- define "envoy-gateway.controller.resources" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "dev" }}
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 500m
  memory: 512Mi
{{- else if eq $profile "staging" }}
requests:
  cpu: 500m
  memory: 512Mi
limits:
  cpu: 1000m
  memory: 1Gi
{{- else if eq $profile "production-ha" }}
requests:
  cpu: 1000m
  memory: 1Gi
limits:
  cpu: 2000m
  memory: 2Gi
{{- else }}
{{- toYaml .Values.controller.resources }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - proxy resources
*/}}
{{- define "envoy-gateway.proxy.resources" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "dev" }}
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 1000m
  memory: 1Gi
{{- else if eq $profile "staging" }}
requests:
  cpu: 500m
  memory: 512Mi
limits:
  cpu: 2000m
  memory: 2Gi
{{- else if eq $profile "production-ha" }}
requests:
  cpu: 1000m
  memory: 1Gi
limits:
  cpu: 4000m
  memory: 4Gi
{{- else }}
{{- toYaml .Values.proxy.resources }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - cert-manager enabled
*/}}
{{- define "envoy-gateway.certManager.enabled" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "production-ha" }}
{{- true }}
{{- else if eq $profile "staging" }}
{{- true }}
{{- else }}
{{- .Values.certificates.certManager.enabled | default false }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - high availability enabled
*/}}
{{- define "envoy-gateway.ha.enabled" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "production-ha" }}
{{- true }}
{{- else }}
{{- .Values.highAvailability.enabled | default false }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - anti-affinity for controller
*/}}
{{- define "envoy-gateway.controller.affinity" -}}
{{- $haEnabled := include "envoy-gateway.ha.enabled" . | trim }}
{{- if eq $haEnabled "true" }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          {{- include "envoy-gateway.controller.selectorLabels" . | nindent 10 }}
      topologyKey: kubernetes.io/hostname
{{- else if .Values.controller.affinity }}
{{- toYaml .Values.controller.affinity }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - anti-affinity for proxy
*/}}
{{- define "envoy-gateway.proxy.affinity" -}}
{{- $haEnabled := include "envoy-gateway.ha.enabled" . | trim }}
{{- $mode := include "envoy-gateway.proxy.mode" . }}
{{- if and (eq $haEnabled "true") (eq $mode "Deployment") }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          {{- include "envoy-gateway.proxy.selectorLabels" . | nindent 10 }}
      topologyKey: kubernetes.io/hostname
{{- else if .Values.proxy.affinity }}
{{- toYaml .Values.proxy.affinity }}
{{- end }}
{{- end }}

{{/*
Controller image
*/}}
{{- define "envoy-gateway.controller.image" -}}
{{- printf "%s:%s" .Values.controller.image.repository (.Values.controller.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Proxy image
*/}}
{{- define "envoy-gateway.proxy.image" -}}
{{- printf "%s:%s" .Values.proxy.image.repository .Values.proxy.image.tag }}
{{- end }}

{{/*
Gateway API examples namespace
*/}}
{{- define "envoy-gateway.examples.namespace" -}}
{{- .Values.gatewayAPI.examples.namespace | default .Release.Namespace }}
{{- end }}
