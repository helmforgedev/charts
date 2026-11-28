{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "clickhouse.fullname" -}}
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

{{- define "clickhouse.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{- define "clickhouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "clickhouse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "clickhouse.labels" -}}
helm.sh/chart: {{ include "clickhouse.chart" . }}
{{ include "clickhouse.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "clickhouse.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "clickhouse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "clickhouse.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.suffixedName" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (max 1 (sub 63 (len $suffix))) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "clickhouse.headlessServiceName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-headless") -}}
{{- end -}}

{{- define "clickhouse.configMapName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-config") -}}
{{- end -}}

{{- define "clickhouse.secretName" -}}
{{- if .Values.clickhouse.existingSecret -}}
{{- .Values.clickhouse.existingSecret -}}
{{- else -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-auth") -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" $root) "suffix" (printf "-%s" $item.name)) -}}
{{- else if gt $index 0 -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "clickhouse.secretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.renderAnnotations" -}}
{{- with .Values.commonAnnotations }}
annotations:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "clickhouse.isStandalone" -}}
{{- if eq (.Values.architecture | default "standalone") "standalone" -}}true{{- end -}}
{{- end -}}

{{- define "clickhouse.isReplicated" -}}
{{- if eq .Values.architecture "replicated" -}}true{{- end -}}
{{- end -}}

