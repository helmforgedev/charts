{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "envoy-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "envoy-gateway.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "envoy-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "envoy-gateway.labels" -}}
helm.sh/chart: {{ include "envoy-gateway.chart" . }}
{{ include "envoy-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Namespace for chart-managed namespaced resources.
*/}}
{{- define "envoy-gateway.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "envoy-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "envoy-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Controller labels
*/}}
{{- define "envoy-gateway.controller.labels" -}}
{{ include "envoy-gateway.labels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Controller selector labels
*/}}
{{- define "envoy-gateway.controller.selectorLabels" -}}
{{ include "envoy-gateway.selectorLabels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "envoy-gateway.serviceAccountName" -}}
{{- if .Values.rateLimiting.enabled }}
{{- "envoy-gateway" }}
{{- else if .Values.serviceAccount.create }}
{{- default (include "envoy-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Controller Deployment name. Envoy Gateway's global rate-limit infrastructure
requires its owning controller Deployment to use the upstream canonical name.
*/}}
{{- define "envoy-gateway.controllerName" -}}
{{- if .Values.rateLimiting.enabled }}
{{- "envoy-gateway" }}
{{- else }}
{{- printf "%s-controller" (include "envoy-gateway.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - controller replica count
*/}}
{{- define "envoy-gateway.controller.replicaCount" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "dev" }}
{{- 1 }}
{{- else if eq $profile "production-ha" }}
{{- 2 }}
{{- else }}
{{- .Values.controller.replicaCount | default 1 }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - controller resources
*/}}
{{- define "envoy-gateway.controller.resources" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "dev" }}
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 500m
  memory: 512Mi
{{- else if eq $profile "production-ha" }}
requests:
  cpu: 1000m
  memory: 1Gi
limits:
  cpu: 2000m
  memory: 2Gi
{{- else }}
{{- toYaml .Values.controller.resources }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - proxy resources
*/}}
{{- define "envoy-gateway.proxy.resources" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "dev" }}
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 1000m
  memory: 1Gi
{{- else if eq $profile "production-ha" }}
requests:
  cpu: 1000m
  memory: 1Gi
limits:
  cpu: 4000m
  memory: 4Gi
{{- else }}
{{- toYaml .Values.proxy.resources }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - high availability enabled
*/}}
{{- define "envoy-gateway.ha.enabled" -}}
{{- $profile := .Values.profile | default "custom" }}
{{- if eq $profile "production-ha" }}
{{- true }}
{{- else }}
{{- .Values.highAvailability.enabled | default false }}
{{- end }}
{{- end }}

{{/*
Profile preset resolution - anti-affinity for controller
*/}}
{{- define "envoy-gateway.controller.affinity" -}}
{{- $haEnabled := include "envoy-gateway.ha.enabled" . | trim }}
{{- if eq $haEnabled "true" }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          {{- include "envoy-gateway.controller.selectorLabels" . | nindent 10 }}
      topologyKey: kubernetes.io/hostname
{{- else if .Values.controller.affinity }}
{{- toYaml .Values.controller.affinity }}
{{- end }}
{{- end }}

{{/*
Controller image
*/}}
{{- define "envoy-gateway.controller.image" -}}
{{- printf "%s:%s" .Values.controller.image.repository (.Values.controller.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Gateway API examples namespace
*/}}
{{- define "envoy-gateway.examples.namespace" -}}
{{- .Values.gatewayAPI.examples.namespace | default (include "envoy-gateway.namespace" .) }}
{{- end }}

{{/*
Gateway name - returns gateway.name or release name
*/}}
{{- define "envoy-gateway.gateway.name" -}}
{{- .Values.gateway.name | default .Release.Name }}
{{- end }}

{{/*
SecurityPolicy target name - returns targetName or gateway name
*/}}
{{- define "envoy-gateway.securityPolicy.targetName" -}}
{{- .Values.securityPolicy.targetName | default (include "envoy-gateway.gateway.name" .) }}
{{- end }}

{{/*
Rate limit Redis URL - returns subchart or external Redis URL.
Subchart (redis.enabled=true): redis service is named "<release>-redis-client" by the helmforge/redis chart.
External (rateLimiting.externalRedis.host set): use the provided host/port.
*/}}
{{- define "envoy-gateway.ratelimit.redisUrl" -}}
{{- if .Values.rateLimiting.externalRedis.host }}
{{- printf "%s:%d" .Values.rateLimiting.externalRedis.host (.Values.rateLimiting.externalRedis.port | int) }}
{{- else if .Values.redis.enabled }}
{{- printf "%s-redis-client.%s.svc.cluster.local:6379" .Release.Name .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Proxy pod spec fragment (nodeSelector, tolerations, affinity) for EnvoyProxy CRD
*/}}
{{- define "envoy-gateway.proxy.podSpec" -}}
{{- if .Values.proxy.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.proxy.nodeSelector | nindent 2 }}
{{- end }}
{{- if .Values.proxy.tolerations }}
tolerations:
  {{- toYaml .Values.proxy.tolerations | nindent 2 }}
{{- end }}
{{- $affinity := .Values.proxy.affinity }}
{{- if $affinity }}
affinity:
  {{- toYaml $affinity | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Central fail-fast validation entrypoint.
*/}}
{{- define "envoy-gateway.validate" -}}
{{- if and .Values.redis.enabled (ne .Values.redis.architecture "standalone") -}}
{{- fail "redis.architecture must be standalone when the bundled rate-limiting backend is enabled" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.rateLimiting.externalRedis.auth.secretName) -}}
{{- fail "externalSecrets.enabled requires rateLimiting.externalRedis.auth.secretName to be set to prevent credential drift between the chart-managed Secret and the ExternalSecret." -}}
{{- end -}}
{{- if and .Values.rateLimiting.enabled (not .Values.redis.enabled) (not .Values.rateLimiting.externalRedis.host) -}}
{{- fail "rateLimiting.enabled requires redis.enabled=true or rateLimiting.externalRedis.host to be set" -}}
{{- end -}}
{{- if and .Values.rateLimiting.enabled (not .Values.redis.enabled) .Values.rateLimiting.externalRedis.host .Values.rateLimiting.externalRedis.auth.enabled (not .Values.rateLimiting.externalRedis.auth.secretName) -}}
{{- fail "rateLimiting.externalRedis.auth.enabled requires rateLimiting.externalRedis.auth.secretName" -}}
{{- end -}}
{{- if and .Values.rateLimiting.enabled .Values.serviceAccount.create .Values.serviceAccount.name (ne .Values.serviceAccount.name "envoy-gateway") -}}
{{- fail "rateLimiting.enabled requires serviceAccount.name to be empty or envoy-gateway" -}}
{{- end -}}
{{- if and .Values.rateLimiting.enabled (not .Values.serviceAccount.create) (ne .Values.serviceAccount.name "envoy-gateway") -}}
{{- fail "rateLimiting.enabled with serviceAccount.create=false requires serviceAccount.name=envoy-gateway" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- $selectorLabels := include "envoy-gateway.controller.selectorLabels" . | fromYaml -}}
{{- range $key, $_ := $selectorLabels -}}
{{- if hasKey $podLabels $key -}}
{{- fail (printf "podLabels must not override selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- if not .Values.crds.enabled -}}
{{- $requiredGVKs := list
  "gateway.networking.k8s.io/v1/BackendTLSPolicy"
  "gateway.networking.k8s.io/v1/GatewayClass"
  "gateway.networking.k8s.io/v1/Gateway"
  "gateway.networking.k8s.io/v1/GRPCRoute"
  "gateway.networking.k8s.io/v1/HTTPRoute"
  "gateway.networking.k8s.io/v1/ListenerSet"
  "gateway.networking.k8s.io/v1/ReferenceGrant"
  "gateway.networking.k8s.io/v1/TCPRoute"
  "gateway.networking.k8s.io/v1/TLSRoute"
  "gateway.networking.k8s.io/v1/UDPRoute"
  "gateway.envoyproxy.io/v1alpha1/Backend"
  "gateway.envoyproxy.io/v1alpha1/BackendTrafficPolicy"
  "gateway.envoyproxy.io/v1alpha1/ClientTrafficPolicy"
  "gateway.envoyproxy.io/v1alpha1/EnvoyExtensionPolicy"
  "gateway.envoyproxy.io/v1alpha1/EnvoyPatchPolicy"
  "gateway.envoyproxy.io/v1alpha1/EnvoyProxy"
  "gateway.envoyproxy.io/v1alpha1/HTTPRouteFilter"
  "gateway.envoyproxy.io/v1alpha1/SecurityPolicy"
-}}
{{- $missingGVKs := list -}}
{{- range $gvk := $requiredGVKs -}}
{{- if not ($.Capabilities.APIVersions.Has $gvk) -}}
{{- $missingGVKs = append $missingGVKs $gvk -}}
{{- end -}}
{{- end -}}
{{- if $missingGVKs -}}
{{- fail (printf "crds.enabled=false requires the complete Envoy Gateway v1.9.0 / Gateway API v1.6.1 Experimental bundle; missing discoverable APIs: %s. Install envoy-gateway-crds first, wait for all CRDs to become Established, then retry without --disable-validation" (join ", " $missingGVKs)) -}}
{{- end -}}

{{- /* `lookup` is empty in client-only rendering. When connected to a cluster,
validate the exact bundle metadata in addition to discovery. */ -}}
{{- $incompatible := list -}}
{{- $gatewayCRDs := list
  "backendtlspolicies.gateway.networking.k8s.io"
  "gatewayclasses.gateway.networking.k8s.io"
  "gateways.gateway.networking.k8s.io"
  "grpcroutes.gateway.networking.k8s.io"
  "httproutes.gateway.networking.k8s.io"
  "listenersets.gateway.networking.k8s.io"
  "referencegrants.gateway.networking.k8s.io"
  "tcproutes.gateway.networking.k8s.io"
  "tlsroutes.gateway.networking.k8s.io"
  "udproutes.gateway.networking.k8s.io"
-}}
{{- range $name := $gatewayCRDs -}}
{{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" $name -}}
{{- if $crd -}}
{{- $version := dig "metadata" "annotations" "gateway.networking.k8s.io/bundle-version" "" $crd -}}
{{- $channel := dig "metadata" "annotations" "gateway.networking.k8s.io/channel" "" $crd -}}
{{- if or (ne $version "v1.6.1") (ne $channel "experimental") -}}
{{- $incompatible = append $incompatible (printf "%s (bundle-version=%q, channel=%q)" $name $version $channel) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $envoyCRDs := list
  "backends.gateway.envoyproxy.io"
  "backendtrafficpolicies.gateway.envoyproxy.io"
  "clienttrafficpolicies.gateway.envoyproxy.io"
  "envoyextensionpolicies.gateway.envoyproxy.io"
  "envoypatchpolicies.gateway.envoyproxy.io"
  "envoyproxies.gateway.envoyproxy.io"
  "httproutefilters.gateway.envoyproxy.io"
  "securitypolicies.gateway.envoyproxy.io"
-}}
{{- range $name := $envoyCRDs -}}
{{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" $name -}}
{{- if $crd -}}
{{- $version := dig "metadata" "annotations" "helmforge.dev/bundle-version" "" $crd -}}
{{- if ne $version "v1.9.0" -}}
{{- $incompatible = append $incompatible (printf "%s (helmforge.dev/bundle-version=%q)" $name $version) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $incompatible -}}
{{- fail (printf "crds.enabled=false found an incompatible external CRD bundle: %s. Apply the matching envoy-gateway-crds bundle server-side before upgrading the controller" (join ", " $incompatible)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
