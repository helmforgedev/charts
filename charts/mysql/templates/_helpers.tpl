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
{{- else -}}
{{- printf "%s-auth" (include "mysql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mysql.tlsSecretName" -}}
{{- required "tls.existingSecret is required when tls.enabled=true" .Values.tls.existingSecret -}}
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

{{- define "mysql.userPassword" -}}
{{- $secretName := include "mysql.secretName" . -}}
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

{{- define "mysql.replicationPassword" -}}
{{- $secretName := include "mysql.secretName" . -}}
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
- name: DATA_SOURCE_NAME
  value: root:$(MYSQL_ROOT_PASSWORD)@(127.0.0.1:{{ .Values.service.port }})/{{ if or .Values.tls.client.enabled .Values.tls.requireSecureTransport }}?tls=skip-verify{{ end }}
- name: MYSQL_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mysql.secretName" . }}
      key: {{ .Values.auth.existingSecretRootPasswordKey }}
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
innodb_log_file_size = 128M
{{- else if eq .Values.config.preset "medium" -}}
max_connections = 200
innodb_buffer_pool_size = 512M
innodb_log_file_size = 256M
{{- else if eq .Values.config.preset "large" -}}
max_connections = 400
innodb_buffer_pool_size = 1G
innodb_log_file_size = 512M
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