{{- define "clickhouse.shards" -}}
{{- if include "clickhouse.isReplicated" . -}}
{{- .Values.replicated.shards | int -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

{{- define "clickhouse.replicasPerShard" -}}
{{- if include "clickhouse.isReplicated" . -}}
{{- .Values.replicated.replicasPerShard | int -}}
{{- else -}}
{{- .Values.replicaCount | int -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.clusterName" -}}
{{- if include "clickhouse.isReplicated" . -}}
{{- .Values.replicated.clusterName -}}
{{- else -}}
default
{{- end -}}
{{- end -}}

{{- define "clickhouse.shardStatefulSetName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .root) "suffix" (printf "-shard%d" (.shard | int))) -}}
{{- end -}}

{{- define "clickhouse.keeperEnabled" -}}
{{- if and (include "clickhouse.isReplicated" .) .Values.replicated.keeper.enabled (empty .Values.replicated.externalZookeeper.servers) -}}true{{- end -}}
{{- end -}}

{{- define "clickhouse.keeperFullname" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-keeper") -}}
{{- end -}}

{{- define "clickhouse.keeperHeadlessServiceName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-keeper-headless") -}}
{{- end -}}

{{- define "clickhouse.keeperConfigMapName" -}}
{{- include "clickhouse.suffixedName" (dict "base" (include "clickhouse.fullname" .) "suffix" "-keeper-config") -}}
{{- end -}}

{{- define "clickhouse.keeperImage" -}}
{{- $tag := .Values.replicated.keeper.image.tag | default .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.replicated.keeper.image.repository $tag -}}
{{- end -}}

{{- define "clickhouse.keeperSelectorLabels" -}}
{{ include "clickhouse.selectorLabels" . }}
app.kubernetes.io/component: keeper
{{- end -}}

{{- define "clickhouse.serverSelectorLabels" -}}
{{ include "clickhouse.selectorLabels" . }}
app.kubernetes.io/component: clickhouse
{{- end -}}

{{- define "clickhouse.podFQDN" -}}
{{- /* Usage: include "clickhouse.podFQDN" (dict "root" $ "podName" $name) */ -}}
{{- printf "%s.%s.%s.svc.%s" .podName (include "clickhouse.headlessServiceName" .root) (include "clickhouse.namespace" .root) .root.Values.clusterDomain -}}
{{- end -}}

{{- define "clickhouse.keeperPodFQDN" -}}
{{- printf "%s.%s.%s.svc.%s" .podName (include "clickhouse.keeperHeadlessServiceName" .root) (include "clickhouse.namespace" .root) .root.Values.clusterDomain -}}
{{- end -}}

{{- define "clickhouse.coordinationNodes" -}}
{{- $root := . -}}
{{- if not (empty .Values.replicated.externalZookeeper.servers) -}}
{{- range .Values.replicated.externalZookeeper.servers }}
<node>
  <host>{{ .host }}</host>
  <port>{{ .port | default 2181 }}</port>
</node>
{{- end }}
{{- else if .Values.replicated.keeper.enabled -}}
{{- $replicas := int .Values.replicated.keeper.replicaCount -}}
{{- $port := int .Values.replicated.keeper.ports.client -}}
{{- range $i := until $replicas }}
{{- $pod := printf "%s-%d" (include "clickhouse.keeperFullname" $root) $i }}
<node>
  <host>{{ include "clickhouse.keeperPodFQDN" (dict "root" $root "podName" $pod) }}</host>
  <port>{{ $port }}</port>
</node>
{{- end }}
{{- end -}}
{{- end -}}

{{- define "clickhouse.remoteServersXML" -}}
{{- $root := . -}}
{{- $shards := int .Values.replicated.shards -}}
{{- $replicas := int .Values.replicated.replicasPerShard -}}
{{- $cluster := .Values.replicated.clusterName -}}
{{- $tcpPort := int .Values.service.ports.tcp -}}
<remote_servers>
  <{{ $cluster }}>
{{- range $shard := until $shards }}
    <shard>
      <internal_replication>{{ ternary "true" "false" $root.Values.replicated.internalReplication }}</internal_replication>
{{- range $replica := until $replicas }}
{{- $sts := include "clickhouse.shardStatefulSetName" (dict "root" $root "shard" $shard) }}
{{- $pod := printf "%s-%d" $sts $replica }}
      <replica>
        <host>{{ include "clickhouse.podFQDN" (dict "root" $root "podName" $pod) }}</host>
        <port>{{ $tcpPort }}</port>
      </replica>
{{- end }}
    </shard>
{{- end }}
  </{{ $cluster }}>
</remote_servers>
{{- end -}}

{{- define "clickhouse.validate" -}}
{{- $arch := .Values.architecture | default "standalone" -}}
{{- if and (ne $arch "standalone") (ne $arch "replicated") -}}
{{- fail "architecture must be standalone or replicated" -}}
{{- end -}}
{{- if eq $arch "standalone" -}}
{{- if lt (.Values.replicaCount | int) 1 -}}{{- fail "replicaCount must be at least 1" -}}{{- end -}}
{{- if gt (.Values.replicaCount | int) 1 -}}{{- fail "replicaCount > 1 is intentionally blocked when architecture=standalone; set architecture=replicated for multi-node clusters" -}}{{- end -}}
{{- else -}}
{{- if lt (.Values.replicated.shards | int) 1 -}}{{- fail "replicated.shards must be at least 1" -}}{{- end -}}
{{- if lt (.Values.replicated.replicasPerShard | int) 1 -}}{{- fail "replicated.replicasPerShard must be at least 1" -}}{{- end -}}
{{- if empty .Values.replicated.clusterName -}}{{- fail "replicated.clusterName must not be empty" -}}{{- end -}}
{{- $hasExternal := not (empty .Values.replicated.externalZookeeper.servers) -}}
{{- if and (not .Values.replicated.keeper.enabled) (not $hasExternal) -}}
{{- fail "architecture=replicated requires replicated.keeper.enabled=true or replicated.externalZookeeper.servers" -}}
{{- end -}}
{{- if and .Values.replicated.keeper.enabled (not $hasExternal) -}}
{{- $k := .Values.replicated.keeper.replicaCount | int -}}
{{- if lt $k 1 -}}{{- fail "replicated.keeper.replicaCount must be at least 1" -}}{{- end -}}
{{- if and (gt $k 1) (ne (mod $k 2) 1) -}}{{- fail "replicated.keeper.replicaCount must be odd when greater than 1" -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}{{- fail "metrics.serviceMonitor.enabled requires metrics.enabled=true" -}}{{- end -}}
{{- if and .Values.clickhouse.existingSecret .Values.clickhouse.password -}}{{- fail "clickhouse.existingSecret and clickhouse.password are mutually exclusive" -}}{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{- fail "podLabels must not override app.kubernetes.io/name" -}}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{- fail "podLabels must not override app.kubernetes.io/instance" -}}{{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}{{- end -}}
{{- end -}}
