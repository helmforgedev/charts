{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "bytestash.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "bytestash.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "bytestash.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "bytestash.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "bytestash.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bytestash.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: server
{{- end -}}
{{- define "bytestash.labels" -}}
helm.sh/chart: {{ include "bytestash.chart" . }}
{{ include "bytestash.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "bytestash.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "bytestash.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "bytestash.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "bytestash.authSecretName" -}}{{- default (printf "%s-auth" (include "bytestash.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "bytestash.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "bytestash.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "bytestash.claimName" -}}{{- default (include "bytestash.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "bytestash.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "bytestash.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "bytestash.validate" -}}
{{- if and .Values.oidc.enabled (or (not (hasPrefix "https://" .Values.oidc.issuerURL)) (not .Values.oidc.clientID) (not (or .Values.oidc.clientSecret .Values.oidc.existingSecret))) -}}{{ fail "OIDC requires HTTPS issuer, client ID and client Secret" }}{{- end -}}
{{- if and .Values.oidc.existingSecret .Values.oidc.clientSecret -}}{{ fail "OIDC existingSecret and clientSecret are mutually exclusive" }}{{- end -}}
{{- range .Values.extraVolumes -}}{{- if has .name (list "workspace" "auth" "bootstrap" "scripts" "tmp" "oidc-ca") -}}{{ fail "extraVolumes overlaps a chart-managed volume" }}{{- end -}}{{- end -}}
{{- range .Values.extraContainers -}}{{- if has .name (list "bytestash" "bootstrap") -}}{{ fail "extraContainers overlaps a chart-managed container" }}{{- end -}}{{- end -}}
{{- if and .Values.backup.enabled (not .Values.persistence.enabled) -}}{{ fail "backup requires persistent source storage" }}{{- end -}}
{{- if and .Values.backup.enabled (has "ReadWriteOncePod" .Values.persistence.accessModes) -}}{{ fail "online backup requires ReadWriteOnce or ReadWriteMany, not ReadWriteOncePod" }}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "ByteStash requires exactly one SQLite writer, even with RWX storage" }}{{- end -}}
{{- if and .Values.auth.existingSecret .Values.auth.jwtSecret -}}{{ fail "auth.existingSecret cannot be combined with auth.jwtSecret" }}{{- end -}}
{{- if and .Values.bootstrap.existingSecret .Values.bootstrap.password -}}{{ fail "bootstrap.existingSecret cannot be combined with bootstrap.password" }}{{- end -}}
{{- if and (not .Values.bootstrap.enabled) (not .Values.persistence.existingClaim) -}}{{ fail "Disabling protected bootstrap requires an existing populated workspace claim" }}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{ fail "ingress.hosts is required when enabled" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must be non-empty when enabled" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (hasPrefix "OIDC_" .name) (has .name (list "JWT_SECRET" "JWT_SECRET_FILE" "TOKEN_EXPIRY" "ADMIN_USERNAMES" "ALLOW_NEW_ACCOUNTS" "ALLOW_PASSWORD_CHANGES" "DISABLE_ACCOUNTS" "DISABLE_INTERNAL_ACCOUNTS" "BASE_PATH" "DEBUG")) -}}{{ fail (printf "extraEnv cannot override chart-managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" -}}{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}
{{- define "bytestash.oidcSecretName" -}}{{- default (printf "%s-oidc" (include "bytestash.fullname" . | trunc 58 | trimSuffix "-")) .Values.oidc.existingSecret -}}{{- end -}}
