{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "nextcloud.backupPod" -}}
{{- $root := .root -}}
{{- $restore := .restore -}}
metadata:
  labels:
    {{- include "nextcloud.selectorLabels" $root | nindent 4 }}
    app.kubernetes.io/component: {{ ternary "restore" "backup" $restore }}
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  {{- if not $restore }}
  serviceAccountName: {{ include "nextcloud.backupName" $root }}
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              {{- include "nextcloud.selectorLabels" $root | nindent 14 }}
              app.kubernetes.io/component: app
  {{- end }}
  {{- with $root.Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
    {{- toYaml $root.Values.podSecurityContext | nindent 4 }}
  initContainers:
    {{- if $restore }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "download" "type" "s3" "command" (list "bash" "/scripts/backup-s3.sh" "download")) | nindent 4 }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "restore-files" "type" "app" "command" (list "bash" "/scripts/restore-files.sh")) | nindent 4 }}
    {{- else }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "check-s3" "type" "s3" "command" (list "bash" "/scripts/backup-s3.sh" "preflight")) | nindent 4 }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "quiesce" "type" "app" "api" true "command" (list "php" "/scripts/backup-coordinate.php" "stop")) | nindent 4 }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "dump-database" "type" "db" "command" (list "bash" "/scripts/dump.sh")) | nindent 4 }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "archive-and-resume" "type" "app" "api" true "command" (list "bash" "/scripts/backup-archive.sh")) | nindent 4 }}
    {{- end }}
  containers:
    {{- if $restore }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "restore-database" "type" "db" "command" (list "bash" "/scripts/restore-database.sh")) | nindent 4 }}
    {{- else }}
    {{- include "nextcloud.backupStage" (dict "root" $root "name" "upload" "type" "s3" "command" (list "bash" "/scripts/backup-s3.sh" "upload")) | nindent 4 }}
    {{- end }}
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: {{ default (include "nextcloud.fullname" $root) $root.Values.persistence.existingClaim }}
    - name: work
      emptyDir:
        sizeLimit: {{ $root.Values.backup.workspaceSize }}
    - name: scripts
      configMap:
        name: {{ include "nextcloud.backupName" $root }}
    - name: tmp
      emptyDir: {}
    {{- if not $restore }}
    - name: api-token
      projected:
        sources:
          - serviceAccountToken:
              path: token
              expirationSeconds: 3600
          - configMap:
              name: kube-root-ca.crt
              items:
                - {key: ca.crt, path: ca.crt}
    {{- end }}
{{- end -}}

{{- define "nextcloud.backupStage" -}}
{{- $root := .root -}}
- name: {{ .name }}
  {{- if eq .type "s3" }}
  image: {{ $root.Values.backup.s3Image | quote }}
  {{- else if eq .type "db" }}
  image: {{ $root.Values.backup.databaseImage | quote }}
  {{- else }}
  image: {{ include "nextcloud.image" $root | quote }}
  {{- end }}
  imagePullPolicy: {{ $root.Values.image.pullPolicy }}
  command: {{ .command | toJson }}
  securityContext:
    {{- toYaml $root.Values.securityContext | nindent 4 }}
  resources:
    {{- toYaml $root.Values.backup.resources | nindent 4 }}
  env:
    {{- if eq .type "s3" }}
    - name: S3_ENDPOINT
      value: {{ $root.Values.backup.s3.endpoint | quote }}
    - name: S3_BUCKET
      value: {{ $root.Values.backup.s3.bucket | quote }}
    - name: S3_PREFIX
      value: {{ $root.Values.backup.s3.prefix | quote }}
    - name: S3_REGION
      value: {{ $root.Values.backup.s3.region | quote }}
    - name: RESTORE_PATH
      value: {{ $root.Values.restore.backupPath | quote }}
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: {{ $root.Values.backup.s3.existingSecret }}
          key: {{ $root.Values.backup.s3.existingSecretAccessKeyKey }}
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: {{ $root.Values.backup.s3.existingSecret }}
          key: {{ $root.Values.backup.s3.existingSecretSecretKeyKey }}
    {{- else if eq .type "db" }}
    - name: PGHOST
      value: {{ include "nextcloud.dbHost" $root | quote }}
    - name: PGPORT
      value: {{ ternary 5432 $root.Values.externalDatabase.port $root.Values.postgresql.enabled | quote }}
    - name: PGDATABASE
      value: {{ include "nextcloud.dbName" $root | quote }}
    - name: PGUSER
      value: {{ include "nextcloud.dbUser" $root | quote }}
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "nextcloud.dbSecret" $root }}
          key: {{ include "nextcloud.dbKey" $root }}
    {{- else }}
    - name: APP_VERSION
      value: {{ $root.Chart.AppVersion | quote }}
    - name: APP_IMAGE
      value: {{ include "nextcloud.image" $root | quote }}
    {{- if .api }}
    - name: APP_DEPLOYMENT
      value: {{ include "nextcloud.fullname" $root | quote }}
    - name: RELEASE_NAME
      value: {{ $root.Release.Name | quote }}
    - name: QUIESCE_TIMEOUT
      value: {{ $root.Values.backup.quiesceTimeout | quote }}
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef: {fieldPath: metadata.namespace}
    - name: POD_UID
      valueFrom:
        fieldRef: {fieldPath: metadata.uid}
    {{- end }}
    {{- end }}
  volumeMounts:
    - {name: work, mountPath: /work}
    - {name: tmp, mountPath: /tmp}
    - {name: scripts, mountPath: /scripts, readOnly: true}
    {{- if eq .type "app" }}
    - {name: data, mountPath: /var/www/html}
    {{- end }}
    {{- if .api }}
    - {name: api-token, mountPath: /var/run/secrets/kubernetes.io/serviceaccount, readOnly: true}
    {{- end }}
{{- end -}}
