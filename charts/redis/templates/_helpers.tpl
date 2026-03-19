{{/*
Expand the name of the chart.
*/}}
{{- define "redis.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "redis.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart label.
*/}}
{{- define "redis.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "redis.labels" -}}
helm.sh/chart: {{ include "redis.chart" . }}
{{ include "redis.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name.
*/}}
{{- define "redis.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "redis.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Architecture checks.
*/}}
{{- define "redis.isStandalone" -}}
{{- if eq .Values.architecture "standalone" -}}true{{- end -}}
{{- end -}}

{{- define "redis.isReplication" -}}
{{- if eq .Values.architecture "replication" -}}true{{- end -}}
{{- end -}}

{{- define "redis.isSentinel" -}}
{{- if eq .Values.architecture "sentinel" -}}true{{- end -}}
{{- end -}}

{{- define "redis.isCluster" -}}
{{- if eq .Values.architecture "cluster" -}}true{{- end -}}
{{- end -}}

{{/*
Common names.
*/}}
{{- define "redis.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "redis.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "redis.headlessServiceName" -}}
{{- printf "%s-headless" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.clientServiceName" -}}
{{- printf "%s-client" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.primaryServiceName" -}}
{{- printf "%s-primary" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.replicaServiceName" -}}
{{- printf "%s-replicas" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.sentinelServiceName" -}}
{{- printf "%s-sentinel" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.metricsServiceName" -}}
{{- printf "%s-metrics" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.primaryStatefulSetName" -}}
{{- printf "%s-primary" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.replicaStatefulSetName" -}}
{{- printf "%s-replica" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.sentinelStatefulSetName" -}}
{{- printf "%s-sentinel" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.clusterStatefulSetName" -}}
{{- printf "%s-cluster" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.configMapName" -}}
{{- printf "%s-config" (include "redis.fullname" .) -}}
{{- end -}}

{{/*
Secret value helpers.
*/}}
{{- define "redis.password" -}}
{{- if .Values.auth.password -}}
{{- .Values.auth.password -}}
{{- else if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (include "redis.secretName" .) -}}
{{- if and $secret $secret.data (hasKey $secret.data .Values.auth.existingSecretPasswordKey) -}}
{{- index $secret.data .Values.auth.existingSecretPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Port helper for redis when TLS is enabled.
*/}}
{{- define "redis.serverArgs" -}}
- /etc/redis/redis.conf
{{- if .Values.auth.enabled }}
- --requirepass
- $(REDIS_PASSWORD)
{{- end }}
{{- end -}}

{{/*
TLS block for redis.conf.
*/}}
{{- define "redis.tlsConfig" -}}
{{- if .Values.tls.enabled }}
port 0
tls-port {{ .Values.service.ports.redis }}
tls-cert-file /tls/{{ .Values.tls.certFilename }}
tls-key-file /tls/{{ .Values.tls.keyFilename }}
tls-ca-cert-file /tls/{{ .Values.tls.caFilename }}
tls-auth-clients no
{{- end }}
{{- end -}}

{{/*
Common redis.conf baseline.
*/}}
{{- define "redis.commonConfig" -}}
bind 0.0.0.0
protected-mode no
dir /data
appendonly yes
save 900 1
save 300 10
save 60 10000
{{ include "redis.tlsConfig" . }}
{{- end -}}

{{/*
Probe command.
*/}}
{{- define "redis.probeCommand" -}}
{{- if .Values.auth.enabled -}}
redis-cli -a "$REDIS_PASSWORD" ping
{{- else -}}
redis-cli ping
{{- end -}}
{{- end -}}

{{/*
Exporter environment.
*/}}
{{- define "redis.exporterEnv" -}}
- name: REDIS_ADDR
  value: redis://127.0.0.1:{{ .Values.service.ports.redis }}
{{- if .Values.auth.enabled }}
- name: REDIS_USER
  value: default
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "redis.secretName" . }}
      key: {{ .Values.auth.existingSecretPasswordKey }}
{{- end }}
{{- end -}}

{{/*
Pod labels with component and role.
*/}}
{{- define "redis.componentLabels" -}}
{{ include "redis.selectorLabels" .root }}
app.kubernetes.io/component: redis
app.kubernetes.io/part-of: redis
{{- if .role }}
app.kubernetes.io/role: {{ .role }}
{{- end }}
{{- end -}}

{{/*
Volume claim template.
*/}}
{{- define "redis.volumeClaimTemplate" -}}
- metadata:
    name: data
    labels:
      {{- include "redis.selectorLabels" .root | nindent 6 }}
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

{{/*
Common pod spec fragments.
*/}}
{{- define "redis.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "redis.serviceAccountName" . }}
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
