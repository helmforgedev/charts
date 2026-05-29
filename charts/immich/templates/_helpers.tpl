{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "immich.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "immich.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- $name := include "immich.name" . -}}{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}{{- end -}}
{{- define "immich.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "immich.selectorLabels" -}}
app.kubernetes.io/name: {{ include "immich.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "immich.labels" -}}
helm.sh/chart: {{ include "immich.chart" . }}
{{ include "immich.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "immich.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "immich.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "immich.databaseHost" -}}{{- if .Values.database.internal.enabled -}}{{ include "immich.fullname" . }}-postgresql{{- else -}}{{ .Values.database.external.host }}{{- end -}}{{- end -}}
{{- define "immich.databaseSecretName" -}}{{- if and (not .Values.database.internal.enabled) .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecret }}{{- else -}}{{ include "immich.fullname" . }}-database{{- end -}}{{- end -}}
{{- define "immich.databaseSecretKey" -}}{{- if and (not .Values.database.internal.enabled) .Values.database.external.existingSecret -}}{{ .Values.database.external.existingSecretPasswordKey }}{{- else -}}database-password{{- end -}}{{- end -}}
{{- define "immich.databasePassword" -}}
{{- $secretName := include "immich.databaseSecretName" . -}}
{{- if .Values.database.external.password -}}{{ .Values.database.external.password }}{{- else -}}{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}{{- if and $existing (index $existing.data "database-password") -}}{{ index $existing.data "database-password" | b64dec }}{{- else -}}{{ randAlphaNum 32 }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "immich.valkeyHost" -}}{{- if .Values.valkey.internal.enabled -}}{{ include "immich.fullname" . }}-valkey{{- else -}}{{ .Values.valkey.external.host }}{{- end -}}{{- end -}}
{{- define "immich.redisSecretName" -}}{{- if and (not .Values.valkey.internal.enabled) .Values.valkey.external.existingSecret -}}{{ .Values.valkey.external.existingSecret }}{{- else -}}{{ include "immich.fullname" . }}-redis{{- end -}}{{- end -}}
{{- define "immich.redisSecretKey" -}}{{- if and (not .Values.valkey.internal.enabled) .Values.valkey.external.existingSecret -}}{{ .Values.valkey.external.existingSecretPasswordKey }}{{- else -}}redis-password{{- end -}}{{- end -}}
{{- define "immich.mlUrl" -}}http://{{ include "immich.fullname" . }}-machine-learning:{{ .Values.machineLearning.service.port }}{{- end -}}

{{- define "immich.validate" -}}
{{- $serverScaled := or .Values.autoscaling.enabled (gt (.Values.server.replicaCount | int) 1) -}}
{{- if and .Values.server.persistence.enabled $serverScaled (not (has "ReadWriteMany" .Values.server.persistence.accessModes)) -}}
{{- fail "server persistence requires ReadWriteMany accessModes when server replicas or autoscaling are enabled" -}}
{{- end -}}
{{- if and .Values.machineLearning.enabled .Values.machineLearning.persistence.enabled (gt (.Values.machineLearning.replicaCount | int) 1) (not (has "ReadWriteMany" .Values.machineLearning.persistence.accessModes)) -}}
{{- fail "machineLearning persistence requires ReadWriteMany accessModes when machineLearning.replicaCount is greater than 1" -}}
{{- end -}}
{{- end -}}
