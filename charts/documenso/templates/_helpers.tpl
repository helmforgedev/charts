{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "documenso.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "documenso.fullname" -}}
{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}{{- $name := include "documenso.name" . -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- end -}}

{{- define "documenso.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "documenso.selectorLabels" -}}
app.kubernetes.io/name: {{ include "documenso.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "documenso.labels" -}}
helm.sh/chart: {{ include "documenso.chart" . }}
{{ include "documenso.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "documenso.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "documenso.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "documenso.image" -}}{{- if .Values.image.digest -}}{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}{{- else -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}{{- end -}}
{{- define "documenso.waitImage" -}}{{- printf "%s:%s" .Values.waitForServices.image.repository .Values.waitForServices.image.tag -}}{{- end -}}

{{- define "documenso.databaseFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- end -}}
{{- define "documenso.databaseHost" -}}{{- if .Values.database.external.enabled -}}{{- .Values.database.external.host -}}{{- else -}}{{- include "documenso.databaseFullname" . -}}{{- end -}}{{- end -}}
{{- define "documenso.databasePort" -}}{{- if .Values.database.external.enabled -}}{{- .Values.database.external.port -}}{{- else -}}5432{{- end -}}{{- end -}}
{{- define "documenso.databaseSecretName" -}}{{- if .Values.database.external.enabled -}}{{- .Values.database.external.existingSecret -}}{{- else if .Values.postgresql.auth.existingSecret -}}{{- .Values.postgresql.auth.existingSecret -}}{{- else -}}{{- printf "%s-auth" (include "documenso.databaseFullname" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "documenso.databaseSecretKey" -}}{{- default "user-password" .Values.postgresql.auth.existingSecretUserPasswordKey -}}{{- end -}}

{{- define "documenso.redisFullname" -}}
{{- if .Values.redis.fullnameOverride -}}{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- $name := default "redis" .Values.redis.nameOverride -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- end -}}
{{- define "documenso.redisHost" -}}{{- if .Values.redis.external.enabled -}}{{- .Values.redis.external.host -}}{{- else -}}{{- printf "%s-client" (include "documenso.redisFullname" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "documenso.redisPort" -}}{{- if .Values.redis.external.enabled -}}{{- .Values.redis.external.port -}}{{- else -}}6379{{- end -}}{{- end -}}
{{- define "documenso.redisSecretName" -}}{{- if .Values.redis.external.enabled -}}{{- .Values.redis.external.existingSecret -}}{{- else if .Values.redis.auth.existingSecret -}}{{- .Values.redis.auth.existingSecret -}}{{- else -}}{{- printf "%s-auth" (include "documenso.redisFullname" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "documenso.redisSecretKey" -}}{{- if .Values.redis.external.enabled -}}{{- .Values.redis.external.passwordKey -}}{{- else -}}{{ default "redis-password" .Values.redis.auth.existingSecretPasswordKey }}{{- end -}}{{- end -}}

{{- define "documenso.applicationSecretName" -}}{{- default (printf "%s-application" (include "documenso.fullname" .)) .Values.documenso.existingSecret -}}{{- end -}}
{{- define "documenso.publicUrl" -}}
{{- if .Values.documenso.publicUrl -}}{{- .Values.documenso.publicUrl -}}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}{{- $scheme := ternary "https" "http" (gt (len .Values.ingress.tls) 0) -}}{{- printf "%s://%s" $scheme (index .Values.ingress.hosts 0).host -}}
{{- else if and .Values.gatewayAPI.enabled (gt (len .Values.gatewayAPI.httpRoutes) 0) (gt (len ((index .Values.gatewayAPI.httpRoutes 0).hostnames | default list)) 0) -}}{{- printf "%s://%s" .Values.gatewayAPI.publicUrlScheme (index (index .Values.gatewayAPI.httpRoutes 0).hostnames 0) -}}
{{- else -}}{{- printf "http://%s.%s.svc:%v" (include "documenso.fullname" .) .Release.Namespace .Values.service.port -}}{{- end -}}
{{- end -}}
{{- define "documenso.externalSecretName" -}}{{- $root := .root -}}{{- $item := .item -}}{{- if $item.fullnameOverride -}}{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else if $item.name -}}{{- printf "%s-%s" (include "documenso.fullname" $root) $item.name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- fail "externalSecrets.items[].name or fullnameOverride is required" -}}{{- end -}}{{- end -}}
{{- define "documenso.httpRouteName" -}}{{- if .route.fullnameOverride -}}{{- .route.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else if .route.name -}}{{- printf "%s-%s" (include "documenso.fullname" .root) .route.name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%d" (include "documenso.fullname" .root) .index | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}

{{- define "documenso.validate" -}}
{{- if and .Values.database.external.enabled .Values.postgresql.enabled }}{{ fail "documenso: database.external.enabled and postgresql.enabled are mutually exclusive" }}{{ end -}}
{{- if and (not .Values.database.external.enabled) (not .Values.postgresql.enabled) }}{{ fail "documenso: enable postgresql or configure database.external" }}{{ end -}}
{{- if .Values.database.external.enabled }}{{- if not .Values.database.external.host }}{{ fail "documenso: database.external.host is required" }}{{ end -}}{{- if not .Values.database.external.existingSecret }}{{ fail "documenso: database.external.existingSecret is required" }}{{ end -}}{{- end -}}
{{- if eq .Values.documenso.jobsProvider "bullmq" }}
{{- if and .Values.redis.external.enabled .Values.redis.enabled }}{{ fail "documenso: redis.external.enabled and redis.enabled are mutually exclusive" }}{{ end -}}
{{- if and (not .Values.redis.external.enabled) (not .Values.redis.enabled) }}{{ fail "documenso: BullMQ requires bundled or external Redis" }}{{ end -}}
{{- if and .Values.redis.external.enabled (or (not .Values.redis.external.host) (not .Values.redis.external.existingSecret)) }}{{ fail "documenso: external Redis requires host and existingSecret" }}{{ end -}}
{{- else if or .Values.redis.enabled .Values.redis.external.enabled }}{{ fail "documenso: Redis may only be configured when jobsProvider is bullmq" }}{{ end -}}
{{- if and (gt (int .Values.replicaCount) 1) (ne .Values.documenso.jobsProvider "bullmq") }}{{ fail "documenso: multiple replicas require jobsProvider=bullmq" }}{{ end -}}
{{- if and (gt (int .Values.replicaCount) 1) (ne .Values.objectStorage.provider "s3") }}{{ fail "documenso: multiple replicas require shared S3 object storage" }}{{ end -}}
{{- if and .Values.autoscaling.enabled (ne .Values.documenso.jobsProvider "bullmq") }}{{ fail "documenso: autoscaling requires jobsProvider=bullmq" }}{{ end -}}
{{- if and .Values.autoscaling.enabled (ne .Values.objectStorage.provider "s3") }}{{ fail "documenso: autoscaling requires shared S3 object storage" }}{{ end -}}
{{- if and .Values.autoscaling.enabled (lt (int .Values.autoscaling.maxReplicas) (int .Values.autoscaling.minReplicas)) }}{{ fail "documenso: autoscaling.maxReplicas must be greater than or equal to minReplicas" }}{{ end -}}
{{- if and (eq .Values.objectStorage.provider "s3") (or (not .Values.objectStorage.s3.bucket) (not .Values.objectStorage.s3.existingSecret)) }}{{ fail "documenso: S3 storage requires bucket and existingSecret" }}{{ end -}}
{{- if .Values.smtp.enabled }}{{- if not .Values.smtp.host }}{{ fail "documenso: smtp.host is required" }}{{ end -}}{{- if not .Values.smtp.existingSecret }}{{ fail "documenso: smtp.existingSecret is required" }}{{ end -}}{{- end -}}
{{- if .Values.certificate.enabled }}{{- if not .Values.certificate.existingSecret }}{{ fail "documenso: certificate.existingSecret is required" }}{{ end -}}{{- end -}}
{{- if .Values.gotenberg.enabled }}{{- if not .Values.gotenberg.url }}{{ fail "documenso: gotenberg.url is required" }}{{ end -}}{{- end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled }}{{ fail "documenso: enable either ingress or gatewayAPI, not both" }}{{ end -}}
{{- if and .Values.networkPolicy.enabled .Values.networkPolicy.egressIsolation .Values.database.external.enabled (not .Values.database.external.networkPolicyPeers) (not .Values.networkPolicy.extraEgress) }}{{ fail "documenso: database.external.networkPolicyPeers or networkPolicy.extraEgress is required with egress isolation" }}{{ end -}}
{{- if and .Values.networkPolicy.enabled .Values.networkPolicy.egressIsolation .Values.redis.external.enabled (not .Values.redis.external.networkPolicyPeers) (not .Values.networkPolicy.extraEgress) }}{{ fail "documenso: redis.external.networkPolicyPeers or networkPolicy.extraEgress is required with egress isolation" }}{{ end -}}
{{- end -}}
