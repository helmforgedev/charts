{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "mosquitto.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mosquitto.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "mosquitto.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mosquitto.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "mosquitto.labels" -}}
helm.sh/chart: {{ include "mosquitto.chart" . }}
app.kubernetes.io/name: {{ include "mosquitto.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mosquitto
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "mosquitto.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mosquitto.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mosquitto.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "mosquitto.mqttxImage" -}}
{{- printf "%s:%s" .Values.mqttxWeb.image.repository .Values.mqttxWeb.image.tag -}}
{{- end -}}

{{- define "mosquitto.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "mosquitto.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "mosquitto.authSecretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "mosquitto.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mosquitto.aclConfigMapName" -}}
{{- if .Values.acl.existingConfigMap -}}
{{- .Values.acl.existingConfigMap -}}
{{- else -}}
{{- printf "%s-acl" (include "mosquitto.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "mosquitto.statefulsetName" -}}
{{- include "mosquitto.fullname" . -}}
{{- end -}}

{{- define "mosquitto.headlessServiceName" -}}
{{- printf "%s-headless" (include "mosquitto.fullname" .) -}}
{{- end -}}

{{- define "mosquitto.websocketHost" -}}
{{- if .Values.mqttxWeb.broker.host -}}
{{- .Values.mqttxWeb.broker.host -}}
{{- else if and .Values.websocketIngress.enabled (gt (len .Values.websocketIngress.hosts) 0) -}}
{{- (index .Values.websocketIngress.hosts 0).host -}}
{{- else -}}
{{- printf "%s.%s.svc.%s" (include "mosquitto.fullname" .) .Release.Namespace .Values.clusterDomain -}}
{{- end -}}
{{- end -}}

{{- define "mosquitto.websocketPort" -}}
{{- if gt (int .Values.mqttxWeb.broker.port) 0 -}}
{{- .Values.mqttxWeb.broker.port -}}
{{- else if .Values.websocketIngress.enabled -}}
{{- ternary 443 80 (gt (len .Values.websocketIngress.tls) 0) -}}
{{- else -}}
{{- .Values.service.websocketPort -}}
{{- end -}}
{{- end -}}

{{- define "mosquitto.websocketUrl" -}}
{{- printf "%s://%s:%v%s" .Values.mqttxWeb.broker.scheme (include "mosquitto.websocketHost" .) (include "mosquitto.websocketPort" .) .Values.mqttxWeb.broker.path -}}
{{- end -}}

{{- define "mosquitto.defaultAffinityEnabled" -}}
{{- if and (eq .Values.architecture.mode "federated") (gt (int .Values.broker.replicaCount) 1) .Values.broker.multiReplicaDefaults.enabled (ne .Values.broker.multiReplicaDefaults.podAntiAffinity "none") -}}true{{- end -}}
{{- end -}}

{{- define "mosquitto.defaultTopologySpreadEnabled" -}}
{{- if and (eq .Values.architecture.mode "federated") (gt (int .Values.broker.replicaCount) 1) .Values.broker.multiReplicaDefaults.enabled .Values.broker.multiReplicaDefaults.topologySpread.enabled -}}true{{- end -}}
{{- end -}}

{{- define "mosquitto.validate" -}}
{{- if and (eq .Values.architecture.mode "standalone") (ne (int .Values.broker.replicaCount) 1) -}}
{{- fail "mosquitto: architecture.mode=standalone requires broker.replicaCount=1" -}}
{{- end -}}
{{- if and (eq .Values.architecture.mode "federated") (lt (int .Values.broker.replicaCount) 2) -}}
{{- fail "mosquitto: architecture.mode=federated requires broker.replicaCount>=2" -}}
{{- end -}}
{{- if and .Values.broker.tls.enabled (not .Values.broker.tls.certSecretName) -}}
{{- fail "mosquitto: broker.tls.certSecretName is required when broker.tls.enabled=true" -}}
{{- end -}}
{{- if and .Values.broker.tls.enabled (eq (int .Values.broker.tls.port) (int .Values.broker.listeners.mqtt)) -}}
{{- fail "mosquitto: broker.tls.port must differ from broker.listeners.mqtt" -}}
{{- end -}}
{{- if and .Values.broker.tls.enabled (eq (int .Values.broker.tls.port) (int .Values.broker.listeners.websocket)) -}}
{{- fail "mosquitto: broker.tls.port must differ from broker.listeners.websocket" -}}
{{- end -}}
{{- if and .Values.broker.tls.enabled (eq .Values.architecture.mode "federated") -}}
{{- fail "mosquitto: broker.tls.enabled=true is not supported with architecture.mode=federated" -}}
{{- end -}}
{{- if and .Values.websocketIngress.enabled (empty .Values.websocketIngress.hosts) -}}
{{- fail "mosquitto: websocketIngress.hosts must contain at least one host when websocketIngress.enabled=true" -}}
{{- end -}}
{{- if and .Values.mqttxWeb.ingress.enabled (not .Values.mqttxWeb.enabled) -}}
{{- fail "mosquitto: mqttxWeb.enabled must be true when mqttxWeb.ingress.enabled=true" -}}
{{- end -}}
{{- if and .Values.mqttxWeb.ingress.enabled (empty .Values.mqttxWeb.ingress.hosts) -}}
{{- fail "mosquitto: mqttxWeb.ingress.hosts must contain at least one host when mqttxWeb.ingress.enabled=true" -}}
{{- end -}}
{{- range $labels := list .Values.podLabels .Values.mqttxWeb.podLabels -}}
{{- if hasKey $labels "app.kubernetes.io/name" -}}
{{- fail "mosquitto: podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey $labels "app.kubernetes.io/instance" -}}
{{- fail "mosquitto: podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- if hasKey $labels "app.kubernetes.io/component" -}}
{{- fail "mosquitto: podLabels must not override the selector label app.kubernetes.io/component" -}}
{{- end -}}
{{- end -}}
{{- end -}}
