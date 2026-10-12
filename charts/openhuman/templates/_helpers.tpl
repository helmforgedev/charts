{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "openhuman.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "openhuman.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "openhuman.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "openhuman.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "openhuman.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openhuman.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "openhuman.labels" -}}
helm.sh/chart: {{ include "openhuman.chart" . }}
{{ include "openhuman.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "openhuman.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "openhuman.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "openhuman.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "openhuman.authSecretName" -}}{{- default (include "openhuman.fullname" .) .Values.auth.existingSecret -}}{{- end -}}
{{- define "openhuman.externalSecretName" -}}{{- $root := .root -}}{{- $item := .item -}}{{- $index := .index -}}{{- coalesce $item.fullnameOverride $item.name (printf "%s-%d" (include "openhuman.fullname" $root) $index) | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "openhuman.validate" -}}
{{- if not .Values.persistence.enabled -}}{{- fail "persistence.enabled must remain true because OpenHuman state is not disposable" -}}{{- end -}}
{{- if not .Values.projectsPersistence.enabled -}}{{- fail "projectsPersistence.enabled must remain true with a read-only root filesystem" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.ingressClassName) -}}{{- fail "ingress.enabled requires ingress.ingressClassName" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{- fail "ingress.enabled requires at least one ingress.hosts entry" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.tls) -}}{{- fail "ingress.enabled requires TLS configuration" -}}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}{{- fail "gatewayAPI.enabled requires at least one gatewayAPI.httpRoutes entry" -}}{{- end -}}
{{- $selector := include "openhuman.selectorLabels" . | fromYaml -}}{{- range $key, $_ := .Values.podLabels -}}{{- if hasKey $selector $key -}}{{- fail (printf "podLabels must not override selector label %q" $key) -}}{{- end -}}{{- end -}}
{{- end -}}
