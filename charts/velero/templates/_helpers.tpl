{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "velero.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "velero.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "velero.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "velero.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "velero.labels" -}}
helm.sh/chart: {{ include "velero.chart" . }}
app.kubernetes.io/name: {{ include "velero.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "velero.selectorLabels" -}}
app.kubernetes.io/name: {{ include "velero.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "velero.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "velero.serviceAccountName" -}}
{{- if .Values.serviceAccount.server.create -}}
{{- default (include "velero.fullname" .) .Values.serviceAccount.server.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.server.name -}}
{{- end -}}
{{- end -}}

{{- define "velero.secretName" -}}
{{- if .Values.credentials.existingSecret -}}
{{- .Values.credentials.existingSecret -}}
{{- else -}}
{{- default (printf "%s-credentials" (include "velero.fullname" .)) .Values.credentials.name -}}
{{- end -}}
{{- end -}}

{{- define "velero.credentialsSecretEnabled" -}}
{{- if and .Values.credentials.useSecret (or .Values.credentials.existingSecret .Values.credentials.name .Values.credentials.secretContents) -}}true{{- end -}}
{{- end -}}

{{/* Resolve the metrics listener, preserving the pre-1.6 metricsAddress value. */}}
{{- define "velero.metricsContainerPort" -}}
{{- if .Values.configuration.metricsAddress -}}
{{- trimPrefix ":" .Values.configuration.metricsAddress -}}
{{- else -}}
{{- .Values.metrics.containerPort -}}
{{- end -}}
{{- end -}}

{{/*
Compile all validation warnings and fail if any violation is found
*/}}
{{- define "velero.validate" -}}
{{- $messages := list -}}
{{- if not .Values.configuration.backupStorageLocations -}}
  {{- $messages = append $messages "Velero requires at least one backup storage location configured in configuration.backupStorageLocations." -}}
{{- else -}}
  {{- range $index, $bsl := .Values.configuration.backupStorageLocations -}}
    {{- if not $bsl.name -}}
      {{- $messages = append $messages (printf "configuration.backupStorageLocations[%d].name must be specified." $index) -}}
    {{- end -}}
    {{- if not $bsl.provider -}}
      {{- $messages = append $messages (printf "configuration.backupStorageLocations[%d].provider must be specified." $index) -}}
    {{- end -}}
    {{- if and $bsl.config $bsl.config.s3Url -}}
      {{- if not (regexMatch "^https?://[^/]+.*$" $bsl.config.s3Url) -}}
        {{- $messages = append $messages (printf "configuration.backupStorageLocations[%d].config.s3Url must be a valid URL starting with http:// or https:// with a valid host." $index) -}}
      {{- end -}}
      {{- if not $bsl.bucket -}}
        {{- $messages = append $messages (printf "configuration.backupStorageLocations[%d].bucket must be specified when s3Url is configured." $index) -}}
      {{- end -}}
    {{- end -}}
    {{- if and (gt (len $.Values.schedules) 0) (not $bsl.bucket) -}}
      {{- $messages = append $messages (printf "configuration.backupStorageLocations[%d].bucket must be specified when schedules are defined." $index) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.credentials.useSecret .Values.credentials.existingSecret -}}
  {{- if or .Values.credentials.secretContents .Values.credentials.name -}}
    {{- $messages = append $messages "When credentials.useSecret is true and credentials.existingSecret is provided, neither credentials.secretContents nor credentials.name should be set." -}}
  {{- end -}}
{{- end -}}
{{- if .Values.schedules -}}
  {{- range $index, $sched := .Values.schedules -}}
    {{- if not $sched.name -}}
      {{- $messages = append $messages (printf "schedules[%d].name must be specified." $index) -}}
    {{- end -}}
    {{- if not $sched.schedule -}}
      {{- $messages = append $messages (printf "schedules[%d].schedule (cron expression) must be specified." $index) -}}
    {{- end -}}
    {{- if not $sched.template -}}
      {{- $messages = append $messages (printf "schedules[%d].template must be specified." $index) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}
  {{- $messages = append $messages "When metrics.serviceMonitor.enabled is true, metrics.enabled must also be true." -}}
{{- end -}}
{{- if $messages -}}
  {{- fail (printf "validation failed:\n%s" (join "\n" $messages)) -}}
{{- end -}}
{{- end -}}
