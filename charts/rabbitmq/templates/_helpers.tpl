{{- define "rabbitmq.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "rabbitmq.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "rabbitmq.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "rabbitmq.labels" -}}
helm.sh/chart: {{ include "rabbitmq.chart" . }}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "rabbitmq.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "rabbitmq.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "rabbitmq.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "rabbitmq.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.headlessServiceName" -}}
{{- printf "%s-headless" (include "rabbitmq.fullname" .) -}}
{{- end -}}

{{- define "rabbitmq.configurationName" -}}
{{- printf "%s-config" (include "rabbitmq.fullname" .) -}}
{{- end -}}

{{- define "rabbitmq.tlsSecretName" -}}
{{- .Values.tls.existingSecret -}}
{{- end -}}

{{- define "rabbitmq.replicaCount" -}}
{{- if eq .Values.architecture "cluster" -}}
{{- .Values.cluster.replicaCount | int -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

{{- define "rabbitmq.password" -}}
{{- $secretName := include "rabbitmq.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else if .Values.auth.password -}}
{{- .Values.auth.password -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $existing -}}
{{- index $existing.data "rabbitmq-password" | b64dec -}}
{{- else -}}
{{- randAlphaNum 24 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.erlangCookie" -}}
{{- $secretName := include "rabbitmq.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else if .Values.auth.erlangCookie -}}
{{- .Values.auth.erlangCookie -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $existing -}}
{{- index $existing.data "rabbitmq-erlang-cookie" | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.plugins" -}}
{{- $plugins := list -}}
{{- if .Values.management.enabled -}}
{{- $plugins = append $plugins "rabbitmq_management" -}}
{{- end -}}
{{- if .Values.metrics.enabled -}}
{{- $plugins = append $plugins "rabbitmq_prometheus" -}}
{{- end -}}
{{- if eq .Values.architecture "cluster" -}}
{{- $plugins = append $plugins "rabbitmq_peer_discovery_k8s" -}}
{{- end -}}
{{- range .Values.plugins.extra }}
{{- if not (has . $plugins) -}}
{{- $plugins = append $plugins . -}}
{{- end -}}
{{- end -}}
[{{ join "," $plugins }}].
{{- end -}}

{{- define "rabbitmq.nodenameSuffix" -}}
{{- printf ".%s.%s.svc.%s" (include "rabbitmq.headlessServiceName" .) .Release.Namespace .Values.clusterDomain -}}
{{- end -}}

{{- define "rabbitmq.ingressPortName" -}}
{{- if and .Values.tls.enabled .Values.management.ingress.useTlsPort -}}
management-tls
{{- else -}}
management
{{- end -}}
{{- end -}}
