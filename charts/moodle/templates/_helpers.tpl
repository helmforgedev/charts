{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "moodle.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "moodle.fullname" -}}
{{- if .Values.fullnameOverride -}}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if contains (include "moodle.name" .) .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name (include "moodle.name" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- define "moodle.nameWithSuffix" -}}{{ printf "%s%s" (.base | trunc (int (sub 63 (len .suffix))) | trimSuffix "-") .suffix }}{{- end -}}
{{- define "moodle.selectorLabels" -}}
app.kubernetes.io/name: {{ include "moodle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "moodle.chart" -}}{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "moodle.labels" -}}
helm.sh/chart: {{ include "moodle.chart" . }}
{{ include "moodle.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "moodle.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "moodle.fullname" .) .Values.serviceAccount.name }}
{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}
{{- define "moodle.image" -}}{{ printf "%s:%s@%s" .Values.image.repository .Values.image.tag .Values.image.digest }}{{- end -}}
{{- define "moodle.secretName" -}}{{ default (include "moodle.nameWithSuffix" (dict "base" (include "moodle.fullname" .) "suffix" "-admin")) .Values.moodle.existingSecret }}{{- end -}}
{{- define "moodle.dataClaim" -}}{{ default (include "moodle.nameWithSuffix" (dict "base" (include "moodle.fullname" .) "suffix" "-data")) .Values.persistence.existingClaim }}{{- end -}}
{{- define "moodle.dbHost" -}}
{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}
{{- end -}}
{{- define "moodle.dbName" -}}{{ if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.database }}{{ else }}{{ .Values.database.name }}{{ end }}{{- end -}}
{{- define "moodle.dbUser" -}}{{ if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.username }}{{ else }}{{ .Values.database.username }}{{ end }}{{- end -}}
{{- define "moodle.dbSecret" -}}{{ if .Values.postgresql.enabled }}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{ else }}{{ .Values.database.existingSecret }}{{ end }}{{- end -}}
{{- define "moodle.dbKey" -}}{{ if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{ else }}{{ .Values.database.existingSecretPasswordKey }}{{ end }}{{- end -}}
{{- define "moodle.redisHost" -}}{{ if .Values.redis.enabled }}{{ include "redis.clientServiceName" .Subcharts.redis }}{{ else }}{{ .Values.sessions.host }}{{ end }}{{- end -}}
{{- define "moodle.redisSecret" -}}{{ if .Values.redis.enabled }}{{ include "redis.secretName" .Subcharts.redis }}{{ else }}{{ .Values.sessions.existingSecret }}{{ end }}{{- end -}}
{{- define "moodle.redisKey" -}}{{ if .Values.redis.enabled }}{{ .Values.redis.auth.existingSecretPasswordKey }}{{ else }}{{ .Values.sessions.existingSecretPasswordKey }}{{ end }}{{- end -}}
{{- define "moodle.externalSecretName" -}}{{ if .item.fullnameOverride }}{{ .item.fullnameOverride }}{{ else if .item.name }}{{ include "moodle.nameWithSuffix" (dict "base" (include "moodle.fullname" .root) "suffix" (printf "-%s" .item.name)) }}{{ else }}{{ include "moodle.secretName" .root }}{{ end }}{{- end -}}
{{- define "moodle.httpRouteName" -}}{{ default (include "moodle.fullname" .root) .route.name }}{{- end -}}
{{- define "moodle.validate" -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) }}{{ fail "ingress.hosts must contain at least one host when ingress.enabled=true" }}{{ end -}}
{{- range $labels := list .Values.podLabels .Values.commonLabels -}}
{{- if or (hasKey $labels "app.kubernetes.io/name") (hasKey $labels "app.kubernetes.io/instance") }}{{ fail "podLabels and commonLabels must not override selector labels" }}{{ end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) }}{{ fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" }}{{ end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) }}{{ fail "gatewayAPI.httpRoutes must not be empty" }}{{ end -}}
{{- if not .Values.postgresql.enabled -}}
{{- if or (empty .Values.database.host) (empty .Values.database.existingSecret) }}{{ fail "External PostgreSQL requires database.host and database.existingSecret" }}{{ end -}}
{{- end -}}
{{- if and .Values.sessions.enabled (not .Values.redis.enabled) (empty .Values.sessions.host) }}{{ fail "Redis sessions require redis.enabled or sessions.host" }}{{ end -}}
{{- if and .Values.redis.enabled (or (not .Values.sessions.enabled) (ne .Values.redis.architecture "standalone")) }}{{ fail "Bundled Redis requires sessions.enabled=true and redis.architecture=standalone" }}{{ end -}}
{{- if or (gt (int .Values.replicaCount) 1) .Values.autoscaling.enabled -}}
{{- if or (not .Values.persistence.enabled) (not (has "ReadWriteMany" .Values.persistence.accessModes)) (not .Values.sessions.enabled) }}{{ fail "Multiple replicas and autoscaling require persistent ReadWriteMany moodledata and Redis sessions" }}{{ end -}}
{{- end -}}
{{- if and .Values.pdb.enabled (not .Values.autoscaling.enabled) (lt (int .Values.replicaCount) 2) }}{{ fail "pdb.enabled requires multiple replicas" }}{{ end -}}
{{- if and .Values.moodle.sslProxy (not (hasPrefix "https://" .Values.moodle.wwwroot)) }}{{ fail "moodle.sslProxy requires an HTTPS moodle.wwwroot" }}{{ end -}}
{{- if and (hasPrefix "verify-" .Values.database.sslMode) (empty .Values.database.tlsSecret) }}{{ fail "Verified PostgreSQL TLS requires database.tlsSecret" }}{{ end -}}
{{- if and (eq .Values.source.mode "archive") (empty .Values.source.sha256) }}{{ fail "source.sha256 is required for archive mode" }}{{ end -}}
{{- end -}}
