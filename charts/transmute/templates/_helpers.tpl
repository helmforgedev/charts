{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "transmute.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "transmute.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "transmute.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "transmute.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "transmute.selectorLabels" -}}
app.kubernetes.io/name: {{ include "transmute.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: app
{{- end -}}
{{- define "transmute.labels" -}}
helm.sh/chart: {{ include "transmute.chart" . }}
{{ include "transmute.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{ end }}
{{- end -}}
{{- define "transmute.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "transmute.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "transmute.image" -}}{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}{{- end -}}
{{- define "transmute.secretName" -}}{{- default (printf "%s-auth" (include "transmute.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "transmute.claimName" -}}{{- default (include "transmute.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}

{{- define "transmute.externalSecretName" -}}
{{- if .item.fullnameOverride -}}
{{- .item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .item.name -}}
{{- printf "%s-%s" (include "transmute.fullname" .root | trunc 50 | trimSuffix "-") .item.name | trunc 63 | trimSuffix "-" -}}
{{- else if gt (int .index) 0 -}}
{{- printf "%s-%d" (include "transmute.fullname" .root | trunc 60 | trimSuffix "-") .index | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "transmute.secretName" .root -}}
{{- end -}}
{{- end -}}

{{- define "transmute.validate" -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{- fail "replicaCount must be 1 because Transmute uses local SQLite state" -}}{{- end -}}
{{- if not .Values.persistence.enabled -}}{{- fail "persistence.enabled must be true because Transmute stores users, jobs and files under DATA_DIR" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}{{- end -}}
{{- if and .Values.oidc.enabled (empty .Values.config.appUrl) -}}{{- fail "config.appUrl is required when oidc.enabled=true" -}}{{- end -}}
{{- if and .Values.oidc.enabled (empty .Values.oidc.issuerUrl) -}}{{- fail "oidc.issuerUrl is required when oidc.enabled=true" -}}{{- end -}}
{{- if and .Values.oidc.enabled (empty .Values.oidc.clientId) -}}{{- fail "oidc.clientId is required when oidc.enabled=true" -}}{{- end -}}
{{- if and .Values.oidc.enabled (empty .Values.oidc.clientSecret) (empty .Values.auth.existingSecret) -}}{{- fail "oidc.clientSecret or auth.existingSecret is required when oidc.enabled=true" -}}{{- end -}}
{{- if and .Values.oidc.enabled .Values.oidc.clientSecret (eq .Values.auth.secretKeyKey .Values.oidc.clientSecretKey) -}}{{- fail "auth.secretKeyKey and oidc.clientSecretKey must differ when inline OIDC is configured" -}}{{- end -}}
{{- if and .Values.auth.secretKey (lt (len .Values.auth.secretKey) 32) -}}{{- fail "auth.secretKey must contain at least 32 characters" -}}{{- end -}}
{{- if ne .Values.config.dataDir .Values.persistence.mountPath -}}{{- fail "config.dataDir must equal persistence.mountPath so all application state remains on the PVC" -}}{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{- fail "podLabels must not override app.kubernetes.io/name" -}}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{- fail "podLabels must not override app.kubernetes.io/instance" -}}{{- end -}}
{{- end -}}
{{- end -}}

{{/*
HTTPRoute name helper
*/}}
{{- define "transmute.httpRouteName" -}}
{{- if .route.name -}}
{{- printf "%s-%s" (include "transmute.fullname" .root | trunc 45 | trimSuffix "-") .route.name | trunc 63 | trimSuffix "-" -}}
{{- else if eq (len .root.Values.gatewayAPI.httpRoutes) 1 -}}
{{- include "transmute.fullname" .root -}}
{{- else -}}
{{- printf "%s-%d" (include "transmute.fullname" .root | trunc 55 | trimSuffix "-") .index | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
