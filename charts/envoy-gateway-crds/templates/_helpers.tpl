{{/* SPDX-License-Identifier: Apache-2.0 */}}

{{/* Chart label. */}}
{{- define "envoy-gateway-crds.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels for Helm-managed resources. */}}
{{- define "envoy-gateway-crds.labels" -}}
helm.sh/chart: {{ include "envoy-gateway-crds.chart" . }}
app.kubernetes.io/name: envoy-gateway-crds
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: envoy-gateway
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Fail-fast lifecycle validation. */}}
{{- define "envoy-gateway-crds.validate" -}}
{{- if and (not .Values.crds.gatewayAPI.enabled) (not .Values.crds.envoyGateway.enabled) -}}
{{- fail "at least one CRD bundle must be enabled: crds.gatewayAPI.enabled or crds.envoyGateway.enabled" -}}
{{- end -}}
{{- if and (eq .Values.safeUpgradePolicy.management "managed") (not .Values.crds.gatewayAPI.enabled) -}}
{{- fail "safeUpgradePolicy.management=managed requires crds.gatewayAPI.enabled=true; use external or disabled for provider-managed Gateway API CRDs" -}}
{{- end -}}
{{- end -}}
