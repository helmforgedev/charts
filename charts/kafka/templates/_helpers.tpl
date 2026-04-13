{{- define "kafka.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "kafka.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kafka.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "kafka.labels" -}}
helm.sh/chart: {{ include "kafka.chart" . }}
{{ include "kafka.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "kafka.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kafka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kafka.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "kafka.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "kafka.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "kafka.kraftSecretName" -}}
{{- if .Values.kraft.existingSecret -}}
{{- .Values.kraft.existingSecret -}}
{{- else -}}
{{- printf "%s-kraft" (include "kafka.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "kafka.scriptsConfigMapName" -}}
{{- printf "%s-scripts" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.metricsConfigMapName" -}}
{{- printf "%s-metrics" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.clientServiceName" -}}
{{- printf "%s" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.singleHeadlessServiceName" -}}
{{- printf "%s-headless" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.controllerHeadlessServiceName" -}}
{{- printf "%s-controller-headless" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.brokerHeadlessServiceName" -}}
{{- printf "%s-broker-headless" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.singleStatefulSetName" -}}
{{- printf "%s" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.controllerStatefulSetName" -}}
{{- printf "%s-controller" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.brokerStatefulSetName" -}}
{{- printf "%s-broker" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.singleMetricsServiceName" -}}
{{- printf "%s-metrics" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.controllerMetricsServiceName" -}}
{{- printf "%s-controller-metrics" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.brokerMetricsServiceName" -}}
{{- printf "%s-broker-metrics" (include "kafka.fullname" .) -}}
{{- end -}}

{{- define "kafka.internalReplicationFactor" -}}
{{- if eq .Values.architecture "cluster" -}}
{{- if eq (.Values.cluster.brokers.replicaCount | int) 0 -}}
{{- min 3 (.Values.cluster.controllers.replicaCount | int) -}}
{{- else -}}
{{- min 3 (.Values.cluster.brokers.replicaCount | int) -}}
{{- end -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

{{- define "kafka.minInSyncReplicas" -}}
{{- if eq .Values.architecture "cluster" -}}
{{- .Values.cluster.minInSyncReplicas | int -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

{{- define "kafka.clusterId" -}}
{{- $secretName := include "kafka.kraftSecretName" . -}}
{{- if .Values.kraft.existingSecret -}}
{{- "" -}}
{{- else if .Values.kraft.clusterId -}}
{{- .Values.kraft.clusterId -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $existing -}}
{{- index $existing.data .Values.kraft.existingSecretClusterIdKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 22 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kafka.controllerDirectoryId" -}}
{{- $root := .root -}}
{{- $index := .index | int -}}
{{- $key := printf "%s-%d-directory-id" $root.Values.kraft.existingSecretControllerDirectoryIdPrefix $index -}}
{{- $secretName := include "kafka.kraftSecretName" $root -}}
{{- if $root.Values.kraft.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" $root.Release.Namespace $secretName -}}
{{- if $existing -}}
{{- index $existing.data $key | b64dec -}}
{{- else -}}
{{- randAlphaNum 22 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kafka.controllerBootstrapServers" -}}
{{- if eq .Values.architecture "cluster" -}}
{{- $name := include "kafka.controllerHeadlessServiceName" . -}}
{{- $count := .Values.cluster.controllers.replicaCount | int -}}
{{- $parts := list -}}
{{- range $i := until $count -}}
{{- $parts = append $parts (printf "%s-%d.%s.%s.svc.%s:%d" (include "kafka.controllerStatefulSetName" $) $i $name $.Release.Namespace $.Values.clusterDomain ($.Values.listeners.controller.port | int)) -}}
{{- end -}}
{{- join "," $parts -}}
{{- else -}}
{{- printf "%s-0.%s.%s.svc.%s:%d" (include "kafka.singleStatefulSetName" .) (include "kafka.singleHeadlessServiceName" .) .Release.Namespace .Values.clusterDomain (.Values.listeners.controller.port | int) -}}
{{- end -}}
{{- end -}}

{{- define "kafka.initialControllers" -}}
{{- $name := include "kafka.controllerHeadlessServiceName" . -}}
{{- $count := .Values.cluster.controllers.replicaCount | int -}}
{{- $parts := list -}}
{{- range $i := until $count -}}
{{- $dir := include "kafka.controllerDirectoryId" (dict "root" $ "index" $i) -}}
{{- $parts = append $parts (printf "%d@%s-%d.%s.%s.svc.%s:%d:%s" $i (include "kafka.controllerStatefulSetName" $) $i $name $.Release.Namespace $.Values.clusterDomain ($.Values.listeners.controller.port | int) $dir) -}}
{{- end -}}
{{- join "," $parts -}}
{{- end -}}

{{- define "kafka.singlePodDns" -}}
{{- printf "%s-0.%s.%s.svc.%s" (include "kafka.singleStatefulSetName" .) (include "kafka.singleHeadlessServiceName" .) .Release.Namespace .Values.clusterDomain -}}
{{- end -}}

{{- define "kafka.validate" -}}
{{- if not (or (eq .Values.architecture "single-broker") (eq .Values.architecture "cluster")) -}}
{{- fail "architecture must be single-broker or cluster" -}}
{{- end -}}
{{- if and (eq .Values.architecture "cluster") (lt (.Values.cluster.controllers.replicaCount | int) 3) -}}
{{- fail "cluster.controllers.replicaCount must be at least 3 for cluster mode" -}}
{{- end -}}
{{- if and (eq .Values.architecture "cluster") (gt (.Values.cluster.brokers.replicaCount | int) 0) (lt (.Values.cluster.brokers.replicaCount | int) 3) -}}
{{- fail "cluster.brokers.replicaCount must be 0 (combined mode: controllers act as brokers) or at least 3 for dedicated-broker mode" -}}
{{- end -}}
{{- if and (eq .Values.architecture "cluster") (gt (.Values.cluster.brokers.replicaCount | int) 0) (gt (.Values.cluster.minInSyncReplicas | int) (.Values.cluster.brokers.replicaCount | int)) -}}
{{- fail "cluster.minInSyncReplicas cannot be greater than cluster.brokers.replicaCount" -}}
{{- end -}}
{{- if and (eq .Values.architecture "cluster") (eq (.Values.cluster.brokers.replicaCount | int) 0) (gt (.Values.cluster.minInSyncReplicas | int) (.Values.cluster.controllers.replicaCount | int)) -}}
{{- fail "cluster.minInSyncReplicas cannot be greater than cluster.controllers.replicaCount in combined mode" -}}
{{- end -}}
{{- end -}}
