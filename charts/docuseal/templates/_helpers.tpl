{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "docuseal.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "docuseal.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "docuseal.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "docuseal.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "docuseal.labels" -}}
helm.sh/chart: {{ include "docuseal.chart" . }}
app.kubernetes.io/name: {{ include "docuseal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: docuseal
{{- with .Values.commonLabels }}
{{ toYaml . | nindent 0 }}
{{- end }}
{{- end -}}
{{- define "docuseal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "docuseal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "docuseal.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "docuseal.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "docuseal.image" -}}{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}{{- end -}}
{{- define "docuseal.secretName" -}}{{- default (printf "%s-application" (include "docuseal.fullname" .)) .Values.docuseal.existingSecret -}}{{- end -}}
{{- define "docuseal.pvcName" -}}{{- default (include "docuseal.fullname" .) .Values.storage.persistence.existingClaim -}}{{- end -}}
{{- define "docuseal.postgresqlFullname" -}}{{- if .Values.postgresql.fullnameOverride -}}{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (default "postgresql" .Values.postgresql.nameOverride) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "docuseal.databaseHost" -}}{{- ternary .Values.database.external.host (include "docuseal.postgresqlFullname" .) .Values.database.external.enabled -}}{{- end -}}
{{- define "docuseal.databasePort" -}}{{- ternary .Values.database.external.port 5432 .Values.database.external.enabled -}}{{- end -}}
{{- define "docuseal.databaseName" -}}{{- ternary .Values.database.external.database .Values.postgresql.auth.database .Values.database.external.enabled -}}{{- end -}}
{{- define "docuseal.databaseUser" -}}{{- ternary .Values.database.external.username .Values.postgresql.auth.username .Values.database.external.enabled -}}{{- end -}}
{{- define "docuseal.databaseSecretName" -}}{{- if .Values.database.external.enabled -}}{{- .Values.database.external.existingSecret -}}{{- else if .Values.postgresql.auth.existingSecret -}}{{- .Values.postgresql.auth.existingSecret -}}{{- else -}}{{- printf "%s-auth" (include "docuseal.postgresqlFullname" .) -}}{{- end -}}{{- end -}}
{{- define "docuseal.databaseSecretKey" -}}{{- if .Values.database.external.enabled -}}{{- .Values.database.external.passwordKey -}}{{- else -}}{{- default "user-password" .Values.postgresql.auth.existingSecretUserPasswordKey -}}{{- end -}}{{- end -}}
{{- define "docuseal.redisFullname" -}}{{- if .Values.redis.fullnameOverride -}}{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (default "redis" .Values.redis.nameOverride) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "docuseal.redisHost" -}}{{- if .Values.redisExternal.enabled -}}{{- .Values.redisExternal.host -}}{{- else -}}{{- printf "%s-client" (include "docuseal.redisFullname" .) -}}{{- end -}}{{- end -}}
{{- define "docuseal.redisPort" -}}{{- ternary .Values.redisExternal.port 6379 .Values.redisExternal.enabled -}}{{- end -}}
{{- define "docuseal.redisDatabase" -}}{{- ternary .Values.redisExternal.database 0 .Values.redisExternal.enabled -}}{{- end -}}
{{- define "docuseal.redisSecretName" -}}{{- if .Values.redisExternal.enabled -}}{{- .Values.redisExternal.existingSecret -}}{{- else if .Values.redis.auth.existingSecret -}}{{- .Values.redis.auth.existingSecret -}}{{- else -}}{{- printf "%s-auth" (include "docuseal.redisFullname" .) -}}{{- end -}}{{- end -}}
{{- define "docuseal.redisSecretKey" -}}{{- if .Values.redisExternal.enabled -}}{{- .Values.redisExternal.passwordKey -}}{{- else -}}{{- default "redis-password" .Values.redis.auth.existingSecretPasswordKey -}}{{- end -}}{{- end -}}

{{- define "docuseal.env" -}}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.secretName" .root }}
      key: {{ .root.Values.docuseal.secretKeyBaseKey }}
