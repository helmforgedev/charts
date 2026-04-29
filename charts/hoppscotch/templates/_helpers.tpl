{{/* SPDX-License-Identifier: Apache-2.0 */}}

{{- define "hoppscotch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hoppscotch.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "hoppscotch.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hoppscotch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hoppscotch.labels" -}}
helm.sh/chart: {{ include "hoppscotch.chart" . }}
{{ include "hoppscotch.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "hoppscotch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hoppscotch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "hoppscotch.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "hoppscotch.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "hoppscotch.isProduction" -}}
{{- if eq .Values.mode "production" -}}true{{- end -}}
{{- end -}}

{{/*
validateAll — fail-fast on misconfigured values
*/}}
{{- define "hoppscotch.validateAll" -}}
{{- $mode := .Values.mode | default "dev" -}}
{{- if not (has $mode (list "dev" "production")) -}}
  {{- fail "mode must be one of: dev, production" -}}
{{- end -}}
{{- if eq $mode "production" -}}
  {{- if and (not .Values.ingress.host) (not .Values.baseUrl) -}}
    {{- fail "production mode requires ingress.host or baseUrl to be set" -}}
  {{- end -}}
  {{- if and (not .Values.postgresql.enabled) (not .Values.database.external.enabled) -}}
    {{- fail "production mode requires postgresql.enabled=true or database.external.enabled=true" -}}
  {{- end -}}
  {{- if and .Values.database.external.enabled (not .Values.database.external.host) (not .Values.database.external.url) (not .Values.database.external.existingSecret) -}}
    {{- fail "database.external.host or database.external.url or database.external.existingSecret is required when database.external.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.encryption.key (ne (len .Values.encryption.key) 32) -}}
  {{- fail "encryption.key must be exactly 32 characters when set" -}}
{{- end -}}
{{- if and .Values.auth.github.enabled (not .Values.auth.github.existingSecret) -}}
  {{- if not .Values.auth.github.clientId -}}
    {{- fail "auth.github.clientId is required when auth.github.enabled=true (or set auth.github.existingSecret)" -}}
  {{- end -}}
  {{- if not .Values.auth.github.clientSecret -}}
    {{- fail "auth.github.clientSecret is required when auth.github.enabled=true (or set auth.github.existingSecret)" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.auth.google.enabled (not .Values.auth.google.existingSecret) -}}
  {{- if not .Values.auth.google.clientId -}}
    {{- fail "auth.google.clientId is required when auth.google.enabled=true (or set auth.google.existingSecret)" -}}
  {{- end -}}
  {{- if not .Values.auth.google.clientSecret -}}
    {{- fail "auth.google.clientSecret is required when auth.google.enabled=true (or set auth.google.existingSecret)" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.auth.microsoft.enabled (not .Values.auth.microsoft.existingSecret) -}}
  {{- if not .Values.auth.microsoft.clientId -}}
    {{- fail "auth.microsoft.clientId is required when auth.microsoft.enabled=true (or set auth.microsoft.existingSecret)" -}}
  {{- end -}}
  {{- if not .Values.auth.microsoft.clientSecret -}}
    {{- fail "auth.microsoft.clientSecret is required when auth.microsoft.enabled=true (or set auth.microsoft.existingSecret)" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.mailer.enabled .Values.mailer.useCustomConfigs (not .Values.mailer.host) (not .Values.mailer.existingSecret) -}}
  {{- fail "mailer.host is required when mailer.enabled=true and mailer.useCustomConfigs=true" -}}
{{- end -}}
{{- if and .Values.mailer.enabled (not .Values.mailer.useCustomConfigs) (not .Values.mailer.smtpUrl) (not .Values.mailer.existingSecret) -}}
  {{- fail "mailer.smtpUrl is required when mailer.enabled=true and mailer.useCustomConfigs=false (or set mailer.existingSecret)" -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (not .Values.gatewayAPI.parentRefs) -}}
  {{- fail "gatewayAPI.parentRefs is required when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
  {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- end -}}

{{/*
protocol — https if TLS configured, else http
*/}}
{{- define "hoppscotch.protocol" -}}
{{- if .Values.ingress.tls -}}https{{- else -}}http{{- end -}}
{{- end -}}

{{/*
baseUrl — VITE_BASE_URL
*/}}
{{- define "hoppscotch.baseUrl" -}}
{{- if .Values.baseUrl -}}
{{- .Values.baseUrl -}}
{{- else if .Values.ingress.host -}}
{{- printf "%s://%s" (include "hoppscotch.protocol" .) .Values.ingress.host -}}
{{- else -}}
http://localhost:3000
{{- end -}}
{{- end -}}

{{/*
adminUrl — VITE_ADMIN_URL
*/}}
{{- define "hoppscotch.adminUrl" -}}
{{- if .Values.adminUrl -}}
{{- .Values.adminUrl -}}
{{- else if .Values.ingress.host -}}
{{- printf "%s://%s/admin" (include "hoppscotch.protocol" .) .Values.ingress.host -}}
{{- else -}}
http://localhost:3100
{{- end -}}
{{- end -}}

{{/*
backendGqlUrl — VITE_BACKEND_GQL_URL
*/}}
{{- define "hoppscotch.backendGqlUrl" -}}
{{- if .Values.backendGqlUrl -}}
{{- .Values.backendGqlUrl -}}
{{- else if .Values.ingress.host -}}
{{- printf "%s://%s/backend/graphql" (include "hoppscotch.protocol" .) .Values.ingress.host -}}
{{- else -}}
http://localhost:3170/graphql
{{- end -}}
{{- end -}}

{{/*
backendWsUrl — VITE_BACKEND_WS_URL (wss:// in production)
*/}}
{{- define "hoppscotch.backendWsUrl" -}}
{{- if .Values.backendWsUrl -}}
{{- .Values.backendWsUrl -}}
{{- else if .Values.ingress.host -}}
{{- if .Values.ingress.tls -}}
{{- printf "wss://%s/backend/graphql" .Values.ingress.host -}}
{{- else -}}
{{- printf "ws://%s/backend/graphql" .Values.ingress.host -}}
{{- end -}}
{{- else -}}
ws://localhost:3170/graphql
{{- end -}}
{{- end -}}

{{/*
backendApiUrl — VITE_BACKEND_API_URL
*/}}
{{- define "hoppscotch.backendApiUrl" -}}
{{- if .Values.backendApiUrl -}}
{{- .Values.backendApiUrl -}}
{{- else if .Values.ingress.host -}}
{{- printf "%s://%s/backend/v1" (include "hoppscotch.protocol" .) .Values.ingress.host -}}
{{- else -}}
http://localhost:3170/v1
{{- end -}}
{{- end -}}

{{/*
shortcodeBaseUrl — VITE_SHORTCODE_BASE_URL
*/}}
{{- define "hoppscotch.shortcodeBaseUrl" -}}
{{- if .Values.shortcodeBaseUrl -}}
{{- .Values.shortcodeBaseUrl -}}
{{- else -}}
{{- include "hoppscotch.baseUrl" . -}}
{{- end -}}
{{- end -}}

{{/*
whitelistedOrigins — WHITELISTED_ORIGINS CSV
*/}}
{{- define "hoppscotch.whitelistedOrigins" -}}
{{- $base := include "hoppscotch.baseUrl" . -}}
{{- $admin := include "hoppscotch.adminUrl" . -}}
{{- $api := include "hoppscotch.backendApiUrl" . -}}
{{- printf "%s,%s,%s,app://localhost_3200,app://hoppscotch" $base $admin $api -}}
{{- end -}}

{{/*
authProviders — VITE_ALLOWED_AUTH_PROVIDERS
*/}}
{{- define "hoppscotch.authProviders" -}}
{{- .Values.auth.providers | default "EMAIL" -}}
{{- end -}}

{{/*
githubCallbackUrl
*/}}
{{- define "hoppscotch.githubCallbackUrl" -}}
{{- if .Values.auth.github.callbackUrl -}}
{{- .Values.auth.github.callbackUrl -}}
{{- else -}}
{{- printf "%s/auth/github/callback" (include "hoppscotch.backendApiUrl" .) -}}
{{- end -}}
{{- end -}}

{{/*
googleCallbackUrl
*/}}
{{- define "hoppscotch.googleCallbackUrl" -}}
{{- if .Values.auth.google.callbackUrl -}}
{{- .Values.auth.google.callbackUrl -}}
{{- else -}}
{{- printf "%s/auth/google/callback" (include "hoppscotch.backendApiUrl" .) -}}
{{- end -}}
{{- end -}}

{{/*
microsoftCallbackUrl
*/}}
{{- define "hoppscotch.microsoftCallbackUrl" -}}
{{- if .Values.auth.microsoft.callbackUrl -}}
{{- .Values.auth.microsoft.callbackUrl -}}
{{- else -}}
{{- printf "%s/auth/microsoft/callback" (include "hoppscotch.backendApiUrl" .) -}}
{{- end -}}
{{- end -}}

{{/*
databaseHost — resolves subchart or external host
*/}}
{{- define "hoppscotch.databaseHost" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
databasePort
*/}}
{{- define "hoppscotch.databasePort" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.port | default 5432 | toString -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{/*
databaseName
*/}}
{{- define "hoppscotch.databaseName" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.name | default "hoppscotch" -}}
{{- else -}}
{{- .Values.postgresql.auth.database | default "hoppscotch" -}}
{{- end -}}
{{- end -}}

{{/*
databaseSecretName — name of the secret holding database-url
*/}}
{{- define "hoppscotch.databaseSecretName" -}}
{{- if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- include "hoppscotch.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
databaseSecretUrlKey — key within the secret for the full DATABASE_URL value
*/}}
{{- define "hoppscotch.databaseSecretUrlKey" -}}
{{- if and .Values.database.external.existingSecret .Values.database.external.existingSecretUrlKey -}}
{{- .Values.database.external.existingSecretUrlKey -}}
{{- else -}}
database-url
{{- end -}}
{{- end -}}

{{/*
encryptionSecretName — name of the secret holding data-encryption-key
*/}}
{{- define "hoppscotch.encryptionSecretName" -}}
{{- if .Values.encryption.existingSecret -}}
{{- .Values.encryption.existingSecret -}}
{{- else -}}
{{- include "hoppscotch.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
encryptionSecretKey — key within the secret for data-encryption-key
*/}}
{{- define "hoppscotch.encryptionSecretKey" -}}
{{- if .Values.encryption.existingSecret -}}
{{- .Values.encryption.existingSecretKey | default "data-encryption-key" -}}
{{- else -}}
data-encryption-key
{{- end -}}
{{- end -}}

{{/*
databaseEnv — env entries for DATABASE_URL (and DB_PASSWORD helper for password-only mode).
Handles three cases:
  1. existingSecret with full URL key → single secretKeyRef
  2. existingSecret password-only → K8s env-var substitution using $(DB_PASSWORD)
  3. chart-managed secret → single secretKeyRef to chart secret
*/}}
{{- define "hoppscotch.databaseEnv" -}}
{{- if and .Values.database.external.enabled .Values.database.external.existingSecret (not .Values.database.external.existingSecretUrlKey) }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.external.existingSecret }}
      key: {{ .Values.database.external.existingSecretPasswordKey }}
- name: DATABASE_URL
  value: {{ printf "postgresql://%s:$(DB_PASSWORD)@%s:%s/%s" .Values.database.external.username (include "hoppscotch.databaseHost" .) (include "hoppscotch.databasePort" .) (include "hoppscotch.databaseName" .) | quote }}
{{- else }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "hoppscotch.databaseSecretName" . }}
      key: {{ include "hoppscotch.databaseSecretUrlKey" . }}
{{- end }}
{{- end -}}
