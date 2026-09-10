{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "memos.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "memos.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "memos.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "memos.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "memos.selectorLabels" -}}
app.kubernetes.io/name: {{ include "memos.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "memos.labels" -}}
helm.sh/chart: {{ include "memos.chart" . }}
{{ include "memos.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "memos.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "memos.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "memos.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "memos.databaseSecretName" -}}{{- default (printf "%s-database" (include "memos.fullname" .)) .Values.database.existingSecret -}}{{- end -}}

{{- define "memos.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "memos.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "memos.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "memos.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "memos.databaseComponents" -}}{{- if or .Values.postgresql.enabled .Values.mysql.enabled .Values.database.host -}}true{{- end -}}{{- end -}}
{{- define "memos.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else if .Values.mysql.enabled -}}{{ include "mysql.sourceServiceName" .Subcharts.mysql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "memos.databasePort" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.service.port }}{{- else if .Values.mysql.enabled -}}{{ .Values.mysql.service.port }}{{- else -}}{{ .Values.database.port | default (ternary 5432 3306 (eq .Values.database.driver "postgres")) }}{{- end -}}{{- end -}}
{{- define "memos.databaseName" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else if .Values.mysql.enabled -}}{{ .Values.mysql.auth.database }}{{- else -}}{{ .Values.database.name }}{{- end -}}{{- end -}}
{{- define "memos.databaseUser" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else if .Values.mysql.enabled -}}{{ .Values.mysql.auth.username }}{{- else -}}{{ .Values.database.username }}{{- end -}}{{- end -}}
{{- define "memos.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else if .Values.mysql.enabled -}}{{ include "mysql.secretName" .Subcharts.mysql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "memos.databasePasswordKey" -}}{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.existingSecretUserPasswordKey }}{{- else if .Values.mysql.enabled -}}{{ .Values.mysql.auth.existingSecretUserPasswordKey }}{{- else -}}{{ .Values.database.passwordKey }}{{- end -}}{{- end -}}
{{- define "memos.validate" -}}
{{- if and .Values.pdb.enabled (lt (int .Values.replicaCount) 2) -}}{{ fail "A Memos PodDisruptionBudget requires at least two SQL-backed replicas with shared storage" }}{{- end -}}
{{- if and .Values.postgresql.enabled .Values.mysql.enabled -}}{{ fail "Enable only one Memos database subchart" }}{{- end -}}
{{- if or (and .Values.postgresql.enabled (ne .Values.database.driver "postgres")) (and .Values.mysql.enabled (ne .Values.database.driver "mysql")) -}}{{ fail "database.driver must match the enabled database subchart" }}{{- end -}}
{{- if and (include "memos.databaseComponents" .) (or .Values.database.dsn .Values.database.existingSecret) -}}{{ fail "Database components and complete DSN sources are mutually exclusive" }}{{- end -}}
{{- if and .Values.database.dsn .Values.database.existingSecret -}}{{ fail "database.dsn and database.existingSecret are mutually exclusive" }}{{- end -}}
{{- if and (or .Values.postgresql.enabled .Values.mysql.enabled) (or .Values.database.host .Values.database.passwordSecret) -}}{{ fail "Bundled database credentials cannot be combined with external host or passwordSecret" }}{{- end -}}
{{- if and .Values.database.host (or (eq .Values.database.driver "sqlite") (not .Values.database.passwordSecret)) -}}{{ fail "External database components require a SQL driver and database.passwordSecret" }}{{- end -}}
{{- if and (include "memos.databaseComponents" .) (or .Values.app.command .Values.app.args) -}}{{ fail "Database components require the native Memos command" }}{{- end -}}
{{- range concat .Values.app.env .Values.app.extraEnv -}}
{{- if has .name (list "MEMOS_PORT" "MEMOS_DATA" "MEMOS_DRIVER" "MEMOS_DSN" "MEMOS_ADDR" "MEMOS_INSTANCE_URL" "MEMOS_DEMO" "MEMOS_LOG_LEVEL" "MEMOS_ALLOW_PRIVATE_WEBHOOKS" "BOOTSTRAP_USERNAME" "BOOTSTRAP_DISPLAY_NAME") -}}
{{- fail (printf "app.env and app.extraEnv must not override chart-managed variable %s" .name) -}}
{{- end -}}
{{- end -}}
{{- if and .Values.bootstrap.existingSecret .Values.bootstrap.password -}}{{ fail "bootstrap.existingSecret and bootstrap.password are mutually exclusive" }}{{- end -}}
{{- if and .Values.bootstrap.enabled (or .Values.app.command .Values.app.args) -}}{{ fail "Protected bootstrap requires the native Memos command; disable bootstrap for explicit command or argument overrides" }}{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (eq .Values.database.driver "sqlite") -}}
{{- fail "replicaCount > 1 requires database.driver=mysql or database.driver=postgres because SQLite cannot safely share state across Memos pods" -}}
{{- end -}}
{{- if and (ne .Values.database.driver "sqlite") (not (or .Values.database.dsn .Values.database.existingSecret (include "memos.databaseComponents" .))) -}}
{{- fail "database.dsn or database.existingSecret is required when database.driver is mysql or postgres" -}}
{{- end -}}
{{- if and (ne .Values.database.driver "sqlite") (not .Values.persistence.enabled) (not .Values.persistence.existingClaim) -}}
{{- fail "persistence.enabled or persistence.existingClaim is required with external databases because Memos still stores local assets in MEMOS_DATA" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (ne .Values.database.driver "sqlite") (not .Values.persistence.existingClaim) -}}
{{- fail "replicaCount > 1 with mysql or postgres requires persistence.existingClaim backed by shared storage because generated StatefulSet PVCs are per-pod and Memos can store local assets in MEMOS_DATA" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- range $key := (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}
{{- if hasKey $podLabels $key -}}
{{- fail (printf "podLabels must not override the selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "memos.nativeEnvironment" -}}
- name: MEMOS_PORT
  value: {{ .Values.app.port | quote }}
- name: MEMOS_DATA
  value: {{ .Values.persistence.mountPath | quote }}
- name: MEMOS_DRIVER
  value: {{ .Values.database.driver | quote }}
- name: MEMOS_LOG_LEVEL
  value: {{ .Values.memos.logLevel | quote }}
{{- if .Values.memos.addr }}
- name: MEMOS_ADDR
  value: {{ .Values.memos.addr | quote }}
{{- end }}
{{- if .Values.memos.instanceUrl }}
- name: MEMOS_INSTANCE_URL
  value: {{ .Values.memos.instanceUrl | quote }}
{{- end }}
- name: MEMOS_DEMO
  value: {{ .Values.memos.demo | quote }}
- name: MEMOS_ALLOW_PRIVATE_WEBHOOKS
  value: {{ .Values.memos.allowPrivateWebhooks | quote }}
{{- if or .Values.database.dsn .Values.database.existingSecret }}
- name: MEMOS_DSN
  valueFrom:
    secretKeyRef:
      name: {{ include "memos.databaseSecretName" . }}
      key: {{ .Values.database.existingSecretKey | quote }}
{{- end }}
{{- if .Values.database.caSecret }}
- {name: SSL_CERT_FILE, value: /database-ca/ca.crt}
{{- end }}
{{- range .Values.app.env }}
- name: {{ .name }}
  {{- if hasKey . "valueFrom" }}
  valueFrom:
    {{- toYaml .valueFrom | nindent 4 }}
  {{- else }}
  value: {{ default "" .value | quote }}
  {{- end }}
{{- end }}
{{- with .Values.app.extraEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end -}}
