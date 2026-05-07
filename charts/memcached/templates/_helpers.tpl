{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "memcached.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "memcached.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 52 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 52 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "memcached.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "memcached.suffixedName" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMaxLength := int (sub 63 (add 1 (len $suffix))) -}}
{{- printf "%s-%s" ($base | trunc $baseMaxLength | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "memcached.selectorLabels" -}}
app.kubernetes.io/name: {{ include "memcached.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "memcached.labels" -}}
helm.sh/chart: {{ include "memcached.chart" . }}
{{ include "memcached.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "memcached.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "memcached.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "memcached.headlessServiceName" -}}
{{- include "memcached.suffixedName" (dict "base" (include "memcached.fullname" .) "suffix" "headless") -}}
{{- end -}}

{{- define "memcached.metricsServiceName" -}}
{{- include "memcached.suffixedName" (dict "base" (include "memcached.fullname" .) "suffix" "metrics") -}}
{{- end -}}

{{- define "memcached.testPodName" -}}
{{- include "memcached.suffixedName" (dict "base" (include "memcached.fullname" .) "suffix" "test-connection") -}}
{{- end -}}

{{- define "memcached.authSecretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- include "memcached.suffixedName" (dict "base" (include "memcached.fullname" .) "suffix" "auth") -}}
{{- end -}}
{{- end -}}

{{- define "memcached.tlsSecretName" -}}
{{- required "tls.existingSecret is required when tls.enabled=true" .Values.tls.existingSecret -}}
{{- end -}}

{{- define "memcached.authFile" -}}
{{- printf "%s:%s\n" .Values.auth.username .Values.auth.password -}}
{{- end -}}

{{- define "memcached.listenAddress" -}}
{{- if and (has "IPv6" .Values.service.ipFamilies) (eq .Values.memcached.listenAddress "0.0.0.0") -}}
{{- "0.0.0.0,::" -}}
{{- else -}}
{{- .Values.memcached.listenAddress -}}
{{- end -}}
{{- end -}}

{{- define "memcached.validate" -}}
{{- $resourceRequests := default dict .Values.resources.requests -}}
{{- if not (has .Values.architecture (list "standalone" "distributed")) -}}
{{- fail "architecture must be one of: standalone, distributed" -}}
{{- end -}}
{{- if and (eq .Values.architecture "standalone") (gt (int .Values.replicaCount) 1) -}}
{{- fail "architecture=standalone requires replicaCount=1; use architecture=distributed for multiple independent cache nodes" -}}
{{- end -}}
{{- if and (eq .Values.architecture "standalone") .Values.autoscaling.enabled -}}
{{- fail "autoscaling.enabled requires architecture=distributed because standalone mode must remain a single cache pod" -}}
{{- end -}}
{{- if and .Values.autoscaling.enabled .Values.autoscaling.targetCPUUtilizationPercentage (not $resourceRequests.cpu) -}}
{{- fail "autoscaling.targetCPUUtilizationPercentage requires resources.requests.cpu" -}}
{{- end -}}
{{- if and .Values.autoscaling.enabled .Values.autoscaling.targetMemoryUtilizationPercentage (not $resourceRequests.memory) -}}
{{- fail "autoscaling.targetMemoryUtilizationPercentage requires resources.requests.memory" -}}
{{- end -}}
{{- if not (has .Values.auth.mode (list "ascii" "sasl")) -}}
{{- fail "auth.mode must be one of: ascii, sasl" -}}
{{- end -}}
{{- if and .Values.auth.enabled (eq .Values.auth.mode "sasl") (ne .Values.memcached.protocol "binary") -}}
{{- fail "auth.mode=sasl requires memcached.protocol=binary" -}}
{{- end -}}
{{- if and .Values.auth.enabled (eq .Values.auth.mode "sasl") (not .Values.auth.existingSecret) -}}
{{- fail "auth.mode=sasl requires auth.existingSecret containing SASL configuration and database files" -}}
{{- end -}}
{{- if and .Values.auth.enabled (eq .Values.auth.mode "sasl") (not .Values.auth.sasl.configKey) -}}
{{- fail "auth.sasl.configKey is required when auth.mode=sasl" -}}
{{- end -}}
{{- if and .Values.auth.enabled (eq .Values.auth.mode "sasl") (not .Values.auth.sasl.databaseKey) -}}
{{- fail "auth.sasl.databaseKey is required when auth.mode=sasl" -}}
{{- end -}}
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) (not .Values.auth.password) -}}
{{- fail "auth.password or auth.existingSecret is required when auth.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.auth.existingSecret) -}}
{{- fail "auth.existingSecret is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.data) -}}
{{- fail "externalSecrets.data is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.tls.enabled (not .Values.tls.existingSecret) -}}
{{- fail "tls.existingSecret is required when tls.enabled=true" -}}
{{- end -}}
{{- if and .Values.metrics.enabled .Values.auth.enabled -}}
{{- fail "metrics.enabled cannot be combined with auth.enabled because the upstream memcached exporter does not support Memcached authentication" -}}
{{- end -}}
{{- if and .Values.metrics.memcachedTLS.enabled (not .Values.tls.enabled) -}}
{{- fail "metrics.memcachedTLS.enabled requires tls.enabled=true" -}}
{{- end -}}
{{- if and .Values.extstore.enabled .Values.autoscaling.enabled .Values.extstore.persistence.enabled -}}
{{- fail "extstore.persistence.enabled cannot be combined with autoscaling.enabled because PVC-backed cache files are pod-local" -}}
{{- end -}}
{{- end -}}

{{- define "memcached.extendedOptions" -}}
{{- $options := list -}}
{{- range .Values.memcached.extendedOptions }}
{{- $options = append $options . -}}
{{- end }}
{{- if .Values.extstore.enabled }}
{{- $options = append $options (printf "ext_path=%s:%s" .Values.extstore.path .Values.extstore.size) -}}
{{- $options = append $options (printf "ext_page_size=%v" .Values.extstore.pageSizeMB) -}}
{{- $options = append $options (printf "ext_wbuf_size=%v" .Values.extstore.wbufSizeMB) -}}
{{- $options = append $options (printf "ext_threads=%v" .Values.extstore.threads) -}}
{{- $options = append $options (printf "ext_item_size=%v" .Values.extstore.itemSizeBytes) -}}
{{- end }}
{{- if .Values.tls.enabled }}
{{- $options = append $options (printf "ssl_chain_cert=/tls/%s" .Values.tls.certKey) -}}
{{- $options = append $options (printf "ssl_key=/tls/%s" .Values.tls.keyKey) -}}
{{- $options = append $options (printf "ssl_verify_mode=%s" .Values.tls.verifyMode) -}}
{{- $options = append $options (printf "ssl_min_version=%s" .Values.tls.minVersion) -}}
{{- if .Values.tls.caKey }}
{{- $options = append $options (printf "ssl_ca_cert=/tls/%s" .Values.tls.caKey) -}}
{{- end }}
{{- end }}
{{- join "," $options -}}
{{- end -}}

{{- define "memcached.args" -}}
- -m
- {{ .Values.memcached.memoryLimitMB | quote }}
- -p
- {{ .Values.service.port | quote }}
- -U
- {{ .Values.memcached.udpPort | quote }}
- -l
- {{ include "memcached.listenAddress" . | quote }}
- -c
- {{ .Values.memcached.maxConnections | quote }}
- -t
- {{ .Values.memcached.threads | quote }}
- -I
- {{ .Values.memcached.maxItemSize | quote }}
- -B
{{- if and .Values.auth.enabled (eq .Values.auth.mode "ascii") }}
- "ascii"
{{- else }}
- {{ .Values.memcached.protocol | quote }}
{{- end }}
{{- if .Values.memcached.disableFlushAll }}
- -F
{{- end }}
{{- if .Values.memcached.disableEvictions }}
- -M
{{- end }}
{{- if .Values.memcached.disableCas }}
- -C
{{- end }}
{{- if .Values.memcached.disableWatch }}
- -W
{{- end }}
{{- if .Values.memcached.disableDumping }}
- -X
{{- end }}
{{- with .Values.memcached.verbosity }}
- {{ . | quote }}
{{- end }}
{{- if .Values.auth.enabled }}
{{- if eq .Values.auth.mode "sasl" }}
- -S
{{- else }}
- -Y
- /auth/{{ .Values.auth.authFileKey }}
{{- end }}
{{- end }}
{{- if .Values.tls.enabled }}
- -Z
{{- end }}
{{- $extended := include "memcached.extendedOptions" . }}
{{- if $extended }}
- -o
- {{ $extended | quote }}
{{- end }}
{{- range .Values.memcached.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}
