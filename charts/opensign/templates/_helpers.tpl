{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "opensign.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opensign.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "opensign.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "opensign.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opensign.labels" -}}
helm.sh/chart: {{ include "opensign.chart" . }}
app.kubernetes.io/name: {{ include "opensign.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: opensign
{{- with .Values.commonLabels }}
{{ toYaml . | nindent 0 }}
{{- end }}
{{- end -}}

{{- define "opensign.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opensign.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "opensign.componentSelectorLabels" -}}
{{ include "opensign.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "opensign.componentName" -}}
{{- printf "%s-%s" (include "opensign.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opensign.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "opensign.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "opensign.frontendImage" -}}
{{- printf "%s@%s" .Values.frontend.image.repository .Values.frontend.image.digest -}}
{{- end -}}

{{- define "opensign.backendImage" -}}
{{- printf "%s@%s" .Values.backend.image.repository .Values.backend.image.digest -}}
{{- end -}}

{{- define "opensign.secretName" -}}
{{- default (include "opensign.fullname" .) .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "opensign.mongodbSecretName" -}}
{{- if .Values.externalMongodb.enabled -}}
{{- .Values.externalMongodb.existingSecret -}}
{{- else -}}
{{- include "mongodb.secretName" (dict "Values" .Values.mongodb "Chart" (dict "Name" "mongodb") "Release" .Release) -}}
{{- end -}}
{{- end -}}

{{- define "opensign.mongodbHost" -}}
{{- include "mongodb.fullname" (dict "Values" .Values.mongodb "Chart" (dict "Name" "mongodb") "Release" .Release) -}}
{{- end -}}

{{- define "opensign.persistenceClaimName" -}}
{{- default (include "opensign.fullname" .) .Values.storage.persistence.existingClaim -}}
{{- end -}}

{{- define "opensign.validate" -}}
{{- if and .Values.frontend.autoscaling.enabled (gt (int .Values.frontend.autoscaling.minReplicas) (int .Values.frontend.autoscaling.maxReplicas)) -}}
{{- fail "frontend.autoscaling.maxReplicas must be greater than or equal to minReplicas" -}}
{{- end -}}
{{- if and .Values.frontend.autoscaling.enabled (not .Values.frontend.autoscaling.targetCPUUtilizationPercentage) (not .Values.frontend.autoscaling.targetMemoryUtilizationPercentage) -}}
{{- fail "frontend.autoscaling requires at least one CPU or memory utilization target" -}}
{{- end -}}
{{- if eq .Values.mongodb.enabled .Values.externalMongodb.enabled -}}
{{- fail "exactly one of mongodb.enabled or externalMongodb.enabled must be true" -}}
{{- end -}}
{{- if and .Values.externalMongodb.enabled (not .Values.externalMongodb.uri) (not .Values.externalMongodb.existingSecret) -}}
{{- fail "externalMongodb.uri or externalMongodb.existingSecret is required when externalMongodb.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalMongodb.enabled .Values.networkPolicy.enabled (not .Values.externalMongodb.networkPolicyPeers) (not .Values.networkPolicy.extraEgress) -}}
{{- fail "externalMongodb.networkPolicyPeers or networkPolicy.extraEgress is required for external MongoDB when NetworkPolicy is enabled" -}}
{{- end -}}
{{- if not (hasSuffix "/app" (trimSuffix "/" .Values.config.apiUrl)) -}}
{{- fail "config.apiUrl must end with /app" -}}
{{- end -}}
{{- if and .Values.smtp.enabled (or (not .Values.smtp.host) (not .Values.smtp.fromAddress)) -}}
{{- fail "smtp.host and smtp.fromAddress are required when smtp.enabled=true" -}}
{{- end -}}
{{- if and .Values.smtp.enabled (not .Values.secrets.existingSecret) (not .Values.secrets.smtpPassword) -}}
{{- fail "secrets.smtpPassword or secrets.existingSecret is required when smtp.enabled=true" -}}
{{- end -}}
{{- if ne (empty .Values.secrets.pfxBase64) (empty .Values.secrets.pfxPassphrase) -}}
{{- fail "secrets.pfxBase64 and secrets.pfxPassphrase must be configured together" -}}
{{- end -}}
{{- if eq .Values.storage.type "s3" -}}
  {{- if or (not .Values.storage.s3.bucket) (not .Values.storage.s3.endpoint) (not .Values.storage.s3.baseUrl) -}}
  {{- fail "storage.s3.bucket, endpoint, and baseUrl are required when storage.type=s3" -}}
  {{- end -}}
  {{- if and (not .Values.secrets.existingSecret) (or (not .Values.secrets.objectStorageAccessKeyId) (not .Values.secrets.objectStorageSecretAccessKey)) -}}
  {{- fail "S3 credentials or secrets.existingSecret are required when storage.type=s3" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.ingress.enabled -}}
  {{- if or (not .Values.ingress.frontendHost) (not .Values.ingress.apiHost) -}}
  {{- fail "ingress.frontendHost and ingress.apiHost are required when ingress.enabled=true" -}}
  {{- end -}}
  {{- if eq .Values.ingress.frontendHost .Values.ingress.apiHost -}}
  {{- fail "ingress frontend and API hosts must differ because OpenSign exposes backend root routes" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.ingress.enabled .Values.gateway.enabled -}}
{{- fail "ingress.enabled and gateway.enabled are mutually exclusive" -}}
{{- end -}}
{{- if .Values.gateway.enabled -}}
  {{- if not .Values.gateway.parentRefs -}}
  {{- fail "gateway.parentRefs must not be empty when gateway.enabled=true" -}}
  {{- end -}}
  {{- if or (not .Values.gateway.frontendHostnames) (not .Values.gateway.apiHostnames) -}}
  {{- fail "gateway frontendHostnames and apiHostnames must not be empty when gateway.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.secrets.existingSecret -}}
  {{- fail "externalSecrets.enabled requires secrets.existingSecret" -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
  {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.items -}}
  {{- fail "externalSecrets.items must not be empty when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- $hasMasterKey := false -}}
  {{- range .Values.externalSecrets.items -}}
    {{- if eq .secretKey $.Values.secrets.masterKeyKey }}{{ $hasMasterKey = true }}{{ end -}}
  {{- end -}}
  {{- if not $hasMasterKey -}}
  {{- fail (printf "externalSecrets.items must map the required key %q" .Values.secrets.masterKeyKey) -}}
  {{- end -}}
{{- end -}}
{{- range .Values.frontend.extraEnv -}}
  {{- if has .name (list "PUBLIC_URL" "REACT_APP_SERVERURL" "REACT_APP_APPID" "PORT" "HOME") -}}
  {{- fail (printf "frontend.extraEnv must not override chart-managed environment variable %s" .name) -}}
  {{- end -}}
{{- end -}}
{{- range .Values.backend.extraEnv -}}
  {{- if has .name (list "APP_ID" "appName" "MASTER_KEY" "MONGODB_ROOT_PASSWORD" "MONGODB_URI" "PARSE_MOUNT" "SERVER_URL" "PUBLIC_URL" "PORT" "USE_LOCAL" "SMTP_ENABLE" "SMTP_HOST" "SMTP_PORT" "SMTP_USERNAME" "SMTP_USER_EMAIL" "SMTP_PASS" "PFX_BASE64" "PASS_PHRASE" "DO_SPACE" "DO_ENDPOINT" "DO_BASEURL" "DO_REGION" "DO_ACCESS_KEY_ID" "DO_SECRET_ACCESS_KEY" "HOME") -}}
  {{- fail (printf "backend.extraEnv must not override chart-managed environment variable %s" .name) -}}
  {{- end -}}
{{- end -}}
{{- $reserved := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" -}}
{{- range $key, $_ := (.Values.podLabels | default dict) -}}
  {{- if has $key $reserved -}}
  {{- fail (printf "podLabels must not override selector label %q" $key) -}}
  {{- end -}}
{{- end -}}
{{- end -}}
