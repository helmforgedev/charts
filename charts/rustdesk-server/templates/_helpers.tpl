{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "rustdesk-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "rustdesk-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "rustdesk-server.name" . -}}
{{- if contains $name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- end -}}
{{- define "rustdesk-server.chart" -}}{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "rustdesk-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rustdesk-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "rustdesk-server.labels" -}}
helm.sh/chart: {{ include "rustdesk-server.chart" . }}
{{ include "rustdesk-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "rustdesk-server.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- define "rustdesk-server.claimName" -}}{{ default (include "rustdesk-server.fullname" .) .Values.persistence.existingClaim }}{{- end -}}
{{- define "rustdesk-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "rustdesk-server.fullname" .) .Values.serviceAccount.name }}
{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}
{{- define "rustdesk-server.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .item.name -}}{{ printf "%s-%s" (include "rustdesk-server.fullname" .root) .item.name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ include "rustdesk-server.fullname" .root }}{{- end -}}
{{- end -}}
{{- define "rustdesk-server.httpRouteName" -}}
{{- if .route.name -}}{{ printf "%s-%s" (include "rustdesk-server.fullname" .root) .route.name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ include "rustdesk-server.fullname" .root }}{{- end -}}
{{- end -}}
{{- define "rustdesk-server.validate" -}}
{{- if and (or .Values.ingress.enabled .Values.gatewayAPI.enabled) (not .Values.websocket.enabled) -}}{{ fail "Ingress and HTTPRoute require websocket.enabled=true; native TCP/UDP cannot use HTTP routing" }}{{- end -}}
{{- if and .Values.ingress.enabled (or (not .Values.ingress.rendezvousHost) (not .Values.ingress.relayHost) (eq .Values.ingress.rendezvousHost .Values.ingress.relayHost)) -}}{{ fail "WebSocket Ingress requires two distinct nonempty hostnames" }}{{- end -}}
{{- if and .Values.auth.existingSecret (eq .Values.auth.privateKeyKey .Values.auth.publicKeyKey) -}}{{ fail "native private and public Secret keys must be distinct" }}{{- end -}}

{{- if not (semverCompare ">=1.29.0-0" .Capabilities.KubeVersion.Version) -}}
{{- fail "RustDesk ordered startup requires Kubernetes >=1.29 with native SidecarContainers enabled" -}}
{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "RustDesk requires exactly one rendezvous/relay pair; shared SQLite and in-memory relay pairs cannot scale horizontally" }}{{- end -}}
{{- range $labels := list .Values.podLabels .Values.commonLabels -}}
{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}
{{- if hasKey $labels $key -}}{{ fail (printf "custom labels must not override selector label %s" $key) }}{{- end -}}
{{- end -}}{{- end -}}
{{- $p := int .Values.server.rendezvousPort -}}
{{- $r := int .Values.server.relayPort -}}
{{- $ports := list (int (sub $p 1)) $p (int (add $p 2)) $r (int (add $r 2)) -}}
{{- if ne (len (uniq $ports)) 5 -}}{{ fail "RustDesk native and derived NAT/WebSocket listener ports must not overlap" }}{{- end -}}
{{- if and (not .Values.persistence.enabled) .Values.persistence.existingClaim -}}{{ fail "persistence.existingClaim requires persistence.enabled=true" }}{{- end -}}
{{- end -}}
