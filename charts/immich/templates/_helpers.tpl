{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "immich.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "immich.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- $name := include "immich.name" . -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}{{- end -}}
{{- define "immich.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "immich.selectorLabels" -}}
app.kubernetes.io/name: {{ include "immich.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "immich.labels" -}}
helm.sh/chart: {{ include "immich.chart" . }}
{{ include "immich.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "immich.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "immich.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "immich.databaseInternalEnabled" -}}{{- if .Values.postgresql.enabled -}}true{{- end -}}{{- end -}}
{{- define "immich.postgresqlFullname" -}}{{- if .Values.postgresql.fullnameOverride -}}{{ .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "immich.valkeyFullname" -}}{{- if .Values.valkey.fullnameOverride -}}{{ .Values.valkey.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{- $name := default "valkey" .Values.valkey.nameOverride -}}{{- if contains $name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}{{- end -}}
{{- define "immich.databaseHost" -}}{{- if include "immich.databaseInternalEnabled" . -}}{{ include "immich.postgresqlFullname" . }}{{- else -}}{{ .Values.database.external.host }}{{- end -}}{{- end -}}
{{- define "immich.databasePort" -}}{{- if include "immich.databaseInternalEnabled" . -}}{{ .Values.postgresql.service.port | default 5432 }}{{- else -}}{{ .Values.database.external.port }}{{- end -}}{{- end -}}
{{- define "immich.databaseName" -}}{{- if include "immich.databaseInternalEnabled" . -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.database.external.database }}{{- end -}}{{- end -}}
{{- define "immich.databaseUsername" -}}{{- if include "immich.databaseInternalEnabled" . -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.database.external.username }}{{- end -}}{{- end -}}
{{- define "immich.databaseSecretName" -}}{{- if include "immich.databaseInternalEnabled" . -}}{{- $pgExternalSecrets := .Values.postgresql.externalSecrets | default dict -}}{{- $pgExternalSecretsAuth := $pgExternalSecrets.auth | default dict -}}{{- if .Values.postgresql.auth.existingSecret -}}{{ .Values.postgresql.auth.existingSecret }}{{- else if and $pgExternalSecrets.enabled $pgExternalSecretsAuth.enabled -}}{{ default (printf "%s-auth" (include "immich.postgresqlFullname" .)) $pgExternalSecretsAuth.targetName }}{{- else -}}{{ printf "%s-auth" (include "immich.postgresqlFullname" .) }}{{- end -}}{{- else if .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecret }}{{- else -}}{{ include "immich.fullname" . }}-database{{- end -}}{{- end -}}
{{- define "immich.databaseSecretKey" -}}{{- if include "immich.databaseInternalEnabled" . -}}{{- if eq .Values.postgresql.auth.username "postgres" -}}{{ .Values.postgresql.auth.existingSecretPostgresPasswordKey | default "postgres-password" }}{{- else -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" }}{{- end -}}{{- else if .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecretPasswordKey }}{{- else -}}database-password{{- end -}}{{- end -}}
{{- define "immich.databasePassword" -}}
{{- .Values.database.external.password -}}
{{- end -}}
{{- define "immich.valkeyInternalEnabled" -}}{{- if .Values.valkey.internal.enabled -}}true{{- end -}}{{- end -}}
{{- define "immich.valkeyHost" -}}{{- if include "immich.valkeyInternalEnabled" . -}}{{- if eq .Values.valkey.architecture "replication" -}}{{ include "immich.valkeyFullname" . }}-primary{{- else if or (eq .Values.valkey.architecture "standalone") (eq .Values.valkey.architecture "cluster") -}}{{ include "immich.valkeyFullname" . }}-client{{- else -}}{{- fail "Immich internal cache supports valkey.architecture=standalone, replication, or cluster" -}}{{- end -}}{{- else -}}{{ .Values.valkey.external.host }}{{- end -}}{{- end -}}
{{- define "immich.valkeyPort" -}}{{- if include "immich.valkeyInternalEnabled" . -}}{{ .Values.valkey.service.ports.redis | default 6379 }}{{- else -}}{{ .Values.valkey.external.port }}{{- end -}}{{- end -}}
{{- define "immich.redisSecretName" -}}{{- if include "immich.valkeyInternalEnabled" . -}}{{- if .Values.valkey.auth.existingSecret -}}{{ .Values.valkey.auth.existingSecret }}{{- else -}}{{ include "immich.valkeyFullname" . }}-auth{{- end -}}{{- else if .Values.valkey.external.existingSecret -}}{{ .Values.valkey.external.existingSecret }}{{- else -}}{{ include "immich.fullname" . }}-redis{{- end -}}{{- end -}}
{{- define "immich.redisSecretKey" -}}{{- if include "immich.valkeyInternalEnabled" . -}}{{ .Values.valkey.auth.existingSecretPasswordKey | default "valkey-password" }}{{- else if .Values.valkey.external.existingSecret -}}{{ .Values.valkey.external.existingSecretPasswordKey }}{{- else -}}redis-password{{- end -}}{{- end -}}
{{- define "immich.hasRedisPassword" -}}{{- if or (and (include "immich.valkeyInternalEnabled" .) .Values.valkey.auth.enabled) .Values.valkey.external.password .Values.valkey.external.existingSecret -}}true{{- end -}}{{- end -}}
{{- define "immich.mlUrl" -}}http://{{ include "immich.fullname" . }}-machine-learning:{{ .Values.machineLearning.service.port }}{{- end -}}

{{- define "immich.validate" -}}
{{- $serverScaled := or .Values.autoscaling.enabled (gt (.Values.server.replicaCount | int) 1) -}}
{{- if and .Values.server.persistence.enabled $serverScaled (not (has "ReadWriteMany" .Values.server.persistence.accessModes)) -}}
{{- fail "server persistence requires ReadWriteMany accessModes when server replicas or autoscaling are enabled" -}}
{{- end -}}
{{- if and .Values.machineLearning.enabled .Values.machineLearning.persistence.enabled (gt (.Values.machineLearning.replicaCount | int) 1) (not (has "ReadWriteMany" .Values.machineLearning.persistence.accessModes)) -}}
{{- fail "machineLearning persistence requires ReadWriteMany accessModes when machineLearning.replicaCount is greater than 1" -}}
{{- end -}}
{{- if and (include "immich.databaseInternalEnabled" .) (ne .Values.postgresql.auth.username "postgres") -}}
{{- fail "internal PostgreSQL for Immich requires postgresql.auth.username=postgres so the app user owns the database" -}}
{{- end -}}
{{- if and (not (include "immich.databaseInternalEnabled" .)) (not .Values.database.external.password) (not .Values.database.external.existingSecret) -}}
{{- fail "external database requires database.external.password or database.external.existingSecret" -}}
{{- end -}}
{{- if and (not (include "immich.databaseInternalEnabled" .)) (not .Values.database.external.host) -}}
{{- fail "external database requires database.external.host" -}}
{{- end -}}
{{- if and (not (include "immich.valkeyInternalEnabled" .)) (not .Values.valkey.external.host) -}}
{{- fail "external cache requires valkey.external.host" -}}
{{- end -}}
{{- end -}}
