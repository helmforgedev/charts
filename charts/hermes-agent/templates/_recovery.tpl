{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "hermes-agent.s3Env" -}}
- {name: HOME, value: /tmp}
- {name: S3_BUCKET, value: {{ .Values.backup.s3.bucket | quote }}}
- {name: S3_PREFIX, value: {{ .Values.backup.s3.prefix | quote }}}
- {name: S3_REGION, value: {{ .Values.backup.s3.region | quote }}}
- {name: S3_ENDPOINT, value: {{ .Values.backup.s3.endpoint | quote }}}
- {name: ALLOW_INSECURE_ENDPOINT, value: {{ .Values.backup.s3.allowInsecureEndpoint | toString | quote }}}
- {name: S3_SSE, value: {{ .Values.backup.s3.sse | quote }}}
- {name: S3_KMS_KEY_ID, value: {{ .Values.backup.s3.kmsKeyId | quote }}}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef: {name: {{ .Values.backup.s3.existingSecret }}, key: AWS_ACCESS_KEY_ID}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef: {name: {{ .Values.backup.s3.existingSecret }}, key: AWS_SECRET_ACCESS_KEY}
- name: AWS_SESSION_TOKEN
  valueFrom:
    secretKeyRef: {name: {{ .Values.backup.s3.existingSecret }}, key: AWS_SESSION_TOKEN, optional: true}
{{- if .Values.backup.s3.caSecret }}
- {name: AWS_CA_BUNDLE, value: /s3-ca/ca.crt}
{{- end }}
{{- end }}
{{- define "hermes-agent.restoreEnv" -}}
- {name: HERMES_HOME, value: /tmp/hermes-recovery}
- {name: TARGET_HOME, value: /opt/data}
- {name: PYTHONDONTWRITEBYTECODE, value: "1"}
- {name: RESTORE_MANIFEST_KEY, value: {{ .Values.restore.manifestKey | quote }}}
- {name: MAX_ARCHIVE_BYTES, value: {{ .Values.restore.maxArchiveBytes | int64 | toString | quote }}}
- {name: MAX_EXPANDED_BYTES, value: {{ .Values.restore.maxExpandedBytes | int64 | toString | quote }}}
{{- end }}
{{- define "hermes-agent.restoreInitContainers" -}}
{{- range $action := list "prepare-restore" "download" "restore" }}
- name: {{ $action }}
  {{- if eq $action "download" }}
  image: {{ printf "%s:%s" $.Values.backup.image.repository $.Values.backup.image.tag | quote }}
  command: [/bin/bash, /recovery/s3.sh, download]
  {{- else }}
  image: {{ include "hermes-agent.image" $ | quote }}
  command: [/opt/hermes/.venv/bin/python, /recovery/archive.py, {{ $action }}]
  {{- end }}
  env:
    {{- include "hermes-agent.restoreEnv" $ | nindent 4 }}
    {{- if eq $action "download" }}
    {{- include "hermes-agent.s3Env" $ | nindent 4 }}
    {{- else }}
    - {name: HOME, value: /tmp}
    {{- end }}
  securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
  resources: {{ toJson $.Values.backup.resources }}
  volumeMounts:
    - {name: recovery, mountPath: /recovery, readOnly: true}
    - {name: recovery-work, mountPath: /work}
    - {name: tmp, mountPath: /tmp}
    {{- if ne $action "download" }}
    - {name: data, mountPath: /opt/data}
    {{- else if $.Values.backup.s3.caSecret }}
    - {name: s3-ca, mountPath: /s3-ca, readOnly: true}
    {{- end }}
{{- end }}
{{- end }}
