{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "qdrant.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "qdrant.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "qdrant.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "qdrant.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "qdrant.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qdrant.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "qdrant.labels" -}}
helm.sh/chart: {{ include "qdrant.chart" . }}
{{ include "qdrant.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "qdrant.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "qdrant.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "qdrant.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "qdrant.validate" -}}
{{- if and .Values.cluster.enabled (lt (int .Values.replicaCount) 2) -}}
{{- fail "cluster.enabled requires replicaCount >= 2" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (not .Values.cluster.enabled) -}}
{{- fail "replicaCount > 1 requires cluster.enabled=true so Qdrant pods form one distributed cluster" -}}
{{- end -}}
{{- if and .Values.cluster.enabled (not .Values.persistence.enabled) -}}
{{- fail "cluster.enabled requires persistence.enabled=true" -}}
{{- end -}}
{{- if and .Values.cluster.enabled .Values.persistence.existingClaim -}}
{{- fail "cluster.enabled requires generated per-pod PVCs; do not set persistence.existingClaim" -}}
{{- end -}}
{{- if and .Values.cluster.enabled .Values.app.command -}}
{{- fail "cluster.enabled manages the Qdrant startup command for peer bootstrap; use app.args for extra Qdrant flags" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- if hasKey $podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey $podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
