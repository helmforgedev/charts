{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "metrics-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "metrics-server.fullname" -}}
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

{{- define "metrics-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "metrics-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "metrics-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "metrics-server.labels" -}}
helm.sh/chart: {{ include "metrics-server.chart" . }}
{{ include "metrics-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "metrics-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "metrics-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "metrics-server.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{- define "metrics-server.securePort" -}}
{{- if and .Values.hostNetwork.enabled (eq (.Values.containerPort | int) 10250) -}}
4443
{{- else -}}
{{- .Values.containerPort -}}
{{- end -}}
{{- end }}

{{- define "metrics-server.deploymentStrategy" -}}
{{- $strategy := deepCopy .Values.deploymentStrategy -}}
{{- $rolling := default dict $strategy.rollingUpdate -}}
{{- $usesDefaultRolling := and (eq $strategy.type "RollingUpdate") (eq (toString $rolling.maxUnavailable) "0") (eq (toString $rolling.maxSurge) "1") -}}
{{- if ne $strategy.type "RollingUpdate" }}
{{- toYaml (omit $strategy "rollingUpdate") }}
{{- else if and .Values.hostNetwork.enabled $usesDefaultRolling }}
type: RollingUpdate
rollingUpdate:
  maxUnavailable: 1
  maxSurge: 0
{{- else }}
{{- toYaml $strategy }}
{{- end }}
{{- end }}

{{- define "metrics-server.args" -}}
- --cert-dir={{ .Values.metricsServer.certDir }}
- --secure-port={{ include "metrics-server.securePort" . }}
- --kubelet-preferred-address-types={{ join "," .Values.metricsServer.kubelet.preferredAddressTypes }}
{{- if .Values.metricsServer.kubelet.useNodeStatusPort }}
- --kubelet-use-node-status-port
{{- end }}
{{- if .Values.serviceMonitor.enabled }}
- --authorization-always-allow-paths=/livez,/readyz,/metrics
{{- end }}
- --metric-resolution={{ .Values.metricsServer.metricResolution }}
{{- if .Values.metricsServer.kubelet.insecureTLS }}
- --kubelet-insecure-tls
{{- end }}
{{- with .Values.metricsServer.kubelet.certificateAuthority }}
- --kubelet-certificate-authority={{ . }}
{{- end }}
{{- with .Values.metricsServer.kubelet.requestTimeout }}
- --kubelet-request-timeout={{ . }}
{{- end }}
{{- with .Values.metricsServer.extraArgs }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "metrics-server.validate" -}}
{{- if and .Values.apiService.create (not .Values.rbac.create) -}}
{{- fail "rbac.create must be true when apiService.create=true because Metrics API aggregation requires RBAC delegation" -}}
{{- end -}}
{{- if empty .Values.metricsServer.kubelet.preferredAddressTypes -}}
{{- fail "metricsServer.kubelet.preferredAddressTypes must contain at least one address type" -}}
{{- end -}}
{{- end }}
