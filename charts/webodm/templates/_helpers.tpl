{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "webodm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "webodm.fullname" -}}
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

{{- define "webodm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "webodm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webodm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "webodm.componentSelectorLabels" -}}
{{ include "webodm.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "webodm.labels" -}}
helm.sh/chart: {{ include "webodm.chart" . }}
{{ include "webodm.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "webodm.image" -}}
{{- printf "%s:%s@%s" .Values.image.repository .Values.image.tag .Values.image.digest -}}
{{- end -}}

{{- define "webodm.processingImage" -}}
{{- if .Values.processing.gpu.enabled -}}
{{- printf "%s:%s@%s" .Values.processing.gpu.image.repository .Values.processing.gpu.image.tag .Values.processing.gpu.image.digest -}}
{{- else -}}
{{- printf "%s:%s@%s" .Values.processing.image.repository .Values.processing.image.tag .Values.processing.image.digest -}}
{{- end -}}
{{- end -}}

{{- define "webodm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "webodm.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "webodm.secretName" -}}
{{- default (printf "%s-auth" (include "webodm.fullname" .)) .Values.webodm.existingSecret -}}
{{- end -}}

{{- define "webodm.mediaClaimName" -}}
{{- default (printf "%s-media" (include "webodm.fullname" .)) .Values.persistence.existingClaim -}}
{{- end -}}

{{- define "webodm.processingClaimName" -}}
{{- default (printf "%s-processing" (include "webodm.fullname" .)) .Values.processing.persistence.existingClaim -}}
{{- end -}}

{{- define "webodm.processingServiceName" -}}
{{- printf "%s-processing" (include "webodm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "webodm.oidcConfigMapName" -}}
{{- printf "%s-oidc" (include "webodm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "webodm.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- printf "%s-%s" (include "webodm.fullname" $root) $item.name | trunc 63 | trimSuffix "-" -}}
{{- else if gt $index 0 -}}
{{- printf "%s-%d" (include "webodm.fullname" $root) $index | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "webodm.secretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "webodm.databaseHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "postgresql.primaryServiceName" .Subcharts.postgresql -}}
{{- else -}}
{{- .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "webodm.databaseName" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "webodm.databaseUser" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}

{{- define "webodm.databaseSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "postgresql.secretName" .Subcharts.postgresql -}}
{{- else -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "webodm.databaseSecretKey" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{- else -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}{{- end -}}
{{- end -}}

{{- define "webodm.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{- include "redis.clientServiceName" .Subcharts.redis -}}
{{- else -}}
{{- .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{- define "webodm.redisSecretName" -}}
{{- if .Values.redis.enabled -}}
{{- include "redis.secretName" .Subcharts.redis -}}
{{- else -}}
{{- .Values.externalRedis.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "webodm.redisSecretKey" -}}
{{- if .Values.redis.enabled -}}{{ .Values.redis.auth.existingSecretPasswordKey }}{{- else -}}{{ .Values.externalRedis.existingSecretPasswordKey }}{{- end -}}
{{- end -}}

{{- define "webodm.applicationEnv" -}}
- name: WO_DATABASE_HOST
  value: {{ include "webodm.databaseHost" . | quote }}
- name: WO_DATABASE_PORT
  value: {{ ternary 5432 .Values.externalDatabase.port .Values.postgresql.enabled | quote }}
- name: WO_DATABASE_NAME
  value: {{ include "webodm.databaseName" . | quote }}
- name: WO_DATABASE_USER
  value: {{ include "webodm.databaseUser" . | quote }}
- name: WO_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "webodm.databaseSecretName" . }}
      key: {{ include "webodm.databaseSecretKey" . }}
- name: REDIS_HOST
  value: {{ include "webodm.redisHost" . | quote }}
- name: REDIS_PORT
  value: {{ ternary 6379 .Values.externalRedis.port .Values.redis.enabled | quote }}
- name: REDIS_DATABASE
  value: {{ .Values.externalRedis.database | quote }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "webodm.redisSecretName" . }}
      key: {{ include "webodm.redisSecretKey" . }}
- name: WO_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "webodm.secretName" . }}
      key: {{ .Values.webodm.existingSecretKeyKey }}
- name: WO_BROKER
  value: "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/$(REDIS_DATABASE)"
- name: WO_HOST
  value: {{ .Values.webodm.host | quote }}
- name: WO_PORT
  value: "8000"
- name: WO_DEBUG
  value: {{ ternary "YES" "NO" .Values.webodm.debug | quote }}
- name: WO_SSL
  value: "NO"
- name: WO_DEFAULT_NODES
  value: "0"
{{- if .Values.oidc.enabled }}
- name: WEBODM_OIDC_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.oidc.existingSecret }}
      key: {{ .Values.oidc.existingSecretClientSecretKey }}
{{- end }}
{{- with .Values.webodm.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "webodm.validate" -}}
{{- if and (not .Values.postgresql.enabled) (or (empty .Values.externalDatabase.host) (empty .Values.externalDatabase.existingSecret)) -}}
{{- fail "externalDatabase.host and externalDatabase.existingSecret are required when postgresql.enabled=false" -}}
{{- end -}}
{{- if and (not .Values.redis.enabled) (or (empty .Values.externalRedis.host) (empty .Values.externalRedis.existingSecret)) -}}
{{- fail "externalRedis.host and externalRedis.existingSecret are required when redis.enabled=false" -}}
{{- end -}}
{{- if and (gt (int .Values.worker.replicaCount) 1) (not (has "ReadWriteMany" .Values.persistence.accessModes)) -}}
{{- fail "persistence.accessModes must include ReadWriteMany when worker.replicaCount is greater than one" -}}
{{- end -}}
{{- if and (not .Values.persistence.enabled) (empty .Values.persistence.existingClaim) -}}
{{- fail "persistence.enabled or persistence.existingClaim is required because webapp and worker share media" -}}
{{- end -}}
{{- if .Values.oidc.enabled -}}
{{- if or (empty .Values.oidc.clientId) (empty .Values.oidc.existingSecret) (empty .Values.oidc.authEndpoint) (empty .Values.oidc.tokenEndpoint) (empty .Values.oidc.userinfoEndpoint) -}}
{{- fail "oidc.clientId, oidc.existingSecret, oidc.authEndpoint, oidc.tokenEndpoint, and oidc.userinfoEndpoint are required when oidc.enabled=true" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.pdb.enabled (lt (int .Values.worker.replicaCount) 2) -}}
{{- fail "pdb.enabled requires worker.replicaCount greater than one" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{ fail "podLabels must not override app.kubernetes.io/name" }}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{ fail "podLabels must not override app.kubernetes.io/instance" }}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/component" -}}{{ fail "podLabels must not override app.kubernetes.io/component" }}{{- end -}}
{{- end -}}
{{- end -}}
