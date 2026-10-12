{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ib-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "ib-gateway.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "ib-gateway.name" . -}}
{{- if contains $name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- end -}}
{{- define "ib-gateway.chart" -}}{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "ib-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ib-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "ib-gateway.labels" -}}
helm.sh/chart: {{ include "ib-gateway.chart" . }}
{{ include "ib-gateway.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "ib-gateway.image" -}}
{{- if .Values.image.digest -}}{{ printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- end -}}
{{- define "ib-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "ib-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}
{{- define "ib-gateway.claimName" -}}{{ default (include "ib-gateway.fullname" .) .Values.persistence.existingClaim }}{{- end -}}
{{- define "ib-gateway.secretName" -}}{{ default (include "ib-gateway.fullname" .) .Values.auth.existingSecret }}{{- end -}}
{{- define "ib-gateway.vncSecretName" -}}
{{- if .Values.vnc.existingSecret -}}{{ .Values.vnc.existingSecret }}
{{- else -}}{{ include "ib-gateway.secretName" . }}{{- end -}}
{{- end -}}
{{- define "ib-gateway.externalSecretName" -}}
{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .item.name -}}{{ printf "%s-%s" (include "ib-gateway.fullname" .root) .item.name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ include "ib-gateway.fullname" .root }}{{- end -}}
{{- end -}}
{{- define "ib-gateway.bool" -}}{{ ternary "yes" "no" . }}{{- end -}}
{{- define "ib-gateway.apiProbeCommand" -}}
{{- if and (not .Values.auth.existingSecret) (or (not .Values.auth.username) (not .Values.auth.password)) -}}{{ include "ib-gateway.livenessCommand" . }}
{{- else if eq .Values.gateway.tradingMode "live" -}}socat -u /dev/null TCP:127.0.0.1:4001,connect-timeout=2
{{- else if eq .Values.gateway.tradingMode "paper" -}}socat -u /dev/null TCP:127.0.0.1:4002,connect-timeout=2
{{- else -}}socat -u /dev/null TCP:127.0.0.1:4001,connect-timeout=2 && socat -u /dev/null TCP:127.0.0.1:4002,connect-timeout=2
{{- end -}}
{{- end -}}
{{- define "ib-gateway.livenessCommand" -}}
{{- if eq .Values.gateway.tradingMode "live" -}}test -s /tmp/pid_live && kill -0 "$(cat /tmp/pid_live)"
{{- else if eq .Values.gateway.tradingMode "paper" -}}test -s /tmp/pid_paper && kill -0 "$(cat /tmp/pid_paper)"
{{- else -}}test -s /tmp/pid_live && kill -0 "$(cat /tmp/pid_live)" && test -s /tmp/pid_paper && kill -0 "$(cat /tmp/pid_paper)"
{{- end -}}
{{- end -}}
{{- define "ib-gateway.validate" -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "IB Gateway requires replicaCount=1; concurrent account sessions are not safe high availability" }}{{- end -}}
{{- if not (has .Values.gateway.tradingMode (list "paper" "live" "both")) -}}{{ fail "gateway.tradingMode must be paper, live or both" }}{{- end -}}
{{- if and .Values.auth.existingSecret (or .Values.auth.username .Values.auth.password .Values.auth.paperUsername .Values.auth.paperPassword) -}}{{ fail "auth inline values cannot be combined with auth.existingSecret" }}{{- end -}}
{{- if and (eq .Values.gateway.tradingMode "both") (not .Values.auth.existingSecret) (or (not .Values.auth.paperUsername) (not .Values.auth.paperPassword)) -}}{{ fail "both mode requires paper credentials or auth.existingSecret" }}{{- end -}}
{{- if and .Values.vnc.enabled (not .Values.vnc.existingSecret) (not .Values.auth.existingSecret) (not .Values.vnc.password) -}}{{ fail "vnc.password, vnc.existingSecret or auth.existingSecret is required when vnc.enabled=true" }}{{- end -}}
{{- if and (not .Values.persistence.enabled) .Values.persistence.existingClaim -}}{{ fail "persistence.existingClaim requires persistence.enabled=true" }}{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{ fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" }}{{- end -}}
{{- range $labels := list .Values.podLabels .Values.commonLabels -}}
{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}
{{- if hasKey $labels $key -}}{{ fail (printf "custom labels must not override selector label %s" $key) }}{{- end -}}
{{- end -}}{{- end -}}
{{- end -}}
