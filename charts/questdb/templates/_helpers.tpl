{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "questdb.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "questdb.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "questdb.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "questdb.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "questdb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "questdb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "questdb.labels" -}}
helm.sh/chart: {{ include "questdb.chart" . }}
{{ include "questdb.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "questdb.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "questdb.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "questdb.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "questdb.authSecretName" -}}{{- default (include "questdb.fullname" .) .Values.questdb.existingSecret -}}{{- end -}}
{{- define "questdb.externalSecretName" -}}{{- $root := .root -}}{{- $item := .item -}}{{- $index := .index -}}{{- coalesce $item.fullnameOverride $item.name (printf "%s-%d" (include "questdb.fullname" $root) $index) | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "questdb.validate" -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.ingressClassName) -}}{{- fail "ingress.enabled requires ingress.ingressClassName" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{- fail "ingress.enabled requires at least one ingress.hosts entry" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.tls) -}}{{- fail "ingress.enabled requires TLS configuration" -}}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}{{- fail "gatewayAPI.enabled requires at least one gatewayAPI.httpRoutes entry" -}}{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}{{- fail "metrics.serviceMonitor.enabled requires metrics.enabled" -}}{{- end -}}
{{- if and .Values.networkPolicy.enabled .Values.metrics.serviceMonitor.enabled (empty .Values.networkPolicy.metricsFrom) -}}{{- fail "metrics.serviceMonitor.enabled with networkPolicy.enabled requires networkPolicy.metricsFrom for the Prometheus namespace" -}}{{- end -}}
{{- if and .Values.persistence.existingClaim (not .Values.persistence.enabled) -}}{{- fail "persistence.existingClaim requires persistence.enabled" -}}{{- end -}}
{{- if not .Values.questdb.pgUser -}}{{- fail "questdb.pgUser is required" -}}{{- end -}}
{{- if not .Values.questdb.httpUser -}}{{- fail "questdb.httpUser is required because the chart enables HTTP authentication" -}}{{- end -}}
{{- $selector := include "questdb.selectorLabels" . | fromYaml -}}{{- range $key, $_ := .Values.podLabels -}}{{- if hasKey $selector $key -}}{{- fail (printf "podLabels must not override selector label %q" $key) -}}{{- end -}}{{- end -}}
{{- end -}}
