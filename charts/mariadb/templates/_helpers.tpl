{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "mariadb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mariadb.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "mariadb.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mariadb.labels" -}}
helm.sh/chart: {{ include "mariadb.chart" . }}
{{ include "mariadb.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "mariadb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mariadb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mariadb.componentLabels" -}}
{{ include "mariadb.selectorLabels" .root }}
app.kubernetes.io/component: mariadb
app.kubernetes.io/part-of: mariadb
{{- if .role }}
app.kubernetes.io/role: {{ .role }}
{{- end }}
{{- end -}}

{{- define "mariadb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "mariadb.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "mariadb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.tlsSecretName" -}}
{{- required "tls.existingSecret is required when tls.enabled=true" .Values.tls.existingSecret -}}
{{- end -}}

{{- define "mariadb.configMapName" -}}
{{- printf "%s-config" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.initdbConfigMapName" -}}
{{- printf "%s-initdb" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.sourceServiceName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-source" (include "mariadb.fullname" .) -}}
{{- else -}}
{{- include "mariadb.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.clientServiceName" -}}
{{- include "mariadb.fullname" . -}}
{{- end -}}

{{- define "mariadb.replicasServiceName" -}}
{{- printf "%s-replicas" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.metricsServiceName" -}}
{{- printf "%s-metrics" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.sourceMetricsServiceName" -}}
{{- printf "%s-source-metrics" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.replicasMetricsServiceName" -}}
{{- printf "%s-replicas-metrics" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.sourceHeadlessServiceName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-source-headless" (include "mariadb.fullname" .) -}}
{{- else -}}
{{- printf "%s-headless" (include "mariadb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.replicasHeadlessServiceName" -}}
{{- printf "%s-replicas-headless" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.sourceStatefulSetName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-source" (include "mariadb.fullname" .) -}}
{{- else -}}
{{- include "mariadb.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.replicaStatefulSetName" -}}
{{- printf "%s-replicas" (include "mariadb.fullname" .) -}}
{{- end -}}

{{- define "mariadb.rootPassword" -}}
{{- $secretName := include "mariadb.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
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

{{- define "mariadb.userPassword" -}}
{{- $secretName := include "mariadb.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
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

{{- define "mariadb.replicationPassword" -}}
{{- $secretName := include "mariadb.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
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

{{- define "mariadb.probeCommandString" -}}
MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" mariadb-admin ping -h 127.0.0.1 -P {{ .Values.service.port }} -uroot
{{- end -}}

{{- define "mariadb.sourceReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") .Values.replication.source.probes.requireWritable -}}
MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P {{ .Values.service.port }} -uroot -Nse "SELECT IF(@@global.read_only = 0, 1, 0)" | grep -qx 1
{{- else -}}
{{ include "mariadb.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "mariadb.replicaReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") (or .Values.replication.readReplicas.probes.requireReadOnly .Values.replication.readReplicas.probes.requireRunningReplication) -}}
MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P {{ .Values.service.port }} -uroot -Nse "SELECT IF(@@global.read_only = 1{{- if .Values.replication.readReplicas.probes.requireRunningReplication }} AND EXISTS (SELECT 1 FROM information_schema.processlist WHERE command = 'Binlog Dump') IS NOT NULL{{- end }}, 1, 0)" | grep -qx 1
{{- else -}}
{{ include "mariadb.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "mariadb.binlogExpireLogsSeconds" -}}
{{- if gt (int .Values.replication.binlog.retentionDays) 0 -}}
{{- mul (int .Values.replication.binlog.retentionDays) 86400 -}}
{{- else -}}
{{- .Values.replication.binlog.expireLogsSeconds -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.metricsEnv" -}}
- name: DATA_SOURCE_NAME
  value: root:$(MARIADB_ROOT_PASSWORD)@(127.0.0.1:{{ .Values.service.port }})/{{ if or .Values.tls.client.enabled .Values.tls.requireSecureTransport }}?tls=skip-verify{{ end }}
- name: MARIADB_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mariadb.secretName" . }}
      key: {{ .Values.auth.existingSecretRootPasswordKey }}
{{- end -}}

{{- define "mariadb.tlsClientEnabled" -}}
{{- if or .Values.tls.client.enabled .Values.tls.requireSecureTransport -}}true{{- end -}}
{{- end -}}

{{- define "mariadb.cliTlsArgs" -}}
{{- if include "mariadb.tlsClientEnabled" . -}}
--ssl --ssl-ca=/tls/{{ .Values.tls.caFilename }}
{{- end -}}
{{- end -}}

{{- define "mariadb.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "mariadb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "mariadb.backupHost" -}}
{{- include "mariadb.sourceServiceName" . -}}
{{- end -}}

{{- define "mariadb.backupTlsVolumeEnabled" -}}
{{- if include "mariadb.tlsClientEnabled" . -}}true{{- end -}}
{{- end -}}

{{- define "mariadb.replicationTlsClause" -}}
{{- if include "mariadb.tlsClientEnabled" . -}}
MASTER_SSL=1,
MASTER_SSL_CA='/tls/{{ .Values.tls.caFilename }}',
{{- end -}}
{{- end -}}

{{- define "mariadb.configPreset" -}}
{{- if eq .Values.config.preset "small" -}}
max_connections = 100
innodb_buffer_pool_size = 256M
innodb_log_file_size = 128M
{{- else if eq .Values.config.preset "medium" -}}
max_connections = 200
innodb_buffer_pool_size = 512M
innodb_log_file_size = 256M
{{- else if eq .Values.config.preset "large" -}}
max_connections = 400
innodb_buffer_pool_size = 1G
innodb_log_file_size = 512M
{{- else if eq .Values.config.preset "oltp" -}}
max_connections = 300
innodb_buffer_pool_size = 1G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 1
sync_binlog = 1
innodb_io_capacity = 1000
{{- else if eq .Values.config.preset "read-heavy" -}}
max_connections = 300
innodb_buffer_pool_size = 1G
innodb_log_file_size = 512M
table_open_cache = 4096
tmp_table_size = 128M
max_heap_table_size = 128M
{{- else if eq .Values.config.preset "analytics" -}}
max_connections = 150
innodb_buffer_pool_size = 2G
innodb_log_file_size = 1G
tmp_table_size = 256M
max_heap_table_size = 256M
sort_buffer_size = 4M
{{- end -}}
{{- end -}}

{{- define "mariadb.resourcesPreset" -}}
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

{{- define "mariadb.metricsResourcesPreset" -}}
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

{{- define "mariadb.volumeClaimTemplate" -}}
- metadata:
    name: data
    labels:
      {{- include "mariadb.selectorLabels" .root | nindent 6 }}
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

{{- define "mariadb.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "mariadb.serviceAccountName" . }}
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
              {{- include "mariadb.selectorLabels" . | nindent 14 }}
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
        {{- include "mariadb.selectorLabels" . | nindent 8 }}
{{- end }}
{{- end -}}

{{- define "mariadb.pdbEnabled" -}}
{{- if eq .Values.architecture "replication" -}}
{{- if .Values.replication.pdb.enabled -}}true{{- end -}}
{{- else -}}
{{- if .Values.pdb.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}
