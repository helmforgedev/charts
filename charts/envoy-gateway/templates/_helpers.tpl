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
{{- else if eq $profile "production-ha" }}
{{- 2 }}
{{- else }}
{{- .Values.controller.replicaCount | default 1 }}
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
Controller image
*/}}
{{- define "envoy-gateway.controller.image" -}}
{{- printf "%s:%s" .Values.controller.image.repository (.Values.controller.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Gateway API examples namespace
*/}}
{{- define "envoy-gateway.examples.namespace" -}}
{{- .Values.gatewayAPI.examples.namespace | default .Release.Namespace }}
{{- end }}

{{/*
Gateway name - returns gateway.name or release name
*/}}
{{- define "envoy-gateway.gateway.name" -}}
{{- .Values.gateway.name | default .Release.Name }}
{{- end }}

{{/*
SecurityPolicy target name - returns targetName or gateway name
*/}}
{{- define "envoy-gateway.securityPolicy.targetName" -}}
{{- .Values.securityPolicy.targetName | default (include "envoy-gateway.gateway.name" .) }}
{{- end }}

{{/*
Rate limit Redis URL — returns subchart or external Redis URL.
Subchart (redis.enabled=true): redis service is named "<release>-redis" by the helmforge/redis chart.
External (rateLimiting.externalRedis.host set): use the provided host/port.
*/}}
{{- define "envoy-gateway.ratelimit.redisUrl" -}}
{{- if .Values.redis.enabled }}
{{- printf "redis://%s-redis.%s.svc.cluster.local:6379" .Release.Name .Release.Namespace }}
{{- else if .Values.rateLimiting.externalRedis.host }}
{{- printf "redis://%s:%d" .Values.rateLimiting.externalRedis.host (.Values.rateLimiting.externalRedis.port | int) }}
{{- end }}
{{- end }}

{{/*
Proxy pod spec fragment (nodeSelector, tolerations, affinity) for EnvoyProxy CRD
*/}}
{{- define "envoy-gateway.proxy.podSpec" -}}
{{- if .Values.proxy.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.proxy.nodeSelector | nindent 2 }}
{{- end }}
{{- if .Values.proxy.tolerations }}
tolerations:
  {{- toYaml .Values.proxy.tolerations | nindent 2 }}
{{- end }}
{{- $affinity := .Values.proxy.affinity }}
{{- if $affinity }}
affinity:
  {{- toYaml $affinity | nindent 2 }}
{{- end }}
{{- end }}
