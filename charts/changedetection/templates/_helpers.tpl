{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "changedetection.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "changedetection.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "changedetection.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "changedetection.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "changedetection.labels" -}}
helm.sh/chart: {{ include "changedetection.chart" . }}
{{ include "changedetection.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "changedetection.selectorLabels" -}}
app.kubernetes.io/name: {{ include "changedetection.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "changedetection.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "changedetection.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "changedetection.validate" -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.enabled requires ingress.hosts to contain at least one host" -}}
{{- end -}}
{{- if and .Values.gateway.enabled (not .Values.gateway.parentRefs) -}}
{{- fail "gateway.enabled requires gateway.parentRefs to be populated to create a valid HTTPRoute." -}}
{{- end -}}
{{- if .Values.gateway.enabled -}}
{{- range $index, $parentRef := .Values.gateway.parentRefs -}}
{{- if not $parentRef.name -}}
{{- fail (printf "gateway.parentRefs[%d].name is required when gateway.enabled is true" $index) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.data) (not .Values.externalSecrets.dataFrom) -}}
{{- fail "externalSecrets.data or externalSecrets.dataFrom is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- $selectorLabels := include "changedetection.selectorLabels" . | fromYaml -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if hasKey $selectorLabels $key -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "changedetection.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Data PVC claim name */}}
{{- define "changedetection.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "changedetection.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "changedetection.externalSecretName" -}}
{{- default (printf "%s-env" (include "changedetection.fullname" .)) .Values.externalSecrets.target.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
