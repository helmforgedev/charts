{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "moodle.env" -}}
- name: DB_HOST
  value: {{ include "moodle.dbHost" . | quote }}
- name: DB_PORT
  value: {{ ternary "5432" (toString .Values.database.port) .Values.postgresql.enabled | quote }}
- name: DB_NAME
  value: {{ include "moodle.dbName" . | quote }}
- name: DB_USER
  value: {{ include "moodle.dbUser" . | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "moodle.dbSecret" . }}
      key: {{ include "moodle.dbKey" . }}
{{- if .Values.database.tlsSecret }}
- name: PGSSLROOTCERT
  value: /opt/database-tls/ca.crt
{{- end }}
{{- if .Values.sessions.enabled }}
- name: REDIS_HOST
  value: {{ include "moodle.redisHost" . | quote }}
{{- if include "moodle.redisSecret" . }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "moodle.redisSecret" . }}
      key: {{ include "moodle.redisKey" . }}
{{- end }}
{{- end }}
{{- if .Values.smtp.existingSecret }}
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.smtp.existingSecret }}
      key: {{ .Values.smtp.existingSecretPasswordKey }}
{{- end }}
{{- with .Values.moodle.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "moodle.mounts" -}}
{{- if .Values.metrics.enabled }}
- name: metrics-token
  mountPath: /opt/metrics-auth
  readOnly: true
{{- end }}
- name: code
  mountPath: /var/www/html
  readOnly: true
- name: data
  mountPath: /var/moodledata
- name: config
  mountPath: /opt/helmforge
  readOnly: true
- name: config
  mountPath: /usr/local/etc/php/conf.d/zz-helmforge.ini
  subPath: php.ini
  readOnly: true
{{- if .Values.database.tlsSecret }}
- name: database-tls
  mountPath: /opt/database-tls
  readOnly: true
{{- end }}
{{- if .Values.sessions.tlsSecret }}
- name: redis-tls
  mountPath: /opt/redis-tls
  readOnly: true
{{- end }}
{{- with .Values.extraVolumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end -}}
