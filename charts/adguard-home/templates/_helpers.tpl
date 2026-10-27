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

{{/* Selector labels for the AdGuard Home server pod/services. Adds the
     component discriminator so Services do not also match the sync pod
     (which carries app.kubernetes.io/component: sync). */}}
{{- define "adguard-home.serverSelectorLabels" -}}
{{ include "adguard-home.selectorLabels" . }}
app.kubernetes.io/component: server
{{- end -}}

{{/* Full metadata labels for server-owned objects, mirroring the sync and
     backup components which carry their own app.kubernetes.io/component. */}}
{{- define "adguard-home.serverLabels" -}}
{{ include "adguard-home.labels" . }}
app.kubernetes.io/component: server
{{- end -}}

{{/* Image helper - tag prefixed with "v" */}}
{{- define "adguard-home.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/* Returns true when a pre-seed config is provided */}}
{{- define "adguard-home.hasConfig" -}}
{{- if or (not (empty .Values.config.adGuardHome)) .Values.config.existingSecret -}}true{{- end -}}
{{- end -}}

{{/* Active web listener: setup wizard or configured admin UI. */}}
{{- define "adguard-home.webPort" -}}
{{- if (include "adguard-home.hasConfig" .) -}}
{{- .Values.containerPorts.http -}}
{{- else -}}
{{- .Values.containerPorts.setup -}}
{{- end -}}
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

{{- define "adguard-home.validate" -}}
{{- $dnsPortNames := dict "dns-tcp" true "dns-udp" true -}}
{{- range .Values.service.dns.extraPorts -}}
  {{- if hasKey $dnsPortNames .name -}}
    {{- fail "service.dns.extraPorts names must be unique and cannot use the reserved names dns-tcp or dns-udp." -}}
  {{- end -}}
  {{- $_ := set $dnsPortNames .name true -}}
{{- end -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.config.existingSecret -}}
    {{- fail "externalSecrets.enabled requires config.existingSecret to be set to prevent credential drift between the chart-managed Secret and the ExternalSecret." -}}
  {{- end -}}
  {{- $hasConfigKey := false -}}
  {{- range .Values.externalSecrets.data -}}
    {{- if eq .secretKey "AdGuardHome.yaml" -}}
      {{- $hasConfigKey = true -}}
    {{- end -}}
  {{- end -}}
  {{- if not $hasConfigKey -}}
    {{- fail "externalSecrets.data must contain an entry with secretKey 'AdGuardHome.yaml' when externalSecrets.enabled=true to populate the initial configuration." -}}
  {{- end -}}
{{- end -}}
{{- end -}}
