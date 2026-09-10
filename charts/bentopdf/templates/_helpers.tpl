{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "bentopdf.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "bentopdf.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "bentopdf.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "bentopdf.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "bentopdf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bentopdf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "bentopdf.labels" -}}
helm.sh/chart: {{ include "bentopdf.chart" . }}
{{ include "bentopdf.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "bentopdf.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "bentopdf.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "bentopdf.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "bentopdf.validate" -}}
{{- if and .Values.autoscaling.enabled (not (dig "requests" "cpu" "" .Values.resources)) -}}{{ fail "autoscaling requires resources.requests.cpu" }}{{- end -}}
{{- if eq (int .Values.metrics.port) 8081 -}}{{ fail "metrics.port 8081 is reserved for loopback stub_status" }}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{ fail "ingress.hosts is required when enabled" }}{{- end -}}
{{- $minimum := int .Values.replicaCount -}}{{- if .Values.autoscaling.enabled -}}{{- $minimum = int .Values.autoscaling.minReplicas -}}{{- end -}}
{{- if and .Values.podDisruptionBudget.enabled (or (lt $minimum 2) (ge (int .Values.podDisruptionBudget.maxUnavailable) $minimum)) -}}{{ fail "podDisruptionBudget requires at least two replicas and maxUnavailable smaller than minimum replicas" }}{{- end -}}
{{- if gt (int .Values.autoscaling.minReplicas) (int .Values.autoscaling.maxReplicas) -}}{{ fail "autoscaling.minReplicas cannot exceed maxReplicas" }}{{- end -}}
{{- if and (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) (not .Values.metrics.enabled) -}}{{ fail "monitoring resources require metrics.enabled=true" }}{{- end -}}
{{- if eq (int .Values.server.port) 8081 -}}{{ fail "server.port 8081 is reserved for loopback stub_status" }}{{- end -}}
{{- if eq (int .Values.server.port) (int .Values.metrics.port) -}}{{ fail "server.port and metrics.port must differ" }}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}

{{- define "bentopdf.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "bentopdf.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "bentopdf.fullname" .root }}{{- end -}}
{{- end -}}
