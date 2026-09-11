{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "siyuan.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "siyuan.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "siyuan.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "siyuan.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "siyuan.selectorLabels" -}}
app.kubernetes.io/name: {{ include "siyuan.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "siyuan.labels" -}}
helm.sh/chart: {{ include "siyuan.chart" . }}
{{ include "siyuan.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "siyuan.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "siyuan.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "siyuan.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "siyuan.authSecretName" -}}{{- default (printf "%s-auth" (include "siyuan.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "siyuan.claimName" -}}{{- default (include "siyuan.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "siyuan.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "siyuan.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- define "siyuan.oidcSecretName" -}}{{- default (printf "%s-oidc" (include "siyuan.fullname" . | trunc 58 | trimSuffix "-")) .Values.oidc.existingSecret -}}{{- end -}}
{{- define "siyuan.validate" -}}
{{- if .Values.oidc.enabled -}}
{{- if or (not .Values.oidc.issuerURL) (not .Values.oidc.clientID) (not .Values.oidc.redirectURL) (not (or .Values.oidc.existingSecret .Values.oidc.clientSecret)) -}}{{ fail "oidc requires issuerURL, clientID, redirectURL and clientSecret or existingSecret" }}{{- end -}}
{{- if and (not .Values.oidc.allowAll) (not .Values.oidc.claimRules) -}}{{ fail "oidc.claimRules is required unless oidc.allowAll explicitly grants workspace administration to every identity" }}{{- end -}}
{{- if not (regexMatch "^https://[^/?#]+/api/system/oidc/callback$" .Values.oidc.redirectURL) -}}{{ fail "oidc.redirectURL must be an HTTPS origin followed by /api/system/oidc/callback" }}{{- end -}}
{{- if and .Values.oidc.existingSecret .Values.oidc.clientSecret -}}{{ fail "oidc.existingSecret cannot be combined with inline clientSecret" }}{{- end -}}
{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "SiYuan requires exactly one writer per workspace, even with RWX storage" }}{{- end -}}
{{- if and .Values.auth.existingSecret .Values.auth.accessCode -}}{{ fail "auth.existingSecret cannot be combined with auth.accessCode" }}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{ fail "ingress.hosts is required when enabled" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must be non-empty when enabled" }}{{- end -}}
{{- if and (not .Values.persistence.enabled) .Values.persistence.existingClaim -}}{{ fail "persistence.existingClaim requires persistence.enabled" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (hasPrefix "SIYUAN_ACCESS_AUTH_CODE" .name) (hasPrefix "SIYUAN_OIDC_" .name) (has .name (list "HOME" "RUN_IN_CONTAINER" "SIYUAN_WORKSPACE_PATH")) -}}{{ fail (printf "extraEnv cannot override chart-managed security variable %s" .name) }}{{- end -}}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}

{{- define "siyuan.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "siyuan.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "siyuan.fullname" .root }}{{- end -}}
{{- end -}}
