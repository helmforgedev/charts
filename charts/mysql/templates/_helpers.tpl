{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "mysql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mysql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "mysql.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mysql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mysql.labels" -}}
helm.sh/chart: {{ include "mysql.chart" . }}
{{ include "mysql.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "mysql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mysql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mysql.componentLabels" -}}
{{ include "mysql.selectorLabels" .root }}
app.kubernetes.io/component: mysql
app.kubernetes.io/part-of: mysql
{{- if .role }}
app.kubernetes.io/role: {{ .role }}
{{- end }}
{{- end -}}

{{- define "mysql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "mysql.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "mysql.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else if include "mysql.authSecretManagedByExternalSecret" . -}}
{{- default (printf "%s-auth" (include "mysql.fullname" .)) .Values.externalSecrets.auth.targetName -}}
{{- else -}}
{{- printf "%s-auth" (include "mysql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mysql.tlsSecretName" -}}
{{- if .Values.tls.existingSecret -}}
{{- .Values.tls.existingSecret -}}
{{- else if include "mysql.tlsSecretManagedByExternalSecret" . -}}
{{- default (printf "%s-tls" (include "mysql.fullname" .)) .Values.externalSecrets.tls.targetName -}}
{{- else -}}
{{- required "tls.existingSecret or externalSecrets.tls.enabled is required when tls.enabled=true" .Values.tls.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "mysql.configMapName" -}}
{{- printf "%s-config" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.initdbConfigMapName" -}}
{{- printf "%s-initdb" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.sourceServiceName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-source" (include "mysql.fullname" .) -}}
{{- else -}}
{{- include "mysql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mysql.clientServiceName" -}}
{{- include "mysql.fullname" . -}}
{{- end -}}

{{- define "mysql.replicasServiceName" -}}
{{- printf "%s-replicas" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.metricsServiceName" -}}
{{- printf "%s-metrics" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.sourceMetricsServiceName" -}}
{{- printf "%s-source-metrics" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.replicasMetricsServiceName" -}}
{{- printf "%s-replicas-metrics" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.sourceHeadlessServiceName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-source-headless" (include "mysql.fullname" .) -}}
{{- else -}}
{{- printf "%s-headless" (include "mysql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mysql.replicasHeadlessServiceName" -}}
{{- printf "%s-replicas-headless" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.sourceStatefulSetName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-source" (include "mysql.fullname" .) -}}
{{- else -}}
{{- include "mysql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mysql.replicaStatefulSetName" -}}
{{- printf "%s-replicas" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.rootPassword" -}}
{{- $secretName := include "mysql.secretName" . -}}
{{- if or .Values.auth.existingSecret (include "mysql.authSecretManagedByExternalSecret" .) -}}
{{- "" -}}
{{- else if .Values.auth.rootPassword -}}
{{- .Values.auth.rootPassword -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretRootPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretRootPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mysql.userPassword" -}}
{{- $secretName := include "mysql.secretName" . -}}
{{- if or .Values.auth.existingSecret (include "mysql.authSecretManagedByExternalSecret" .) -}}
{{- "" -}}
{{- else if .Values.auth.password -}}
{{- .Values.auth.password -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretUserPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretUserPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mysql.replicationPassword" -}}
{{- $secretName := include "mysql.secretName" . -}}
{{- if or .Values.auth.existingSecret (include "mysql.authSecretManagedByExternalSecret" .) -}}
{{- "" -}}
{{- else if .Values.auth.replicationPassword -}}
{{- .Values.auth.replicationPassword -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretReplicationPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretReplicationPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mysql.probeCommandString" -}}
MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysqladmin ping -h 127.0.0.1 -P {{ .Values.service.port }} -uroot
{{- end -}}

{{- define "mysql.sourceReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") .Values.replication.source.probes.requireWritable -}}
MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql -h 127.0.0.1 -P {{ .Values.service.port }} -uroot -Nse "SELECT IF(@@global.read_only = 0, 1, 0)" | grep -qx 1
{{- else -}}
{{ include "mysql.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "mysql.replicaReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") (or .Values.replication.readReplicas.probes.requireReadOnly .Values.replication.readReplicas.probes.requireRunningReplication) -}}
MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql -h 127.0.0.1 -P {{ .Values.service.port }} -uroot -Nse "SELECT IF(@@global.read_only = 1{{- if .Values.replication.readReplicas.probes.requireRunningReplication }} AND EXISTS (SELECT 1 FROM performance_schema.replication_connection_status WHERE SERVICE_STATE = 'ON') AND EXISTS (SELECT 1 FROM performance_schema.replication_applier_status WHERE SERVICE_STATE = 'ON'){{- end }}, 1, 0)" | grep -qx 1
{{- else -}}
{{ include "mysql.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "mysql.binlogExpireLogsSeconds" -}}
{{- if gt (int .Values.replication.binlog.retentionDays) 0 -}}
{{- mul (int .Values.replication.binlog.retentionDays) 86400 -}}
{{- else -}}
{{- .Values.replication.binlog.expireLogsSeconds -}}
{{- end -}}
{{- end -}}

{{- define "mysql.metricsEnv" -}}
- name: MYSQLD_EXPORTER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mysql.secretName" . }}
      key: {{ .Values.auth.existingSecretRootPasswordKey }}
{{- end -}}

{{- define "mysql.metricsArgs" -}}
- --web.listen-address=:{{ .Values.service.metricsPort }}
- --mysqld.address=127.0.0.1:{{ .Values.service.port }}
- --mysqld.username=root
{{- if or .Values.tls.client.enabled .Values.tls.requireSecureTransport }}
- --tls.insecure-skip-verify
{{- end }}
{{- end -}}

{{- define "mysql.tlsClientEnabled" -}}
{{- if or .Values.tls.client.enabled .Values.tls.requireSecureTransport -}}true{{- end -}}
{{- end -}}

{{- define "mysql.mysqlCliTlsArgs" -}}
{{- if include "mysql.tlsClientEnabled" . -}}
{{- $sslMode := upper .Values.tls.client.sslMode -}}
--ssl-mode={{ $sslMode }}
{{- if eq $sslMode "VERIFY_CA" }}
--ssl-ca=/tls/{{ .Values.tls.caFilename }}
{{- end }}
{{- end -}}
{{- end -}}

{{- define "mysql.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else if include "mysql.backupSecretManagedByExternalSecret" . -}}
{{- default (printf "%s-backup" (include "mysql.fullname" .)) .Values.externalSecrets.backup.targetName -}}
{{- else -}}
{{- printf "%s-backup" (include "mysql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mysql.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not (include "mysql.backupSecretManagedByExternalSecret" .)) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "mysql.backupHost" -}}
{{- include "mysql.sourceServiceName" . -}}
{{- end -}}

{{- define "mysql.backupTlsVolumeEnabled" -}}
{{- if include "mysql.tlsClientEnabled" . -}}true{{- end -}}
{{- end -}}

{{- define "mysql.externalSecretsEnabled" -}}
{{- if .Values.externalSecrets.enabled -}}true{{- end -}}
{{- end -}}

{{- define "mysql.legacyExternalSecretEnabled" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.data (not .Values.externalSecrets.auth.enabled) (not .Values.externalSecrets.tls.enabled) (not .Values.externalSecrets.backup.enabled) -}}true{{- end -}}
{{- end -}}

{{- define "mysql.authSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled (or .Values.externalSecrets.auth.enabled (include "mysql.legacyExternalSecretEnabled" .)) -}}true{{- end -}}
{{- end -}}

{{- define "mysql.tlsSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.tls.enabled -}}true{{- end -}}
{{- end -}}

{{- define "mysql.backupSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.backup.enabled -}}true{{- end -}}
{{- end -}}

{{- define "mysql.validateExternalSecrets" -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if ne .Values.externalSecrets.apiVersion "external-secrets.io/v1" -}}
    {{- fail "externalSecrets.apiVersion must be external-secrets.io/v1" -}}
  {{- end -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
  {{- if and (include "mysql.legacyExternalSecretEnabled" .) (not .Values.auth.existingSecret) -}}
    {{- fail "legacy externalSecrets.data requires auth.existingSecret to prevent credential drift; prefer externalSecrets.auth.enabled for chart-owned target names" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.auth.enabled .Values.auth.existingSecret -}}
    {{- fail "externalSecrets.auth.enabled cannot be combined with auth.existingSecret; set externalSecrets.auth.targetName instead" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.tls.enabled .Values.tls.existingSecret -}}
    {{- fail "externalSecrets.tls.enabled cannot be combined with tls.existingSecret; set externalSecrets.tls.targetName instead" -}}
  {{- end -}}
  {{- if and .Values.externalSecrets.backup.enabled .Values.backup.s3.existingSecret -}}
    {{- fail "externalSecrets.backup.enabled cannot be combined with backup.s3.existingSecret; set externalSecrets.backup.targetName instead" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "mysql.externalSecretDataItem" -}}
{{- if or (not .remoteRef) (eq (len .remoteRef) 0) -}}
{{- fail (printf "%s is required and must contain at least one remoteRef field" .remoteRefName) -}}
{{- end -}}
- secretKey: {{ .secretKey }}
  remoteRef:
    {{- toYaml .remoteRef | nindent 4 }}
{{- end -}}

{{- define "mysql.tlsVolumeMountName" -}}
{{- if .Values.tls.volumePermissions.enabled -}}tls-workdir{{- else -}}tls{{- end -}}
{{- end -}}

{{- define "mysql.tlsVolumeMount" -}}
- name: {{ include "mysql.tlsVolumeMountName" . }}
  mountPath: /tls
  readOnly: true
{{- end -}}

{{- define "mysql.tlsVolumePermissionsInitContainer" -}}
{{- if and .Values.tls.enabled .Values.tls.volumePermissions.enabled }}
- name: tls-volume-permissions
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - sh
    - -ec
    - |
      cp "/tls-secret/{{ .Values.tls.caFilename }}" "/tls-workdir/{{ .Values.tls.caFilename }}"
      cp "/tls-secret/{{ .Values.tls.certFilename }}" "/tls-workdir/{{ .Values.tls.certFilename }}"
      cp "/tls-secret/{{ .Values.tls.keyFilename }}" "/tls-workdir/{{ .Values.tls.keyFilename }}"
      chmod 0644 "/tls-workdir/{{ .Values.tls.caFilename }}" "/tls-workdir/{{ .Values.tls.certFilename }}"
      chmod 0600 "/tls-workdir/{{ .Values.tls.keyFilename }}"
      chown {{ .Values.securityContext.runAsUser }}:{{ .Values.securityContext.runAsGroup }} /tls-workdir/*
  securityContext:
    runAsUser: 0
    runAsGroup: 0
    runAsNonRoot: false
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
      add:
        - CHOWN
  volumeMounts:
    - name: tls
      mountPath: /tls-secret
      readOnly: true
    - name: tls-workdir
      mountPath: /tls-workdir
{{- end -}}
{{- end -}}

{{- define "mysql.tlsVolumes" -}}
{{- if .Values.tls.enabled }}
- name: tls
  secret:
    secretName: {{ include "mysql.tlsSecretName" . }}
{{- if .Values.tls.volumePermissions.enabled }}
- name: tls-workdir
  emptyDir: {}
{{- end }}
{{- end -}}
{{- end -}}

{{- define "mysql.replicationTlsClause" -}}
{{- if include "mysql.tlsClientEnabled" . -}}
SOURCE_SSL=1,
{{- if eq (upper .Values.tls.client.sslMode) "VERIFY_CA" }}
SOURCE_SSL_CA='/tls/{{ .Values.tls.caFilename }}',
{{- end }}
{{- end -}}
{{- end -}}

{{- define "mysql.configPreset" -}}
{{- if eq .Values.config.preset "small" -}}
max_connections = 100
innodb_buffer_pool_size = 256M
innodb_redo_log_capacity = 268435456
{{- else if eq .Values.config.preset "medium" -}}
max_connections = 200
innodb_buffer_pool_size = 512M
innodb_redo_log_capacity = 536870912
{{- else if eq .Values.config.preset "large" -}}
max_connections = 400
innodb_buffer_pool_size = 1G
innodb_redo_log_capacity = 1073741824
{{- else if eq .Values.config.preset "oltp" -}}
max_connections = 300
innodb_buffer_pool_size = 1G
innodb_redo_log_capacity = 1073741824
innodb_flush_log_at_trx_commit = 1
sync_binlog = 1
innodb_io_capacity = 1000
{{- else if eq .Values.config.preset "read-heavy" -}}
max_connections = 300
innodb_buffer_pool_size = 1G
innodb_redo_log_capacity = 1073741824
table_open_cache = 4096
tmp_table_size = 128M
max_heap_table_size = 128M
{{- else if eq .Values.config.preset "analytics" -}}
max_connections = 150
innodb_buffer_pool_size = 2G
innodb_redo_log_capacity = 2147483648
tmp_table_size = 256M
max_heap_table_size = 256M
sort_buffer_size = 4M
{{- end -}}
{{- end -}}

{{- define "mysql.resourcesPreset" -}}
{{- $preset := default "none" .preset -}}
{{- if eq $preset "small" -}}
requests:
  cpu: 250m
  memory: 512Mi
limits:
  cpu: 500m
  memory: 1Gi
{{- else if eq $preset "medium" -}}
requests:
  cpu: 500m
  memory: 1Gi
limits:
  cpu: "1"
  memory: 2Gi
{{- else if eq $preset "large" -}}
requests:
  cpu: "1"
  memory: 2Gi
limits:
  cpu: "2"
  memory: 4Gi
{{- end -}}
{{- end -}}

{{- define "mysql.metricsResourcesPreset" -}}
{{- $preset := default "none" .Values.metrics.resourcesPreset -}}
{{- if eq $preset "small" -}}
requests:
  cpu: 25m
  memory: 64Mi
limits:
  cpu: 100m
  memory: 128Mi
{{- else if eq $preset "medium" -}}
requests:
  cpu: 50m
  memory: 128Mi
limits:
  cpu: 200m
  memory: 256Mi
{{- end -}}
{{- end -}}

{{- define "mysql.volumeClaimTemplate" -}}
- metadata:
    name: data
    labels:
      {{- include "mysql.selectorLabels" .root | nindent 6 }}
  spec:
    accessModes:
      {{- toYaml .persistence.accessModes | nindent 6 }}
    {{- if .persistence.storageClass }}
    storageClassName: {{ .persistence.storageClass | quote }}
    {{- end }}
    resources:
      requests:
        storage: {{ .persistence.size }}
{{- end -}}

{{- define "mysql.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "mysql.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- with .Values.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with .Values.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.affinity }}
affinity:
  {{- toYaml .Values.affinity | nindent 2 }}
{{- else if and (eq .Values.architecture "replication") .Values.replication.scheduling.enableDefaultPodAntiAffinity }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              {{- include "mysql.selectorLabels" . | nindent 14 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml .Values.topologySpreadConstraints | nindent 2 }}
{{- else if and (eq .Values.architecture "replication") .Values.replication.scheduling.enableDefaultTopologySpread }}
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: {{ .Values.replication.scheduling.topologyKey | quote }}
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        {{- include "mysql.selectorLabels" . | nindent 8 }}
{{- end }}
{{- end -}}

{{- define "mysql.pdbEnabled" -}}
{{- if eq .Values.architecture "replication" -}}
{{- if .Values.replication.pdb.enabled -}}true{{- end -}}
{{- else -}}
{{- if .Values.pdb.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}
