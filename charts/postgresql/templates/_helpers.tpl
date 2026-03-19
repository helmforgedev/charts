{{- define "postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "postgresql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "postgresql.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "postgresql.labels" -}}
helm.sh/chart: {{ include "postgresql.chart" . }}
{{ include "postgresql.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "postgresql.componentLabels" -}}
{{ include "postgresql.selectorLabels" .root }}
app.kubernetes.io/component: postgresql
app.kubernetes.io/part-of: postgresql
{{- if .role }}
app.kubernetes.io/role: {{ .role }}
{{- end }}
{{- end -}}

{{- define "postgresql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "postgresql.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "postgresql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.configMapName" -}}
{{- printf "%s-config" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.initdbConfigMapName" -}}
{{- printf "%s-initdb" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.tlsSecretName" -}}
{{- if .Values.tls.enabled -}}
{{- required "tls.existingSecret is required when tls.enabled=true" .Values.tls.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.primaryServiceName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-primary" (include "postgresql.fullname" .) -}}
{{- else -}}
{{- include "postgresql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.clientServiceName" -}}
{{- include "postgresql.fullname" . -}}
{{- end -}}

{{- define "postgresql.replicasServiceName" -}}
{{- printf "%s-replicas" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.metricsServiceName" -}}
{{- printf "%s-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryMetricsServiceName" -}}
{{- printf "%s-primary-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.replicasMetricsServiceName" -}}
{{- printf "%s-replicas-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryHeadlessServiceName" -}}
{{- printf "%s-primary-headless" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.replicasHeadlessServiceName" -}}
{{- printf "%s-replicas-headless" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryStatefulSetName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-primary" (include "postgresql.fullname" .) -}}
{{- else -}}
{{- include "postgresql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.replicaStatefulSetName" -}}
{{- printf "%s-replicas" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.postgresPassword" -}}
{{- $secretName := include "postgresql.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else if .Values.auth.postgresPassword -}}
{{- .Values.auth.postgresPassword -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretPostgresPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretPostgresPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.userPassword" -}}
{{- $secretName := include "postgresql.secretName" . -}}
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

{{- define "postgresql.replicationPassword" -}}
{{- $secretName := include "postgresql.secretName" . -}}
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

{{- define "postgresql.probeCommandString" -}}
{{- if .Values.tls.enabled }}export PGSSLMODE={{ .Values.tls.sslMode | quote }}; export PGSSLROOTCERT=/tls/{{ .Values.tls.caFilename }}; {{- end }}PGPASSWORD="${POSTGRES_PASSWORD}" pg_isready -U postgres -h 127.0.0.1 -p {{ .Values.service.port }}
{{- end -}}

{{- define "postgresql.metricsEnv" -}}
- name: DATA_SOURCE_URI
  value: 127.0.0.1:{{ .Values.service.port }}/postgres?sslmode={{ if .Values.tls.enabled }}{{ .Values.tls.sslMode }}{{ else }}disable{{ end }}{{ if and .Values.tls.enabled (or (eq .Values.tls.sslMode "verify-ca") (eq .Values.tls.sslMode "verify-full")) }}&sslrootcert=/tls/{{ .Values.tls.caFilename }}{{ end }}
- name: DATA_SOURCE_USER
  value: postgres
- name: DATA_SOURCE_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "postgresql.secretName" . }}
      key: {{ .Values.auth.existingSecretPostgresPasswordKey }}
{{- end -}}

{{- define "postgresql.configPreset" -}}
{{- if eq .Values.config.preset "small" -}}
max_connections = 100
shared_buffers = '256MB'
effective_cache_size = '768MB'
work_mem = '4MB'
maintenance_work_mem = '64MB'
{{- else if eq .Values.config.preset "medium" -}}
max_connections = 200
shared_buffers = '512MB'
effective_cache_size = '1536MB'
work_mem = '8MB'
maintenance_work_mem = '128MB'
{{- else if eq .Values.config.preset "large" -}}
max_connections = 400
shared_buffers = '1GB'
effective_cache_size = '3GB'
work_mem = '16MB'
maintenance_work_mem = '256MB'
{{- end -}}
{{- end -}}

{{- define "postgresql.pgHbaEntries" -}}
{{- range .Values.config.pgHbaEntries }}
{{ .type | default "host" }} {{ .database | default "all" }} {{ .user | default "all" }} {{ .address | default "0.0.0.0/0" }} {{ .method | default "scram-sha-256" }}{{- if .options }} {{ .options }}{{- end }}
{{- end -}}
{{- end -}}

{{- define "postgresql.resourcesPreset" -}}
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

{{- define "postgresql.metricsResourcesPreset" -}}
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

{{- define "postgresql.volumeClaimTemplate" -}}
- metadata:
    name: data
    labels:
      {{- include "postgresql.selectorLabels" .root | nindent 6 }}
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

{{- define "postgresql.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "postgresql.serviceAccountName" . }}
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
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
