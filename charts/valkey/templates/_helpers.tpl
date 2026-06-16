{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "valkey.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "valkey.fullname" -}}
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
{{- define "valkey.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "valkey.labels" -}}
helm.sh/chart: {{ include "valkey.chart" . }}
{{ include "valkey.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Merge global annotations with resource-specific annotations.
Resource-specific annotations win when keys overlap.
*/}}
{{- define "valkey.annotations" -}}
{{- $global := default dict .root.Values.annotations -}}
{{- $local := default dict .annotations -}}
{{- $annotations := mergeOverwrite (deepCopy $global) $local -}}
{{- with $annotations -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}

{{- define "valkey.renderAnnotations" -}}
{{- $annotations := include "valkey.annotations" . -}}
{{- if $annotations }}
annotations:
{{ $annotations | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "valkey.serviceAnnotations" -}}
{{- $global := default dict .root.Values.annotations -}}
{{- $service := default dict .root.Values.service.annotations -}}
{{- $local := default dict .annotations -}}
{{- $annotations := mergeOverwrite (deepCopy $global) $service $local -}}
{{- with $annotations -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}

{{- define "valkey.renderServiceAnnotations" -}}
{{- $annotations := include "valkey.serviceAnnotations" . -}}
{{- if $annotations }}
annotations:
{{ $annotations | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "valkey.selectorLabels" -}}
app.kubernetes.io/name: {{ include "valkey.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name.
*/}}
{{- define "valkey.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "valkey.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Architecture checks.
*/}}
{{- define "valkey.isStandalone" -}}
{{- if eq .Values.architecture "standalone" -}}true{{- end -}}
{{- end -}}

{{- define "valkey.isReplication" -}}
{{- if eq .Values.architecture "replication" -}}true{{- end -}}
{{- end -}}

{{- define "valkey.isSentinel" -}}
{{- if eq .Values.architecture "sentinel" -}}true{{- end -}}
{{- end -}}

{{- define "valkey.isCluster" -}}
{{- if eq .Values.architecture "cluster" -}}true{{- end -}}
{{- end -}}

{{/*
Common names.
*/}}
{{- define "valkey.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "valkey.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "valkey.headlessServiceName" -}}
{{- printf "%s-headless" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.clientServiceName" -}}
{{- printf "%s-client" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.primaryServiceName" -}}
{{- printf "%s-primary" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.replicaServiceName" -}}
{{- printf "%s-replicas" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.sentinelServiceName" -}}
{{- printf "%s-sentinel" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.metricsServiceName" -}}
{{- printf "%s-metrics" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.primaryStatefulSetName" -}}
{{- printf "%s-primary" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.replicaStatefulSetName" -}}
{{- printf "%s-replica" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.sentinelStatefulSetName" -}}
{{- printf "%s-sentinel" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.clusterStatefulSetName" -}}
{{- printf "%s-cluster" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.configMapName" -}}
{{- printf "%s-config" (include "valkey.fullname" .) -}}
{{- end -}}

{{- define "valkey.clusterDomain" -}}
{{- default "cluster.local" .Values.clusterDomain -}}
{{- end -}}

{{- define "valkey.serviceFqdn" -}}
{{- printf "%s.%s.svc.%s" .name .root.Release.Namespace (include "valkey.clusterDomain" .root) -}}
{{- end -}}

{{- define "valkey.headlessServiceFqdn" -}}
{{- include "valkey.serviceFqdn" (dict "root" . "name" (include "valkey.headlessServiceName" .)) -}}
{{- end -}}

{{- define "valkey.fullnameFqdn" -}}
{{- include "valkey.serviceFqdn" (dict "root" . "name" (include "valkey.fullname" .)) -}}
{{- end -}}

{{- define "valkey.clientServiceFqdn" -}}
{{- include "valkey.serviceFqdn" (dict "root" . "name" (include "valkey.clientServiceName" .)) -}}
{{- end -}}

{{- define "valkey.primaryServiceFqdn" -}}
{{- include "valkey.serviceFqdn" (dict "root" . "name" (include "valkey.primaryServiceName" .)) -}}
{{- end -}}

{{- define "valkey.replicaServiceFqdn" -}}
{{- include "valkey.serviceFqdn" (dict "root" . "name" (include "valkey.replicaServiceName" .)) -}}
{{- end -}}

{{- define "valkey.sentinelServiceFqdn" -}}
{{- include "valkey.serviceFqdn" (dict "root" . "name" (include "valkey.sentinelServiceName" .)) -}}
{{- end -}}

{{- define "valkey.primaryPodFqdn" -}}
{{- printf "%s-0.%s" (include "valkey.primaryStatefulSetName" .) (include "valkey.headlessServiceFqdn" .) -}}
{{- end -}}

{{- define "valkey.clusterPodFqdn" -}}
{{- printf "%s.%s" .podName (include "valkey.headlessServiceFqdn" .root) -}}
{{- end -}}

{{/*
Secret value helpers.
*/}}
{{- define "valkey.password" -}}
{{- if .Values.auth.password -}}
{{- .Values.auth.password -}}
{{- else if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (include "valkey.secretName" .) -}}
{{- if and $secret $secret.data (hasKey $secret.data .Values.auth.existingSecretPasswordKey) -}}
{{- index $secret.data .Values.auth.existingSecretPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Authentication checksum for pod rollouts.
*/}}
{{- define "valkey.authChecksum" -}}
{{- $existingSecretData := "" -}}
{{- if .Values.auth.existingSecret -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.auth.existingSecret -}}
{{- if and $secret $secret.data (hasKey $secret.data .Values.auth.existingSecretPasswordKey) -}}
{{- $existingSecretData = index $secret.data .Values.auth.existingSecretPasswordKey -}}
{{- end -}}
{{- end -}}
{{- dict "password" .Values.auth.password "existingSecret" .Values.auth.existingSecret "key" .Values.auth.existingSecretPasswordKey "existingSecretData" $existingSecretData "externalSecrets" .Values.externalSecrets | toJson | sha256sum -}}
{{- end -}}

{{/*
Port helper for Valkey when TLS is enabled.
*/}}
{{- define "valkey.serverArgs" -}}
- /etc/valkey/valkey.conf
{{- if .Values.auth.enabled }}
- --requirepass
- $(VALKEY_PASSWORD)
{{- end }}
{{- end -}}

{{/*
TLS block for valkey.conf.
*/}}
{{- define "valkey.tlsConfig" -}}
{{- if .Values.tls.enabled }}
port 0
tls-port {{ .Values.service.ports.valkey }}
tls-cert-file /tls/{{ .Values.tls.certFilename }}
tls-key-file /tls/{{ .Values.tls.keyFilename }}
tls-ca-cert-file /tls/{{ .Values.tls.caFilename }}
tls-auth-clients no
{{- end }}
{{- end -}}

{{/*
TLS block for sentinel.conf.
*/}}
{{- define "valkey.sentinelTlsConfig" -}}
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

{{/*
valkey-cli TLS flags.
*/}}
{{- define "valkey.cliTlsArgs" -}}
{{- if .Values.tls.enabled -}}
--tls --cacert /tls/{{ .Values.tls.caFilename }}
{{- if .Values.tls.insecureSkipVerify }} --insecure{{- end }}
{{- end -}}
{{- end -}}

{{- define "valkey.probeTlsArgs" -}}
{{- if .Values.tls.enabled -}}
--tls --cacert /tls/{{ .Values.tls.caFilename }} --insecure
{{- end -}}
{{- end -}}

{{/*
Common valkey.conf baseline.
*/}}
{{- define "valkey.commonConfig" -}}
bind 0.0.0.0
protected-mode no
{{- if not .Values.tls.enabled }}
port {{ .Values.service.ports.valkey }}
{{- end }}
dir /data
appendonly yes
save 900 1
save 300 10
save 60 10000
{{ include "valkey.tlsConfig" . }}
{{- end -}}

{{/*
Probe command.
*/}}
{{- define "valkey.probeCommand" -}}
{{- if .Values.auth.enabled -}}
valkey-cli {{ include "valkey.probeTlsArgs" . }} -p {{ .Values.service.ports.valkey }} -a "$VALKEY_PASSWORD" --no-auth-warning ping
{{- else -}}
valkey-cli {{ include "valkey.probeTlsArgs" . }} -p {{ .Values.service.ports.valkey }} ping
{{- end -}}
{{- end -}}

{{/*
Exporter environment.
*/}}
{{- define "valkey.exporterEnv" -}}
- name: REDIS_ADDR
  value: {{ ternary "rediss" "redis" .Values.tls.enabled }}://127.0.0.1:{{ .Values.service.ports.valkey }}
{{- if .Values.tls.enabled }}
- name: REDIS_EXPORTER_TLS_CA_CERT_FILE
  value: /tls/{{ .Values.tls.caFilename }}
{{- if .Values.metrics.tlsSkipVerify }}
- name: REDIS_EXPORTER_SKIP_TLS_VERIFICATION
  value: "true"
{{- end }}
{{- end }}
{{- if .Values.auth.enabled }}
- name: REDIS_USER
  value: default
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "valkey.secretName" . }}
      key: {{ .Values.auth.existingSecretPasswordKey }}
{{- end }}
{{- end -}}

{{- define "valkey.metricsVolumeMounts" -}}
{{- if .Values.tls.enabled }}
volumeMounts:
  - name: tls
    mountPath: /tls
    readOnly: true
{{- end }}
{{- end -}}

{{/*
Pod labels with component and role.
*/}}
{{- define "valkey.componentLabels" -}}
{{ include "valkey.selectorLabels" .root }}
app.kubernetes.io/component: valkey
app.kubernetes.io/part-of: valkey
{{- if .role }}
app.kubernetes.io/role: {{ .role }}
{{- end }}
{{- end -}}

{{/*
Volume claim template.
*/}}
{{- define "valkey.volumeClaimTemplate" -}}
- metadata:
    name: data
    labels:
      {{- include "valkey.selectorLabels" .root | nindent 6 }}
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
{{- define "valkey.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "valkey.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.automountServiceAccountToken }}
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
