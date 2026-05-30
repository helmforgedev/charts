{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "jupyterhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "jupyterhub.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}
{{- end -}}
{{- define "jupyterhub.chart" -}}{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "jupyterhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jupyterhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "jupyterhub.labels" -}}
helm.sh/chart: {{ include "jupyterhub.chart" . }}
{{ include "jupyterhub.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "jupyterhub.renderAnnotations" -}}
{{- $common := .common | default dict -}}
{{- $specific := .specific | default dict -}}
{{- $annotations := mergeOverwrite (deepCopy $common) $specific -}}
{{- with $annotations }}
annotations:
{{ toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
{{- define "jupyterhub.podLabels" -}}
{{- $labels := omit .Values.podLabels "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" -}}
{{- with $labels -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}
{{- define "jupyterhub.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ default (include "jupyterhub.fullname" .) .Values.serviceAccount.name }}{{- else }}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}
{{- define "jupyterhub.hubName" -}}{{ include "jupyterhub.fullname" . }}-hub{{- end -}}
{{- define "jupyterhub.proxyName" -}}{{ include "jupyterhub.fullname" . }}{{- end -}}
{{- define "jupyterhub.proxyApiName" -}}{{ include "jupyterhub.fullname" . }}-proxy-api{{- end -}}
{{- define "jupyterhub.hubDataClaimName" -}}
{{- if .Values.hub.persistence.existingClaim }}{{ .Values.hub.persistence.existingClaim }}{{- else }}{{ include "jupyterhub.hubName" . }}-data{{- end -}}
{{- end -}}
{{- define "jupyterhub.hubHealthPath" -}}
{{- $base := trimSuffix "/" .Values.hub.baseUrl -}}
{{- if eq $base "" -}}/hub/health{{- else -}}{{ printf "%s/hub/health" $base }}{{- end -}}
{{- end -}}
{{- define "jupyterhub.hubMetricsPath" -}}
{{- $base := trimSuffix "/" .Values.hub.baseUrl -}}
{{- if eq $base "" -}}/hub/metrics{{- else -}}{{ printf "%s/hub/metrics" $base }}{{- end -}}
{{- end -}}
{{- define "jupyterhub.hubErrorPath" -}}
{{- $base := trimSuffix "/" .Values.hub.baseUrl -}}
{{- if eq $base "" -}}/hub/error{{- else -}}{{ printf "%s/hub/error" $base }}{{- end -}}
{{- end -}}
{{- define "jupyterhub.secretName" -}}
{{- if .Values.proxy.existingSecret }}{{ .Values.proxy.existingSecret }}{{- else }}{{ include "jupyterhub.fullname" . }}-proxy{{- end -}}
{{- end -}}
{{- define "jupyterhub.proxyToken" -}}
{{- if .Values.proxy.secretToken }}{{ .Values.proxy.secretToken }}{{- else if .Values.proxy.existingSecret }}{{ "" }}{{- else }}{{ randAlphaNum 64 }}{{- end -}}
{{- end -}}
{{- define "jupyterhub.proxyDefaultBindIp" -}}
{{- if or (has "IPv6" .Values.service.ipFamilies) (eq .Values.service.ipFamilyPolicy "PreferDualStack") (eq .Values.service.ipFamilyPolicy "RequireDualStack") -}}
::
{{- else -}}
0.0.0.0
{{- end -}}
{{- end -}}
{{- define "jupyterhub.proxyBindIp" -}}
{{- default (include "jupyterhub.proxyDefaultBindIp" .) .Values.proxy.bind.ip -}}
{{- end -}}
{{- define "jupyterhub.proxyApiBindIp" -}}
{{- default (include "jupyterhub.proxyDefaultBindIp" .) .Values.proxy.bind.apiIp -}}
{{- end -}}
{{- define "jupyterhub.validateValues" -}}
{{- $publicExposure := or .Values.ingress.enabled .Values.gateway.enabled (eq .Values.service.type "LoadBalancer") (eq .Values.service.type "NodePort") -}}
{{- if and $publicExposure (eq .Values.auth.type "dummy") (not .Values.auth.dummyPassword) (not .Values.auth.allowInsecureDummy) -}}
{{- fail "public exposure with the default dummy authenticator requires auth.dummyPassword or auth.allowInsecureDummy=true" -}}
{{- end -}}
{{- if and $publicExposure (ne .Values.auth.type "dummy") (not (regexMatch "(?m)^\\s*c\\.JupyterHub\\.authenticator_class\\s*=" .Values.hub.extraConfig)) -}}
{{- fail "public exposure with a custom authenticator requires hub.extraConfig to set authenticator_class" -}}
{{- end -}}
{{- $hasExternalHubDb := regexMatch "(?m)^\\s*c\\.JupyterHub\\.db_url\\s*=" .Values.hub.extraConfig -}}
{{- if and (gt (int .Values.hub.replicaCount) 1) (not $hasExternalHubDb) -}}
{{- fail "hub.replicaCount > 1 requires hub.extraConfig to configure an external c.JupyterHub.db_url; the default SQLite database is single-writer and must run with one Hub replica" -}}
{{- end -}}
{{- $singleWriterHubPVC := or (has "ReadWriteOnce" .Values.hub.persistence.accessModes) (has "ReadWriteOncePod" .Values.hub.persistence.accessModes) -}}
{{- if and (gt (int .Values.hub.replicaCount) 1) .Values.hub.persistence.enabled (not .Values.hub.persistence.existingClaim) $singleWriterHubPVC -}}
{{- fail "hub.replicaCount > 1 with hub.persistence.enabled=true requires hub.persistence.accessModes without ReadWriteOnce or ReadWriteOncePod, or hub.persistence.enabled=false, to avoid multiple Hub replicas sharing a single-writer PVC" -}}
{{- end -}}
{{- if and (gt (int .Values.hub.replicaCount) 1) $hasExternalHubDb (not .Values.hub.persistence.enabled) (not .Values.hub.cookieSecret.existingSecret) -}}
{{- fail "hub.replicaCount > 1 with hub.persistence.enabled=false requires hub.cookieSecret.existingSecret so every Hub replica uses the same JupyterHub cookie secret" -}}
{{- end -}}
{{- if and .Values.hub.cookieSecret.fileName (contains "/" .Values.hub.cookieSecret.fileName) -}}
{{- fail "hub.cookieSecret.fileName must be a file name, not a path" -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled .Values.metrics.authenticatePrometheus -}}
{{- fail "metrics.serviceMonitor.enabled=true requires metrics.authenticatePrometheus=false until ServiceMonitor scrape credentials are configured" -}}
{{- end -}}
{{- if and $publicExposure (not .Values.metrics.authenticatePrometheus) (not .Values.metrics.allowPublicUnauthenticatedPrometheus) -}}
{{- fail "public exposure with unauthenticated Prometheus metrics requires metrics.allowPublicUnauthenticatedPrometheus=true" -}}
{{- end -}}
{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" -}}
{{- if hasKey $.Values.commonLabels $key -}}
{{- fail (printf "commonLabels cannot override reserved selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" -}}
{{- if hasKey $.Values.podLabels $key -}}
{{- fail (printf "podLabels cannot override reserved selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
