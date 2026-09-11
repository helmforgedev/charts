{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "text-embeddings-inference.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "text-embeddings-inference.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "text-embeddings-inference.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "text-embeddings-inference.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "text-embeddings-inference.selectorLabels" -}}
app.kubernetes.io/name: {{ include "text-embeddings-inference.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "text-embeddings-inference.labels" -}}
helm.sh/chart: {{ include "text-embeddings-inference.chart" . }}
{{ include "text-embeddings-inference.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "text-embeddings-inference.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "text-embeddings-inference.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "text-embeddings-inference.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}

{{- define "text-embeddings-inference.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "text-embeddings-inference.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "text-embeddings-inference.fullname" .root }}{{- end -}}
{{- end -}}

{{- define "text-embeddings-inference.suffix" -}}{{ printf "%s-%s" (include "text-embeddings-inference.fullname" .root | trunc (int (sub 62 (len .suffix))) | trimSuffix "-") .suffix }}{{- end -}}
{{- define "text-embeddings-inference.authSecret" -}}{{ default (include "text-embeddings-inference.suffix" (dict "root" . "suffix" "auth")) .Values.auth.existingSecret }}{{- end -}}
{{- define "text-embeddings-inference.cacheClaim" -}}{{ default (include "text-embeddings-inference.suffix" (dict "root" . "suffix" "cache")) .Values.cache.persistence.existingClaim }}{{- end -}}
{{- define "text-embeddings-inference.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ include "text-embeddings-inference.suffix" (dict "root" .root "suffix" (default "auth" .item.name)) }}{{- end -}}{{- end -}}
{{- define "text-embeddings-inference.validate" -}}
{{- if and (not .Values.proxy.ipv6) (or (has "IPv6" .Values.service.ipFamilies) (has .Values.service.ipFamilyPolicy (list "PreferDualStack" "RequireDualStack"))) -}}{{ fail "proxy.ipv6 must be enabled when requesting IPv6 or dual-stack Services" }}{{- end -}}
{{- if and (eq .Values.model.source "hub") (or (not .Values.model.id) (not (regexMatch "^[a-f0-9]{40}$" .Values.model.revision))) -}}{{ fail "hub models require model.id and an immutable 40-character model.revision" }}{{- end -}}
{{- if and (eq .Values.model.source "local") (not .Values.model.local.existingClaim) -}}{{ fail "local models require model.local.existingClaim containing complete model artifacts" }}{{- end -}}
{{- if and .Values.model.defaultPrompt .Values.model.defaultPromptName -}}{{ fail "model.defaultPrompt and model.defaultPromptName are mutually exclusive" }}{{- end -}}
{{- if or (eq (int .Values.proxy.port) 8081) (eq (int .Values.metrics.port) 8081) (eq (int .Values.proxy.port) (int .Values.metrics.port)) -}}{{ fail "public, private metrics and reserved loopback 8081 ports must differ" }}{{- end -}}
{{- if and .Values.cache.persistence.enabled (or .Values.autoscaling.enabled (gt (int .Values.replicaCount) 1) (ne .Values.rollout.strategy "Recreate")) -}}{{ fail "persistent cache requires one replica, Recreate strategy and autoscaling disabled" }}{{- end -}}
{{- if and .Values.autoscaling.enabled (or .Values.gpu.enabled (not (dig "requests" "cpu" "" .Values.resources))) -}}{{ fail "CPU autoscaling requires CPU requests and gpu.enabled=false" }}{{- end -}}
{{- if gt (int .Values.autoscaling.minReplicas) (int .Values.autoscaling.maxReplicas) -}}{{ fail "autoscaling.minReplicas cannot exceed maxReplicas" }}{{- end -}}
{{- $minimum := int .Values.replicaCount -}}{{- if .Values.autoscaling.enabled -}}{{- $minimum = int .Values.autoscaling.minReplicas -}}{{- end -}}
{{- if and .Values.podDisruptionBudget.enabled (or (lt $minimum 2) (ge (int .Values.podDisruptionBudget.maxUnavailable) $minimum)) -}}{{ fail "podDisruptionBudget requires at least two minimum replicas and a smaller maxUnavailable" }}{{- end -}}
{{- if and .Values.metrics.enabled (not .Values.metrics.ingressFrom) -}}{{ fail "metrics.ingressFrom must explicitly authorize monitoring peers" }}{{- end -}}
{{- if and (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) (not .Values.metrics.enabled) -}}{{ fail "monitoring resources require metrics.enabled" }}{{- end -}}
{{- if and .Values.metrics.prometheusRule.enabled (not .Values.metrics.serviceMonitor.enabled) -}}{{ fail "the built-in metrics target alert requires metrics.serviceMonitor.enabled" }}{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}{{ fail "ingress.hosts is required when ingress is enabled" }}{{- end -}}
{{- if and .Values.gpu.enabled (contains "cpu-" .Values.image.tag) -}}{{ fail "gpu.enabled requires a compatible pinned CUDA image tag" }}{{- end -}}
{{- if and (not .Values.gpu.enabled) (not (hasPrefix "cpu-" .Values.image.tag)) -}}{{ fail "CPU deployment requires the official cpu image variant" }}{{- end -}}
{{- if and (not .Values.gpu.enabled) (ne (int .Values.inference.maxBatchRequests) 8) -}}{{ fail "the pinned CPU backend forces exactly eight batch requests; inference.maxBatchRequests must be 8" }}{{- end -}}
{{- if ne (get .Values.nodeSelector "kubernetes.io/arch" | default "amd64") "amd64" -}}{{ fail "the pinned TEI 1.9.3 images support linux/amd64 only" }}{{- end -}}
{{- if le (int .Values.terminationGracePeriodSeconds) (int .Values.proxy.readTimeoutSeconds) -}}{{ fail "terminationGracePeriodSeconds must exceed proxy.readTimeoutSeconds" }}{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- $reserved := list "API_KEY" "HF_TOKEN" "LOG_LEVEL" "HOSTNAME" "PORT" "MODEL_ID" "REVISION" "SERVED_MODEL_NAME" "POOLING" "DTYPE" "DEFAULT_PROMPT" "DEFAULT_PROMPT_NAME" "HUGGINGFACE_HUB_CACHE" "HF_HOME" "MAX_CONCURRENT_REQUESTS" "MAX_BATCH_TOKENS" "MAX_BATCH_REQUESTS" "MAX_CLIENT_BATCH_SIZE" "PAYLOAD_LIMIT" "AUTO_TRUNCATE" "TOKENIZATION_WORKERS" "RAYON_NUM_THREADS" "OMP_NUM_THREADS" "MKL_NUM_THREADS" -}}
{{- range .Values.extraEnv -}}{{- if has .name $reserved -}}{{ fail (printf "extraEnv cannot override chart-owned %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "text-embeddings-inference.validateExternalSecrets" -}}
{{- $names := dict -}}
{{- range .Values.externalSecrets.items -}}
{{- $name := include "text-embeddings-inference.externalSecretName" (dict "root" $ "item" .) -}}
{{- if hasKey $names $name -}}{{ fail "ExternalSecret names must be unique after rendering and truncation" }}{{- end -}}
{{- $_ := set $names $name true -}}
{{- end -}}
{{- end -}}