- name: ENCRYPTION_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.secretName" .root }}
      key: {{ .root.Values.docuseal.encryptionSecretKey }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.databaseSecretName" .root }}
      key: {{ include "docuseal.databaseSecretKey" .root }}
- name: DATABASE_URL
  value: {{ printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%v/%s" (include "docuseal.databaseUser" .root) (include "docuseal.databaseHost" .root) (include "docuseal.databasePort" .root) (include "docuseal.databaseName" .root) | quote }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.redisSecretName" .root }}
      key: {{ include "docuseal.redisSecretKey" .root }}
- name: REDIS_URL
  value: {{ printf "redis://:$(REDIS_PASSWORD)@%s:%v/%v" (include "docuseal.redisHost" .root) (include "docuseal.redisPort" .root) (include "docuseal.redisDatabase" .root) | quote }}
- name: RUN_MIGRATIONS
  value: {{ .runMigrations | quote }}
- name: APP_URL
  value: {{ trimSuffix "/" .root.Values.docuseal.appUrl | quote }}
- name: FORCE_SSL
  value: {{ .root.Values.docuseal.forceSsl | quote }}
- name: RAILS_MAX_THREADS
  value: {{ .root.Values.docuseal.railsMaxThreads | quote }}
- name: SIDEKIQ_THREADS
  value: {{ .root.Values.docuseal.sidekiqThreads | quote }}
- name: BOOTSNAP_READONLY
  value: "1"
- name: HOME
  value: /tmp
{{- if eq .root.Values.storage.type "s3" }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.secretName" .root }}
      key: {{ .root.Values.storage.s3.accessKeyIdKey }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.secretName" .root }}
      key: {{ .root.Values.storage.s3.secretAccessKeyKey }}
- name: AWS_REGION
  value: {{ .root.Values.storage.s3.region | quote }}
- name: S3_ATTACHMENTS_BUCKET
  value: {{ .root.Values.storage.s3.bucket | quote }}
- name: S3_ENDPOINT
  value: {{ .root.Values.storage.s3.endpoint | quote }}
- name: ACTIVE_STORAGE_PUBLIC
  value: {{ .root.Values.storage.s3.public | quote }}
{{- end }}
{{- if .root.Values.smtp.enabled }}
- name: SMTP_ADDRESS
  value: {{ .root.Values.smtp.address | quote }}
- name: SMTP_PORT
  value: {{ .root.Values.smtp.port | quote }}
- name: SMTP_DOMAIN
  value: {{ .root.Values.smtp.domain | quote }}
- name: SMTP_USERNAME
  value: {{ .root.Values.smtp.username | quote }}
- name: SMTP_FROM
  value: {{ .root.Values.smtp.from | quote }}
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "docuseal.secretName" .root }}
      key: {{ .root.Values.smtp.passwordKey }}
- name: SMTP_ENABLE_STARTTLS
  value: {{ .root.Values.smtp.starttls | quote }}
{{- end }}
{{- end -}}

{{- define "docuseal.validate" -}}
{{- if eq .Values.postgresql.enabled .Values.database.external.enabled -}}{{- fail "exactly one of postgresql.enabled or database.external.enabled must be true" -}}{{- end -}}
{{- if eq .Values.redis.enabled .Values.redisExternal.enabled -}}{{- fail "exactly one of redis.enabled or redisExternal.enabled must be true" -}}{{- end -}}
{{- if and .Values.database.external.enabled (or (not .Values.database.external.host) (not .Values.database.external.existingSecret)) -}}{{- fail "external PostgreSQL requires database.external.host and existingSecret" -}}{{- end -}}
{{- if and .Values.redisExternal.enabled (or (not .Values.redisExternal.host) (not .Values.redisExternal.existingSecret)) -}}{{- fail "external Redis requires redisExternal.host and existingSecret" -}}{{- end -}}
{{- if and (eq .Values.storage.type "local") (not .Values.storage.persistence.enabled) -}}{{- fail "local storage requires storage.persistence.enabled=true" -}}{{- end -}}
{{- if and (eq .Values.storage.type "s3") (or (not .Values.storage.s3.bucket) (not .Values.docuseal.existingSecret)) -}}{{- fail "S3 storage requires storage.s3.bucket and docuseal.existingSecret" -}}{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (or .Values.postgresql.enabled .Values.redis.enabled (ne .Values.storage.type "s3") (not .Values.docuseal.existingSecret)) -}}{{- fail "replicaCount greater than one requires external PostgreSQL, external Redis, S3 storage, and docuseal.existingSecret" -}}{{- end -}}
{{- if and .Values.networkPolicy.enabled .Values.database.external.enabled (not .Values.database.external.networkPolicyPeers) (not .Values.networkPolicy.extraEgress) -}}{{- fail "external PostgreSQL requires networkPolicyPeers or networkPolicy.extraEgress" -}}{{- end -}}
{{- if and .Values.networkPolicy.enabled .Values.redisExternal.enabled (not .Values.redisExternal.networkPolicyPeers) (not .Values.networkPolicy.extraEgress) -}}{{- fail "external Redis requires networkPolicyPeers or networkPolicy.extraEgress" -}}{{- end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled -}}{{- fail "ingress.enabled and gatewayAPI.enabled are mutually exclusive" -}}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{- fail "ingress.hosts must not be empty when ingress.enabled=true" -}}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (not .Values.gatewayAPI.httpRoutes) -}}{{- fail "gatewayAPI.httpRoutes must not be empty when gatewayAPI.enabled=true" -}}{{- end -}}
{{- if and .Values.smtp.enabled (or (not .Values.smtp.address) (not .Values.smtp.from) (not .Values.docuseal.existingSecret)) -}}{{- fail "SMTP requires smtp.address, smtp.from, and docuseal.existingSecret" -}}{{- end -}}
{{- if and .Values.externalSecrets.enabled (or (not .Values.docuseal.existingSecret) (not .Values.externalSecrets.secretStoreRef.name) (not .Values.externalSecrets.items)) -}}{{- fail "External Secrets requires docuseal.existingSecret, secretStoreRef.name, and items" -}}{{- end -}}
{{- range $key, $_ := (.Values.podLabels | default dict) }}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") }}{{- fail (printf "podLabels must not override selector label %q" $key) }}{{- end }}{{- end -}}
{{- end -}}
