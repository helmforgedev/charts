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

{{- define "postgresql.primaryReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") .Values.replication.primary.probes.requireWritable -}}
{{- if .Values.tls.enabled }}export PGSSLMODE={{ .Values.tls.sslMode | quote }}; export PGSSLROOTCERT=/tls/{{ .Values.tls.caFilename }}; {{- end }}PGPASSWORD="${POSTGRES_PASSWORD}" psql -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d postgres -tAc "SELECT CASE WHEN pg_is_in_recovery() THEN 1 ELSE 0 END" | grep -qx 0
{{- else -}}
{{ include "postgresql.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "postgresql.replicaReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") .Values.replication.readReplicas.probes.requireRecoveryMode -}}
{{- if .Values.tls.enabled }}export PGSSLMODE={{ .Values.tls.sslMode | quote }}; export PGSSLROOTCERT=/tls/{{ .Values.tls.caFilename }}; {{- end }}PGPASSWORD="${POSTGRES_PASSWORD}" psql -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d postgres -tAc "SELECT CASE WHEN pg_is_in_recovery() THEN 1 ELSE 0 END" | grep -qx 1
{{- else -}}
{{ include "postgresql.probeCommandString" . }}
{{- end -}}
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
              {{- include "postgresql.selectorLabels" . | nindent 14 }}
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
        {{- include "postgresql.selectorLabels" . | nindent 8 }}
{{- end }}
{{- end -}}

{{- define "postgresql.pdbEnabled" -}}
{{- if eq .Values.architecture "replication" -}}
{{- if .Values.replication.pdb.enabled -}}true{{- end -}}
{{- else -}}
{{- if .Values.pdb.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}
