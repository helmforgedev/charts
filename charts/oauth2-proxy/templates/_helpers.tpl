{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "oauth2-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "oauth2-proxy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "oauth2-proxy.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "oauth2-proxy.labels" -}}
helm.sh/chart: {{ include "oauth2-proxy.chart" . }}
app.kubernetes.io/name: {{ include "oauth2-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "oauth2-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oauth2-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "oauth2-proxy.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default (printf "v%s" .Chart.AppVersion)) -}}
{{- end -}}

{{- define "oauth2-proxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "oauth2-proxy.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "oauth2-proxy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy.configName" -}}
{{- printf "%s-config" (include "oauth2-proxy.fullname" .) -}}
{{- end -}}

{{- define "oauth2-proxy.authenticatedEmailsSecretName" -}}
{{- if .Values.authenticatedEmailsFile.existingSecret -}}
{{- .Values.authenticatedEmailsFile.existingSecret -}}
{{- else -}}
{{- printf "%s-authenticated-emails" (include "oauth2-proxy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy.alphaConfigSecretName" -}}
{{- if .Values.alphaConfig.existingSecret -}}
{{- .Values.alphaConfig.existingSecret -}}
{{- else -}}
{{- printf "%s-alpha-config" (include "oauth2-proxy.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy.cookieSecret" -}}
{{- $secretName := include "oauth2-proxy.secretName" . -}}
{{- if .Values.auth.cookieSecret -}}
{{- .Values.auth.cookieSecret -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing (index $existing.data .Values.auth.keys.cookieSecret) -}}
{{- index $existing.data .Values.auth.keys.cookieSecret | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy.secretEnv" -}}
- name: OAUTH2_PROXY_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "oauth2-proxy.secretName" . }}
      key: {{ .Values.auth.keys.clientID }}
- name: OAUTH2_PROXY_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "oauth2-proxy.secretName" . }}
      key: {{ .Values.auth.keys.clientSecret }}
- name: OAUTH2_PROXY_COOKIE_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "oauth2-proxy.secretName" . }}
      key: {{ .Values.auth.keys.cookieSecret }}
{{- end -}}

{{- define "oauth2-proxy.validate" -}}
{{- if and (not .Values.auth.createSecret) (not .Values.auth.existingSecret) (not .Values.externalSecrets.enabled) -}}
{{- fail "auth.createSecret=false requires auth.existingSecret or externalSecrets.enabled=true so OAuth2 Proxy credentials are available" -}}
{{- end -}}
{{- $trustedProxyIps := default (list) .Values.config.reverseProxy.trustedProxyIps -}}
{{- if and .Values.config.reverseProxy.enabled (eq (len $trustedProxyIps) 0) -}}
{{- fail "config.reverseProxy.trustedProxyIps must contain at least one trusted proxy CIDR when config.reverseProxy.enabled=true" -}}
{{- end -}}
{{- end -}}
