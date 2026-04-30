{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "adguard-home.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "adguard-home.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "adguard-home.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "adguard-home.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "adguard-home.labels" -}}
helm.sh/chart: {{ include "adguard-home.chart" . }}
{{ include "adguard-home.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "adguard-home.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adguard-home.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Image helper - tag prefixed with "v" */}}
{{- define "adguard-home.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Returns true when a pre-seed config is provided */}}
{{- define "adguard-home.hasConfig" -}}
{{- if or (not (empty .Values.config.adGuardHome)) .Values.config.existingSecret -}}true{{- end -}}
{{- end -}}

{{/* Config secret name */}}
{{- define "adguard-home.configSecretName" -}}
{{- if .Values.config.existingSecret -}}
  {{- .Values.config.existingSecret -}}
{{- else -}}
  {{- printf "%s-config" (include "adguard-home.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Conf PVC claim name */}}
{{- define "adguard-home.confClaimName" -}}
{{- if .Values.persistence.conf.existingClaim -}}
  {{- .Values.persistence.conf.existingClaim -}}
{{- else -}}
  {{- printf "%s-conf" (include "adguard-home.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Work PVC claim name */}}
{{- define "adguard-home.workClaimName" -}}
{{- if .Values.persistence.work.existingClaim -}}
  {{- .Values.persistence.work.existingClaim -}}
{{- else -}}
  {{- printf "%s-work" (include "adguard-home.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Backup secret name */}}
{{- define "adguard-home.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
  {{- .Values.backup.s3.existingSecret -}}
{{- else -}}
  {{- printf "%s-backup" (include "adguard-home.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Sync secret name */}}
{{- define "adguard-home.syncSecretName" -}}
{{- if .Values.sync.existingSecret -}}
  {{- .Values.sync.existingSecret -}}
{{- else -}}
  {{- printf "%s-sync" (include "adguard-home.fullname" .) -}}
{{- end -}}
{{- end -}}
