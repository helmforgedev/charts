{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "bulwark-mail.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bulwark-mail.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bulwark-mail.labels" -}}
helm.sh/chart: {{ include "bulwark-mail.chart" . }}
{{ include "bulwark-mail.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "bulwark-mail.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bulwark-mail.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "bulwark-mail.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "bulwark-mail.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.nameWithSuffix" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (max 1 (sub 63 (len $suffix))) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bulwark-mail.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "bulwark-mail.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.persistenceClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- include "bulwark-mail.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.sessionSecret" -}}
{{- if .Values.secrets.sessionSecret -}}
{{- .Values.secrets.sessionSecret -}}
{{- else -}}
{{- $name := include "bulwark-mail.fullname" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- $key := .Values.secrets.keys.sessionSecret -}}
{{- if and $existing $existing.data (hasKey $existing.data $key) -}}
{{- index $existing.data $key | b64dec -}}
{{- else -}}
{{- randAlphaNum 64 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := int (.index | default 0) -}}
{{- if $route.name -}}
{{- include "bulwark-mail.nameWithSuffix" (dict "base" (include "bulwark-mail.fullname" $root) "suffix" (printf "-%s" $route.name)) -}}
{{- else if gt $index 0 -}}
{{- include "bulwark-mail.nameWithSuffix" (dict "base" (include "bulwark-mail.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "bulwark-mail.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- include "bulwark-mail.nameWithSuffix" (dict "base" (include "bulwark-mail.fullname" $root) "suffix" (printf "-%s" $item.name)) -}}
{{- else if gt $index 0 -}}
{{- include "bulwark-mail.nameWithSuffix" (dict "base" (include "bulwark-mail.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "bulwark-mail.secretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "bulwark-mail.validate" -}}
{{- if ne (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount must be 1 because Bulwark writes mutable state to a single ReadWriteOnce data volume" -}}
{{- end -}}
{{- if .Values.autoscaling.enabled -}}
{{- fail "autoscaling.enabled is not supported for the single-writer Bulwark data contract" -}}
{{- end -}}
{{- if and (eq .Values.config.mode "declarative") (empty .Values.config.jmap.serverUrl) -}}
{{- fail "declarative mode requires config.jmap.serverUrl" -}}
{{- end -}}
{{- if and (eq .Values.config.mode "wizard") (not .Values.persistence.enabled) -}}
{{- fail "persistence.enabled must be true in wizard mode so setup and admin state survive pod replacement" -}}
{{- end -}}
{{- if and .Values.secrets.sessionSecret (lt (len .Values.secrets.sessionSecret) 32) -}}
{{- fail "secrets.sessionSecret must contain at least 32 characters" -}}
{{- end -}}
{{- if and .Values.config.oauth.enabled (or (empty .Values.config.oauth.clientId) (empty .Values.config.oauth.issuerUrl)) -}}
{{- fail "config.oauth.clientId and config.oauth.issuerUrl are required when OAuth is enabled" -}}
{{- end -}}
{{- if and .Values.config.oauth.only (not .Values.config.oauth.enabled) -}}
{{- fail "config.oauth.enabled must be true when config.oauth.only=true" -}}
{{- end -}}
{{- if .Values.config.jwtAuth.enabled -}}
{{- if and (empty .Values.secrets.existingSecret) (or (empty .Values.secrets.jwtAuthSecret) (empty .Values.secrets.stalwartMasterUser) (empty .Values.secrets.stalwartMasterPassword)) -}}
{{- fail "JWT impersonation requires its signing secret, Stalwart master user, and Stalwart master password" -}}
{{- end -}}
{{- if and (empty .Values.secrets.existingSecret) (lt (len .Values.secrets.jwtAuthSecret) 32) -}}
{{- fail "secrets.jwtAuthSecret must contain at least 32 characters" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled -}}
{{- fail "ingress.enabled and gatewayAPI.enabled are mutually exclusive" -}}
{{- end -}}
{{- if .Values.pdb.enabled -}}
{{- fail "pdb.enabled is not supported while replicaCount is restricted to 1" -}}
{{- end -}}
{{- range .Values.ingress.hosts }}
{{- range (.paths | default (list (dict "path" "/"))) }}
{{- if ne (.path | default "/") "/" -}}
{{- fail "Bulwark's published image only supports exposure at path /; ingress subpaths require a custom image rebuild" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}
{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- range .Values.gatewayAPI.httpRoutes }}
{{- if and .path (ne .path "/") -}}
{{- fail "Bulwark's published image only supports exposure at path /; Gateway API subpaths require a custom image rebuild" -}}
{{- end -}}
{{- range (.rules | default list) }}
{{- range (.matches | default list) }}
{{- if and .path .path.value (ne .path.value "/") -}}
{{- fail "Bulwark's published image only supports exposure at path /; Gateway API subpaths require a custom image rebuild" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and (empty .Values.secrets.existingSecret) (not .Values.secrets.generate) -}}
{{- fail "secrets.generate must be true when secrets.existingSecret is empty" -}}
{{- end -}}
{{- $reservedEnv := list "HOSTNAME" "PORT" "SESSION_SECRET" "JMAP_SERVER_URL" "ALLOW_CUSTOM_JMAP_ENDPOINT" "JMAP_SERVERS" "JMAP_SERVER_AUTO_PICK_BY_DOMAIN" "APP_NAME" "STALWART_FEATURES" "SETTINGS_SYNC_ENABLED" "SETTINGS_DATA_DIR" "ADMIN_CONFIG_DIR" "ADMIN_STATE_DIR" "TELEMETRY_DATA_DIR" "VERSION_CHECK_DATA_DIR" "ADMIN_CONFIG_READONLY" "ADMIN_PASSWORD" "ADMIN_SESSION_TTL" "STALWART_ADMIN_ACCESS" "OAUTH_ENABLED" "OAUTH_ONLY" "OAUTH_CLIENT_ID" "OAUTH_CLIENT_SECRET" "OAUTH_ISSUER_URL" "BULWARK_JWT_AUTH_SECRET" "BULWARK_STALWART_MASTER_USER" "BULWARK_STALWART_MASTER_PASSWORD" -}}
{{- range .Values.extraEnv }}
{{- if has .name $reservedEnv -}}
{{- fail (printf "extraEnv must not override chart-managed environment variable %s" .name) -}}
{{- end -}}
{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
{{- end -}}
