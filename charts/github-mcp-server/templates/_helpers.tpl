{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "github-mcp-server.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "github-mcp-server.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "github-mcp-server.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "github-mcp-server.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "github-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "github-mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "github-mcp-server.labels" -}}
helm.sh/chart: {{ include "github-mcp-server.chart" . }}
{{ include "github-mcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "github-mcp-server.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "github-mcp-server.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "github-mcp-server.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "github-mcp-server.githubHostArg" -}}
{{- $host := trim .Values.github.host -}}
{{- if $host -}}
{{- if or (hasPrefix "http://" $host) (hasPrefix "https://" $host) -}}
{{- $host -}}
{{- else -}}
{{- printf "https://%s" $host -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "github-mcp-server.validate" -}}
{{- if and .Values.github.requireToken (not (or .Values.github.personalAccessToken .Values.github.existingSecret)) -}}
{{- fail "github.requireToken=true requires github.personalAccessToken or github.existingSecret" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.persistence.enabled (not .Values.persistence.existingClaim) (not (has "ReadWriteMany" .Values.persistence.accessModes)) -}}
{{- fail "replicaCount > 1 with persistence.enabled requires persistence.accessModes to include ReadWriteMany or persistence.enabled=false" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- range $key := (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}
{{- if hasKey $podLabels $key -}}
{{- fail (printf "podLabels must not override the selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
