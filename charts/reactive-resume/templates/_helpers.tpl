{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "reactive-resume.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "reactive-resume.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "reactive-resume.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "reactive-resume.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "reactive-resume.selectorLabels" -}}
app.kubernetes.io/name: {{ include "reactive-resume.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "reactive-resume.environment" -}}
- {name: NODE_ENV, value: production}
- {name: HOME, value: /tmp}
- {name: APP_URL, value: {{ include "reactive-resume.publicUrl" . | quote }}}
{{- if .Values.oauth.enabled }}
- {name: OAUTH_PROVIDER_NAME, value: {{ .Values.oauth.name | quote }}}
- {name: OAUTH_CLIENT_ID, value: {{ .Values.oauth.clientId | quote }}}
- {name: OAUTH_AUTHORIZATION_URL, value: {{ .Values.oauth.authorizationUrl | quote }}}
- {name: OAUTH_TOKEN_URL, value: {{ .Values.oauth.tokenUrl | quote }}}
- {name: OAUTH_USER_INFO_URL, value: {{ .Values.oauth.userInfoUrl | quote }}}
- {name: OAUTH_SCOPES, value: {{ .Values.oauth.scopes | quote }}}
- name: OAUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef: {name: {{ .Values.oauth.existingSecret }}, key: {{ .Values.oauth.clientSecretKey }}}
{{- if .Values.oauth.caSecret }}
- {name: HF_OAUTH_CA, value: /oauth-ca/ca.crt}
{{- end }}
{{- end }}
{{- if eq .Values.storage.driver "s3" }}
- {name: S3_BUCKET, value: {{ .Values.storage.s3.bucket | quote }}}
- {name: S3_REGION, value: {{ .Values.storage.s3.region | quote }}}
- {name: S3_FORCE_PATH_STYLE, value: {{ .Values.storage.s3.forcePathStyle | quote }}}
{{- with .Values.storage.s3.endpoint }}
- {name: S3_ENDPOINT, value: {{ . | quote }}}
{{- end }}
- name: S3_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret }}, key: {{ .Values.storage.s3.accessKeyIdKey }}}
- name: S3_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret }}, key: {{ .Values.storage.s3.secretAccessKeyKey }}}
{{- if .Values.storage.s3.caSecret }}
- {name: HF_S3_CA, value: /s3-ca/ca.crt}
{{- end }}
{{- end }}
- {name: HF_DATABASE_HOST, value: {{ include "reactive-resume.databaseHost" . | quote }}}
- {name: HF_DATABASE_PORT, value: {{ ternary (get (.Values.postgresql.service | default dict) "port" | default 5432) .Values.database.port .Values.postgresql.enabled | quote }}}
- {name: HF_DATABASE_NAME, value: {{ ternary .Values.postgresql.auth.database .Values.database.name .Values.postgresql.enabled | quote }}}
- {name: HF_DATABASE_USERNAME, value: {{ ternary .Values.postgresql.auth.username .Values.database.username .Values.postgresql.enabled | quote }}}
- {name: HF_DATABASE_TLS, value: {{ and (not .Values.postgresql.enabled) .Values.database.tls.enabled | quote }}}
- name: HF_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "reactive-resume.databasePasswordSecret" . }}
      key: {{ ternary .Values.postgresql.auth.existingSecretUserPasswordKey .Values.database.passwordKey .Values.postgresql.enabled }}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: HF_DATABASE_CA, value: /postgres-ca/ca.crt}
{{- end }}
{{- range $key := list "AUTH_SECRET" "ENCRYPTION_SECRET" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef: {name: {{ include "reactive-resume.identitySecretName" $ }}, key: {{ $key }}}
{{- end }}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- if .Values.smtp.enabled }}
- {name: SMTP_HOST, value: {{ .Values.smtp.host | quote }}}
- {name: SMTP_PORT, value: {{ .Values.smtp.port | quote }}}
- {name: SMTP_FROM, value: {{ .Values.smtp.from | quote }}}
- {name: SMTP_USER, value: {{ .Values.smtp.username | quote }}}
- {name: SMTP_SECURE, value: "true"}
- name: SMTP_PASS
  valueFrom:
    secretKeyRef: {name: {{ .Values.smtp.existingSecret }}, key: {{ .Values.smtp.passwordKey }}}
{{- if .Values.smtp.tls.caSecret }}
- {name: HF_SMTP_CA, value: /smtp-ca/ca.crt}
{{- end }}
{{- end }}
{{- end -}}
{{- define "reactive-resume.mounts" -}}
- {name: data, mountPath: /app/data}
- {name: tmp, mountPath: /tmp}
- {name: runtime, mountPath: /helmforge, readOnly: true}
{{- if and .Values.oauth.enabled .Values.oauth.caSecret }}
- {name: oauth-ca, mountPath: /oauth-ca, readOnly: true}
{{- end }}
{{- if and (eq .Values.storage.driver "s3") .Values.storage.s3.caSecret }}
- {name: s3-ca, mountPath: /s3-ca, readOnly: true}
{{- end }}
{{- if and .Values.smtp.enabled .Values.smtp.tls.caSecret }}
- {name: smtp-ca, mountPath: /smtp-ca, readOnly: true}
{{- end }}
{{- if and (not .Values.postgresql.enabled) .Values.database.tls.caSecret }}
- {name: postgres-ca, mountPath: /postgres-ca, readOnly: true}
{{- end }}
{{- end -}}
{{- define "reactive-resume.labels" -}}
helm.sh/chart: {{ include "reactive-resume.chart" . }}
{{ include "reactive-resume.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "reactive-resume.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "reactive-resume.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "reactive-resume.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}




{{- define "reactive-resume.claimName" -}}{{- default (include "reactive-resume.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "reactive-resume.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "reactive-resume.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "reactive-resume.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "reactive-resume.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "bootstrap") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "reactive-resume.httpRouteName" -}}{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "reactive-resume.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "reactive-resume.fullname" .root }}{{- end -}}{{- end -}}
{{- define "reactive-resume.publicUrl" -}}{{- default (printf "http://%s.%s.svc:%v" (include "reactive-resume.fullname" .) .Release.Namespace .Values.service.port) .Values.server.publicUrl -}}{{- end -}}
{{- define "reactive-resume.databaseHost" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.primaryServiceName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.host }}{{- end -}}{{- end -}}
{{- define "reactive-resume.databasePasswordSecret" -}}{{- if .Values.postgresql.enabled -}}{{ include "postgresql.secretName" .Subcharts.postgresql }}{{- else -}}{{ .Values.database.passwordSecret }}{{- end -}}{{- end -}}
{{- define "reactive-resume.identitySecretName" -}}{{ default (printf "%s-identity" (include "reactive-resume.fullname" . | trunc 53 | trimSuffix "-")) .Values.identity.existingSecret }}{{- end -}}
{{- define "reactive-resume.validate" -}}
{{- if and .Values.oauth.enabled (not (and .Values.oauth.clientId .Values.oauth.existingSecret .Values.oauth.authorizationUrl .Values.oauth.tokenUrl .Values.oauth.userInfoUrl (hasPrefix "https://" .Values.server.publicUrl))) -}}{{ fail "OAuth requires HTTPS public URL, explicit provider endpoints, client ID and Secret" }}{{- end -}}
{{- if and (not .Values.oauth.enabled) (or .Values.oauth.clientId .Values.oauth.existingSecret .Values.oauth.authorizationUrl .Values.oauth.tokenUrl .Values.oauth.userInfoUrl .Values.oauth.caSecret) -}}{{ fail "OAuth connection settings require oauth.enabled" }}{{- end -}}
{{- if and (eq .Values.storage.driver "s3") (not (and .Values.storage.s3.bucket .Values.storage.s3.existingSecret)) -}}{{ fail "S3 requires an existing bucket and credential Secret" }}{{- end -}}
{{- if and (eq .Values.storage.driver "local") (or .Values.storage.s3.bucket .Values.storage.s3.endpoint .Values.storage.s3.existingSecret .Values.storage.s3.caSecret) -}}{{ fail "S3 connection settings require storage.driver=s3" }}{{- end -}}
{{- if and .Values.smtp.enabled (not (and .Values.smtp.host .Values.smtp.from .Values.smtp.username .Values.smtp.existingSecret)) -}}{{ fail "SMTP requires a TLS hostname, sender, username and existing password Secret" }}{{- end -}}
{{- if and (not .Values.smtp.enabled) (or .Values.smtp.host .Values.smtp.existingSecret .Values.smtp.tls.caSecret) -}}{{ fail "SMTP connection settings require smtp.enabled" }}{{- end -}}
{{- if not .Values.networkPolicy.egressIsolation -}}{{ fail "Private native enrollment requires egress isolation" }}{{- end -}}
{{- if and .Values.ingress.enabled .Values.gatewayAPI.enabled -}}{{ fail "Select Ingress or Gateway API exposure" }}{{- end -}}
{{- range $key, $value := .Values.podLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail "Pod labels cannot replace chart workload selectors" }}{{- end -}}{{- end -}}
{{- range $key, $value := .Values.commonLabels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/managed-by" "helm.sh/chart") -}}{{ fail "Common labels cannot replace chart ownership labels" }}{{- end -}}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Reactive Resume requires one replica with serialized native migrations" }}{{- end -}}
{{- if not .Values.networkPolicy.enabled -}}{{ fail "Private native enrollment requires an enforcing NetworkPolicy implementation" }}{{- end -}}
{{- if not .Values.persistence.enabled -}}{{ fail "Retained local storage and identity require persistence" }}{{- end -}}
{{- if ne (int .Values.server.port) 3000 -}}{{ fail "The public proxy uses fixed port 3000; private admission ports are not configurable" }}{{- end -}}
{{- if and .Values.postgresql.enabled (or .Values.database.host .Values.database.passwordSecret .Values.database.tls.caSecret) -}}{{ fail "Bundled and external PostgreSQL settings conflict" }}{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not (and .Values.database.host .Values.database.passwordSecret)) -}}{{ fail "External PostgreSQL requires host and passwordSecret" }}{{- end -}}
{{- if and .Values.postgresql.enabled (ne .Values.postgresql.architecture "standalone") -}}{{ fail "Bundled PostgreSQL currently requires standalone topology" }}{{- end -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.tls.enabled -}}{{ fail "Use the verified external PostgreSQL TLS contract for database TLS" }}{{- end -}}
{{- if and .Values.database.tls.caSecret (not .Values.database.tls.enabled) -}}{{ fail "PostgreSQL CA requires TLS enabled" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if regexMatch "^(DATABASE_|PG|AUTH_|ENCRYPTION_|APP_URL|PORT|SERVER_PORT|FLAG_|BETTER_AUTH_|LOCAL_STORAGE_|S3_|SMTP_|REDIS_|OAUTH_|GOOGLE_|GITHUB_|LINKEDIN_|HF_|NODE_|HOME$)" .name -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
