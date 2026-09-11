{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "papra.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "papra.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "papra.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "papra.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "papra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "papra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "papra.labels" -}}
helm.sh/chart: {{ include "papra.chart" . }}
{{ include "papra.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "papra.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "papra.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "papra.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "papra.authSecretName" -}}{{- default (printf "%s-auth" (include "papra.fullname" . | trunc 58 | trimSuffix "-")) .Values.auth.existingSecret -}}{{- end -}}
{{- define "papra.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "papra.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "papra.claimName" -}}{{- default (include "papra.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "papra.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "papra.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "auth") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "papra.validate" -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "Papra currently requires one writer with Recreate upgrades" }}{{- end -}}
{{- if and .Values.auth.secret .Values.auth.existingSecret -}}{{ fail "auth.secret and auth.existingSecret are mutually exclusive" }}{{- end -}}
{{- if and .Values.bootstrap.password .Values.bootstrap.existingSecret -}}{{ fail "bootstrap.password and bootstrap.existingSecret are mutually exclusive" }}{{- end -}}
{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}{{- if hasKey $.Values.podLabels $key -}}{{ fail (printf "podLabels must not override selector label %s" $key) }}{{- end -}}{{- end -}}
{{- if and .Values.database.remoteUrl .Values.database.encryptionSecret -}}{{ fail "Local database encryption is incompatible with remote libSQL" }}{{- end -}}
{{- if and .Values.database.remoteUrl (not .Values.database.authTokenSecret) -}}{{ fail "Remote libSQL requires database.authTokenSecret" }}{{- end -}}
{{- if and (not .Values.database.remoteUrl) .Values.database.authTokenSecret -}}{{ fail "database.authTokenSecret requires database.remoteUrl" }}{{- end -}}
{{- if and (eq .Values.storage.driver "s3") (not (and .Values.storage.s3.endpoint .Values.storage.s3.region .Values.storage.s3.bucket .Values.storage.s3.existingSecret)) -}}{{ fail "S3 requires endpoint, region, bucket and existingSecret" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if or (hasPrefix "AUTH_" .name) (hasPrefix "TASKS_" .name) (eq "PROCESS_MODE" .name) (hasPrefix "DATABASE_" .name) (hasPrefix "DOCUMENT_STORAGE_" .name) (has .name (list "PORT" "SERVER_HOSTNAME" "APP_BASE_URL" "SERVER_BASE_URL" "CLIENT_BASE_URL" "PAPRA_CONFIG_DIR" "HOME")) -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "papra.nativeEnvironment" -}}
- {name: PORT, value: {{ .Values.server.port | quote }}}
- {name: APP_BASE_URL, value: {{ .Values.server.publicUrl | quote }}}
- {name: SERVER_HOSTNAME, value: "0.0.0.0"}
- {name: DATABASE_URL, value: {{ .Values.database.remoteUrl | default "file:/app/app-data/db/db.sqlite" | quote }}}
{{- range $item := list (dict "env" "DATABASE_AUTH_TOKEN" "secret" .Values.database.authTokenSecret "key" .Values.database.authTokenKey) (dict "env" "DATABASE_ENCRYPTION_KEY" "secret" .Values.database.encryptionSecret "key" .Values.database.encryptionKey) (dict "env" "DOCUMENT_STORAGE_DOCUMENT_KEY_ENCRYPTION_KEYS" "secret" .Values.storage.encryptionSecret "key" .Values.storage.encryptionKey) }}
{{- if $item.secret }}
- name: {{ $item.env }}
  valueFrom:
    secretKeyRef: {name: {{ $item.secret | quote }}, key: {{ $item.key | quote }}}
{{- end }}{{- end }}
- {name: DOCUMENT_STORAGE_DRIVER, value: {{ .Values.storage.driver | quote }}}
- {name: DOCUMENT_STORAGE_ENCRYPTION_IS_ENABLED, value: {{ not (empty .Values.storage.encryptionSecret) | quote }}}
{{- if eq .Values.storage.driver "s3" }}
- {name: DOCUMENT_STORAGE_S3_FORCE_PATH_STYLE, value: {{ .Values.storage.s3.forcePathStyle | quote }}}
- {name: DOCUMENT_STORAGE_S3_ENDPOINT, value: {{ .Values.storage.s3.endpoint | quote }}}
- {name: DOCUMENT_STORAGE_S3_REGION, value: {{ .Values.storage.s3.region | quote }}}
- {name: DOCUMENT_STORAGE_S3_BUCKET_NAME, value: {{ .Values.storage.s3.bucket | quote }}}
- name: DOCUMENT_STORAGE_S3_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret | quote }}, key: {{ .Values.storage.s3.accessKeyIdKey | quote }}}
- name: DOCUMENT_STORAGE_S3_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef: {name: {{ .Values.storage.s3.existingSecret | quote }}, key: {{ .Values.storage.s3.secretAccessKeyKey | quote }}}
{{- end }}
- {name: DOCUMENT_STORAGE_FILESYSTEM_ROOT, value: /app/app-data/documents}
- {name: PAPRA_CONFIG_DIR, value: /app/app-data}
- {name: TASKS_PERSISTENCE_DRIVER, value: libsql}
- {name: TASKS_PERSISTENCE_DRIVERS_LIBSQL_URL, value: 'file:/app/app-data/db/tasks.sqlite'}
- {name: TASKS_PERSISTENCE_DRIVERS_LIBSQL_MIGRATE_WITH_PRAGMA, value: 'true'}
- {name: TASKS_PERSISTENCE_DRIVERS_LIBSQL_POLL_INTERVAL_MS, value: {{ .Values.tasks.pollIntervalMs | quote }}}
- {name: PROCESS_MODE, value: {{ ternary "all" "web" .Values.tasks.workerEnabled | quote }}}
- {name: AUTH_FIRST_USER_AS_ADMIN, value: "false"}
- {name: AUTH_IS_REGISTRATION_ENABLED, value: {{ .Values.auth.allowRegistration | quote }}}
- {name: AUTH_PROVIDERS_EMAIL_IS_ENABLED, value: "true"}
- {name: AUTH_IS_EMAIL_VERIFICATION_REQUIRED, value: "false"}
- {name: AUTH_IS_PASSWORD_RESET_ENABLED, value: "false"}
- {name: BETTER_AUTH_TELEMETRY, value: "0"}
- {name: HOME, value: /home/nonroot}
- {name: XDG_CACHE_HOME, value: /tmp/cache}
{{- if .Values.server.trustedCaSecret }}
- {name: NODE_EXTRA_CA_CERTS, value: /trusted-ca/ca.crt}
{{- end }}
- name: AUTH_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "papra.authSecretName" . }}
      key: {{ .Values.auth.secretKey }}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "papra.mounts" -}}
- {name: workspace, mountPath: /app/app-data}
- {name: tmp, mountPath: /tmp}
- {name: home, mountPath: /home/nonroot}
{{- if .Values.server.trustedCaSecret }}
- {name: trusted-ca, mountPath: /trusted-ca, readOnly: true}
{{- end }}
{{- end -}}

{{- define "papra.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "papra.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "papra.fullname" .root }}{{- end -}}
{{- end -}}
