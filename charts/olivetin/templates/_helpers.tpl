{{/* SPDX-License-Identifier: Apache-2.0 */}}

{{- define "olivetin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "olivetin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "olivetin.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "olivetin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "olivetin.labels" -}}
helm.sh/chart: {{ include "olivetin.chart" . }}
{{ include "olivetin.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "olivetin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "olivetin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "olivetin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "olivetin.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "olivetin.httpRouteName" -}}
{{- $root := index . "root" -}}
{{- $route := index . "route" -}}
{{- $fullname := include "olivetin.fullname" $root -}}
{{- $routeName := $route.name | default "" | trunc 32 | trimSuffix "-" -}}
{{- if $routeName -}}
{{- $baseMaxLength := sub 62 (len $routeName) -}}
{{- printf "%s-%s" ($fullname | trunc (int $baseMaxLength) | trimSuffix "-") $routeName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $fullname -}}
{{- end -}}
{{- end -}}

{{- define "olivetin.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "olivetin.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "olivetin.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ConfigMap checksum annotation */}}
{{- define "olivetin.configChecksum" -}}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
{{- end -}}
