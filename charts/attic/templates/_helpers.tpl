{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "attic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "attic.fullname" -}}
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

{{- define "attic.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "attic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "attic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "attic.labels" -}}
helm.sh/chart: {{ include "attic.chart" . }}
{{ include "attic.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "attic.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "attic.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "attic.secretName" -}}
{{- default (printf "%s-credentials" (include "attic.fullname" .)) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "attic.pvcName" -}}
{{- default (printf "%s-data" (include "attic.fullname" .)) .Values.persistence.existingClaim -}}
{{- end -}}

{{- define "attic.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := int (.index | default 0) -}}
{{- if $route.name -}}
{{- printf "%s-%s" (include "attic.fullname" $root) $route.name | trunc 63 | trimSuffix "-" -}}
{{- else if gt $index 0 -}}
{{- printf "%s-%d" (include "attic.fullname" $root) $index | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "attic.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "attic.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- printf "%s-%s" (include "attic.fullname" $root) $item.name | trunc 63 | trimSuffix "-" -}}
{{- else if gt $index 0 -}}
{{- printf "%s-%d" (include "attic.fullname" $root) $index | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "attic.secretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "attic.config" -}}
listen = {{ .Values.config.listen | quote }}
allowed-hosts = {{ .Values.config.allowedHosts | toJson }}
api-endpoint = {{ .Values.config.apiEndpoint | quote }}
{{- with .Values.config.substituterEndpoint }}
substituter-endpoint = {{ . | quote }}
{{- end }}
max-nar-info-size = {{ int .Values.config.maxNarInfoSize }}
soft-delete-caches = {{ .Values.config.softDeleteCaches }}
require-proof-of-possession = {{ .Values.config.requireProofOfPossession }}

[database]
{{- if eq .Values.database.type "sqlite" }}
url = {{ printf "sqlite://%s?mode=rwc" .Values.database.sqlite.path | quote }}
{{- else }}
heartbeat = {{ .Values.database.postgresql.heartbeat }}
{{- end }}

[storage]
type = {{ .Values.storage.type | quote }}
{{- if eq .Values.storage.type "local" }}
path = {{ .Values.storage.local.path | quote }}
{{- else }}
region = {{ .Values.storage.s3.region | quote }}
bucket = {{ .Values.storage.s3.bucket | quote }}
{{- with .Values.storage.s3.endpoint }}
endpoint = {{ . | quote }}
{{- end }}
{{- end }}

[chunking]
nar-size-threshold = {{ .Values.config.chunking.narSizeThreshold }}
min-size = {{ .Values.config.chunking.minSize }}
avg-size = {{ .Values.config.chunking.avgSize }}
max-size = {{ .Values.config.chunking.maxSize }}

[compression]
type = {{ .Values.config.compression.type | quote }}
{{- with .Values.config.compression.level }}
level = {{ . }}
{{- end }}

[garbage-collection]
interval = {{ .Values.config.garbageCollection.interval | quote }}
default-retention-period = {{ .Values.config.garbageCollection.defaultRetentionPeriod | quote }}

[jwt]
{{- with .Values.config.jwt.tokenBoundIssuer }}
token-bound-issuer = {{ . | quote }}
{{- end }}
{{- with .Values.config.jwt.tokenBoundAudiences }}
token-bound-audiences = {{ . | toJson }}
{{- end }}
{{- end -}}

{{- define "attic.secretEnv" -}}
- name: ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64
  valueFrom:
    secretKeyRef:
      name: {{ include "attic.secretName" . }}
      key: {{ .Values.auth.hs256SecretKey }}
      optional: true
- name: ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64
  valueFrom:
    secretKeyRef:
      name: {{ include "attic.secretName" . }}
      key: {{ .Values.auth.rs256SecretKey }}
      optional: true
- name: ATTIC_SERVER_TOKEN_RS256_PUBKEY_BASE64
  valueFrom:
    secretKeyRef:
      name: {{ include "attic.secretName" . }}
      key: {{ .Values.auth.rs256PublicKey }}
      optional: true
{{- if eq .Values.database.type "postgresql" }}
- name: ATTIC_SERVER_DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "attic.secretName" . }}
      key: {{ .Values.database.postgresql.secretKey }}
{{- end }}
{{- if eq .Values.storage.type "s3" }}
{{- with .Values.storage.s3.accessKeyIdKey }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "attic.secretName" $ }}
      key: {{ . }}
      optional: true
{{- end }}
{{- with .Values.storage.s3.secretAccessKeyKey }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "attic.secretName" $ }}
      key: {{ . }}
      optional: true
{{- end }}
{{- end }}
{{- end -}}

{{- define "attic.validate" -}}
{{- if and (eq .Values.mode "standalone") (ne (int .Values.replicaCount) 1) -}}
{{- fail "replicaCount must be 1 when mode=standalone because SQLite/local storage is not safe for multiple replicas" -}}
{{- end -}}
{{- if and (eq .Values.mode "standalone") (ne .Values.database.type "sqlite") -}}
{{- fail "database.type must be sqlite when mode=standalone" -}}
{{- end -}}
{{- if and (eq .Values.mode "standalone") (ne .Values.storage.type "local") -}}
{{- fail "storage.type must be local when mode=standalone" -}}
{{- end -}}
{{- if and (eq .Values.mode "distributed") (ne .Values.database.type "postgresql") -}}
{{- fail "database.type must be postgresql when mode=distributed" -}}
{{- end -}}
{{- if and (eq .Values.mode "distributed") (ne .Values.storage.type "s3") -}}
{{- fail "storage.type must be s3 when mode=distributed" -}}
{{- end -}}
{{- if and (eq .Values.mode "distributed") (empty .Values.storage.s3.bucket) -}}
{{- fail "storage.s3.bucket is required when mode=distributed" -}}
{{- end -}}
{{- if and (eq .Values.mode "distributed") (empty .Values.auth.existingSecret) -}}
{{- fail "auth.existingSecret is required when mode=distributed so migrations can access stable database and JWT credentials" -}}
{{- end -}}
{{- if and (not .Values.auth.generate) (empty .Values.auth.existingSecret) -}}
{{- fail "auth.existingSecret is required when auth.generate=false" -}}
{{- end -}}
{{- if not (hasSuffix "/" .Values.config.apiEndpoint) -}}
{{- fail "config.apiEndpoint must end with /" -}}
{{- end -}}
{{- if and (or .Values.ingress.enabled .Values.gatewayAPI.enabled) (empty .Values.config.allowedHosts) -}}
{{- fail "config.allowedHosts must contain the public hostname when Ingress or Gateway API is enabled" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.pdb.enabled (or (ne .Values.mode "distributed") (lt (int .Values.replicaCount) 2)) -}}
{{- fail "pdb.enabled requires mode=distributed and replicaCount greater than 1" -}}
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
