{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "redis.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Validate values that must fail before rendering workloads. */}}
{{- define "redis.validate" -}}
{{- if has .Values.image.tag (list "latest" "stable" "main" "master" "edge") -}}
{{- fail "image.tag must be an immutable release tag" -}}
{{- end -}}
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
app.kubernetes.io/part-of: helmforge
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

{{- define "redis.sentinelHeadlessServiceName" -}}
{{- printf "%s-sentinel-headless" (include "redis.fullname" .) -}}
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

{{- define "redis.nodeStatefulSetName" -}}
{{- printf "%s-node" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.configMapName" -}}
{{- printf "%s-config" (include "redis.fullname" .) -}}
{{- end -}}

{{- define "redis.clusterDomain" -}}
{{- default "cluster.local" .Values.clusterDomain -}}
{{- end -}}

{{- define "redis.serviceFqdn" -}}
{{- printf "%s.%s.svc.%s" .name .root.Release.Namespace (include "redis.clusterDomain" .root) -}}
{{- end -}}

{{- define "redis.headlessServiceFqdn" -}}
{{- include "redis.serviceFqdn" (dict "root" . "name" (include "redis.headlessServiceName" .)) -}}
{{- end -}}

{{- define "redis.fullnameFqdn" -}}
{{- include "redis.serviceFqdn" (dict "root" . "name" (include "redis.fullname" .)) -}}
{{- end -}}

{{- define "redis.clientServiceFqdn" -}}
{{- include "redis.serviceFqdn" (dict "root" . "name" (include "redis.clientServiceName" .)) -}}
{{- end -}}

{{- define "redis.primaryServiceFqdn" -}}
{{- include "redis.serviceFqdn" (dict "root" . "name" (include "redis.primaryServiceName" .)) -}}
{{- end -}}

{{- define "redis.replicaServiceFqdn" -}}
{{- include "redis.serviceFqdn" (dict "root" . "name" (include "redis.replicaServiceName" .)) -}}
{{- end -}}

{{- define "redis.sentinelServiceFqdn" -}}
{{- include "redis.serviceFqdn" (dict "root" . "name" (include "redis.sentinelServiceName" .)) -}}
{{- end -}}

{{- define "redis.primaryPodFqdn" -}}
{{- printf "%s-0.%s" (include "redis.primaryStatefulSetName" .) (include "redis.headlessServiceFqdn" .) -}}
{{- end -}}

{{- define "redis.nodePodFqdn" -}}
{{- printf "%s-0.%s" (include "redis.nodeStatefulSetName" .) (include "redis.headlessServiceFqdn" .) -}}
{{- end -}}

{{- define "redis.nodePeerFqdns" -}}
{{- $root := . -}}
{{- $fqdns := list -}}
{{- range $i := until (int .Values.node.replicaCount) -}}
{{- $fqdns = append $fqdns (printf "%s-%d.%s" (include "redis.nodeStatefulSetName" $root) $i (include "redis.headlessServiceFqdn" $root)) -}}
{{- end -}}
{{- join " " $fqdns -}}
{{- end -}}

{{- define "redis.clusterPodFqdn" -}}
{{- printf "%s.%s" .podName (include "redis.headlessServiceFqdn" .root) -}}
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

{{- define "redis.authChecksum" -}}
{{- dict "password" .Values.auth.password "existingSecret" .Values.auth.existingSecret "key" .Values.auth.existingSecretPasswordKey "externalSecrets" .Values.externalSecrets | toJson | sha256sum -}}
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

{{- define "redis.sentinelTlsConfig" -}}
{{- if .Values.tls.enabled }}
port 0
tls-port {{ .Values.service.ports.sentinel }}
tls-cert-file /tls/{{ .Values.tls.certFilename }}
tls-key-file /tls/{{ .Values.tls.keyFilename }}
tls-ca-cert-file /tls/{{ .Values.tls.caFilename }}
tls-auth-clients no
tls-replication yes
{{- end }}
{{- end -}}

{{- define "redis.cliTlsArgs" -}}
{{- if .Values.tls.enabled -}}
--tls --cacert /tls/{{ .Values.tls.caFilename }}
{{- end -}}
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

{{- define "redis.redisLabels" -}}
{{- include "redis.componentLabels" . -}}
{{- end -}}

{{- define "redis.sentinelLabels" -}}
{{ include "redis.selectorLabels" . }}
app.kubernetes.io/component: sentinel
{{- end -}}

{{- define "redis.renderAnnotations" -}}
{{- with .root.Values.annotations }}
annotations:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "redis.podSpec" -}}
{{- include "redis.podSpecCommon" .root -}}
{{- end -}}

{{- define "redis.nodeProbeCommand" -}}
{{- include "redis.probeCommand" . -}}
{{- end -}}

{{- define "redis.sentinelProbeCommand" -}}
redis-cli -p {{ .Values.service.ports.sentinel }} ping
{{- end -}}

{{- define "redis.sentinelReadyCommand" -}}
redis-cli -p {{ .Values.service.ports.sentinel }} sentinel get-master-addr-by-name {{ .Values.sentinel.masterSet }} | grep -q .
{{- end -}}

{{- define "redis.metricsVolumeMounts" -}}
{{- if .Values.tls.enabled }}
volumeMounts:
  - name: tls
    mountPath: /tls
    readOnly: true
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
