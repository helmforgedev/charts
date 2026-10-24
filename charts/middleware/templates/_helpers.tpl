{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "middleware.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "middleware.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "middleware.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "middleware.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "middleware.labels" -}}
helm.sh/chart: {{ include "middleware.chart" . }}
{{ include "middleware.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "middleware.selectorLabels" -}}
app.kubernetes.io/name: {{ include "middleware.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "middleware.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "middleware.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "middleware.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Validate chart-owned contracts before rendering workloads. */}}
{{- define "middleware.validate" -}}
{{- if has .Values.image.tag (list "latest" "stable" "main" "master" "edge") -}}
{{- fail "image.tag must be an immutable release tag" -}}
{{- end -}}
{{- if eq .Values.middleware.internalDbEnabled "true" -}}
{{- fail "middleware.internalDbEnabled must remain \"false\"; the chart uses PostgreSQL as a separate workload" -}}
{{- end -}}
{{- if ne .Values.middleware.internalRedisEnabled "true" -}}
{{- fail "middleware.internalRedisEnabled must remain \"true\"; Middleware 0.3.1 only supports its loopback Redis runtime safely" -}}
{{- end -}}
{{- if .Values.redis.enabled -}}
{{- fail "redis.enabled is unsupported by Middleware 0.3.1 because its remote Redis client cannot authenticate and forces TLS; use the embedded Redis runtime" -}}
{{- end -}}
{{- if .Values.externalRedis.enabled -}}
{{- fail "externalRedis.enabled is unsupported by Middleware 0.3.1 because its remote Redis client cannot authenticate and forces TLS" -}}
{{- end -}}
{{- if and .Values.postgresql.enabled .Values.externalDatabase.enabled -}}
{{- fail "postgresql.enabled and externalDatabase.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not .Values.externalDatabase.enabled) -}}
{{- fail "enable exactly one database mode: postgresql.enabled or externalDatabase.enabled" -}}
{{- end -}}
{{- if .Values.externalDatabase.enabled -}}
  {{- if not .Values.externalDatabase.host -}}
  {{- fail "externalDatabase.host is required when externalDatabase.enabled=true" -}}
  {{- end -}}
  {{- if and .Values.externalDatabase.password .Values.externalDatabase.existingSecret -}}
  {{- fail "set only one external database credential source: password or existingSecret" -}}
  {{- end -}}
  {{- if and (not .Values.externalDatabase.password) (not .Values.externalDatabase.existingSecret) -}}
  {{- fail "externalDatabase.password or externalDatabase.existingSecret is required when externalDatabase.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.ingress.enabled (eq (len .Values.ingress.hosts) 0) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
  {{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}
  {{- fail (printf "podLabels must not override reserved selector label %q" $key) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL subchart fullname, mirrored for deterministic parent wiring. */}}
{{- define "middleware.postgresqlFullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "postgresql" .Values.postgresql.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "middleware.externalDatabaseSecretName" -}}
{{- printf "%s-external-database" (include "middleware.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Render the chart-managed external database Secret. */}}
{{- define "middleware.externalDatabaseSecret" -}}
{{- if and .Values.externalDatabase.enabled .Values.externalDatabase.password (not .Values.externalDatabase.existingSecret) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "middleware.externalDatabaseSecretName" . }}
  labels:
    {{- include "middleware.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{ .Values.externalDatabase.existingSecretPasswordKey | default "user-password" }}: {{ .Values.externalDatabase.password | quote }}
{{- end }}
{{- end -}}

{{/* PostgreSQL host */}}
{{- define "middleware.dbHost" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.host -}}
{{- else -}}
{{- if eq (default "standalone" .Values.postgresql.architecture) "replication" -}}
{{- printf "%s-primary" (include "middleware.postgresqlFullname" .) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "middleware.postgresqlFullname" . -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL port */}}
{{- define "middleware.dbPort" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.port | toString -}}
{{- else -}}
{{- "5432" -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL database name */}}
{{- define "middleware.dbName" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL user */}}
{{- define "middleware.dbUser" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.user -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL secret name */}}
{{- define "middleware.dbSecretName" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- default (include "middleware.externalDatabaseSecretName" .) .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else if and .Values.postgresql.externalSecrets.enabled .Values.postgresql.externalSecrets.auth.enabled -}}
{{- default (printf "%s-auth" (include "middleware.postgresqlFullname" .)) .Values.postgresql.externalSecrets.auth.targetName -}}
{{- else -}}
{{- printf "%s-auth" (include "middleware.postgresqlFullname" .) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL secret password key */}}
{{- define "middleware.dbSecretPasswordKey" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.existingSecretPasswordKey | default "user-password" -}}
{{- else -}}
{{- .Values.postgresql.auth.existingSecretUserPasswordKey | default "user-password" -}}
{{- end -}}
{{- end -}}

{{/* PostgreSQL SSL mode. */}}
{{- define "middleware.dbSslMode" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.sslMode -}}
{{- else if .Values.postgresql.tls.enabled -}}
{{- .Values.postgresql.tls.sslMode | default "require" -}}
{{- else -}}
{{- "disable" -}}
{{- end -}}
{{- end -}}

{{/* Shared database environment for migrations and the application. */}}
{{- define "middleware.databaseEnv" -}}
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "middleware.dbSecretName" . }}
      key: {{ include "middleware.dbSecretPasswordKey" . }}
- name: DB_HOST
  value: {{ include "middleware.dbHost" . | quote }}
- name: DB_PORT
  value: {{ include "middleware.dbPort" . | quote }}
- name: DB_NAME
  value: {{ include "middleware.dbName" . | quote }}
- name: DB_USER
  value: {{ include "middleware.dbUser" . | quote }}
- name: PGSSLMODE
  value: {{ include "middleware.dbSslMode" . | quote }}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "middleware.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "middleware.fullname" .) -}}
{{- end -}}
{{- end -}}
