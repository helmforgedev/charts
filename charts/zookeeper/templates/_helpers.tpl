{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "zookeeper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zookeeper.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "zookeeper.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{- define "zookeeper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zookeeper.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zookeeper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "zookeeper.labels" -}}
helm.sh/chart: {{ include "zookeeper.chart" . }}
{{ include "zookeeper.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "zookeeper.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "zookeeper.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "zookeeper.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "zookeeper.publishNotReadyAddresses" -}}
{{- if or (gt (.Values.replicaCount | int) 1) (not .Values.zookeeper.standaloneEnabled) -}}true{{- else -}}{{ .Values.service.headless.publishNotReadyAddresses }}{{- end -}}
{{- end -}}

{{- define "zookeeper.suffixedName" -}}
{{- $prefix := .name -}}
{{- $suffix := .suffix -}}
{{- $maxPrefix := int (sub 63 (len $suffix)) -}}
{{- printf "%s%s" ($prefix | trunc $maxPrefix | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zookeeper.headlessServiceName" -}}
{{- include "zookeeper.suffixedName" (dict "name" (include "zookeeper.fullname" .) "suffix" "-headless") -}}
{{- end -}}

{{- define "zookeeper.clientServiceName" -}}
{{- include "zookeeper.fullname" . -}}
{{- end -}}

{{- define "zookeeper.metricsServiceName" -}}
{{- include "zookeeper.suffixedName" (dict "name" (include "zookeeper.fullname" .) "suffix" "-metrics") -}}
{{- end -}}

{{- define "zookeeper.configMapName" -}}
{{- include "zookeeper.suffixedName" (dict "name" (include "zookeeper.fullname" .) "suffix" "-config") -}}
{{- end -}}

{{- define "zookeeper.authSecretName" -}}
{{- if .Values.auth.client.existingSecret -}}
{{- .Values.auth.client.existingSecret -}}
{{- else if and .Values.externalSecrets.enabled .Values.auth.client.enabled .Values.externalSecrets.target.name -}}
{{- .Values.externalSecrets.target.name -}}
{{- else -}}
{{- include "zookeeper.suffixedName" (dict "name" (include "zookeeper.fullname" .) "suffix" "-auth") -}}
{{- end -}}
{{- end -}}

{{- define "zookeeper.tlsPasswordsSecretName" -}}
{{- if .Values.tls.client.existingPasswordsSecret -}}
{{- .Values.tls.client.existingPasswordsSecret -}}
{{- else if and .Values.externalSecrets.enabled .Values.tls.client.enabled .Values.externalSecrets.target.name -}}
{{- .Values.externalSecrets.target.name -}}
{{- else -}}
{{- include "zookeeper.suffixedName" (dict "name" (include "zookeeper.fullname" .) "suffix" "-tls-passwords") -}}
{{- end -}}
{{- end -}}

{{- define "zookeeper.tlsSecretName" -}}
{{- .Values.tls.client.existingSecret -}}
{{- end -}}

{{- define "zookeeper.clusterDomain" -}}
{{- default "cluster.local" .Values.clusterDomain -}}
{{- end -}}

{{- define "zookeeper.headlessFqdn" -}}
{{- printf "%s.%s.svc.%s" (include "zookeeper.headlessServiceName" .) (include "zookeeper.namespace" .) (include "zookeeper.clusterDomain" .) -}}
{{- end -}}

{{- define "zookeeper.servers" -}}
{{- $root := . -}}
{{- $servers := list -}}
{{- range $i := until (.Values.replicaCount | int) -}}
{{- $id := add1 $i -}}
{{- $host := printf "%s-%d.%s" (include "zookeeper.fullname" $root) $i (include "zookeeper.headlessFqdn" $root) -}}
{{- $servers = append $servers (printf "server.%d=%s:%d:%d;%d" $id $host ($root.Values.zookeeper.followerPort | int) ($root.Values.zookeeper.electionPort | int) ($root.Values.zookeeper.clientPort | int)) -}}
{{- end -}}
{{- join " " $servers -}}
{{- end -}}

{{- define "zookeeper.peerHosts" -}}
{{- $root := . -}}
{{- $hosts := list -}}
{{- range $i := until (.Values.replicaCount | int) -}}
{{- $hosts = append $hosts (printf "%s-%d.%s" (include "zookeeper.fullname" $root) $i (include "zookeeper.headlessFqdn" $root)) -}}
{{- end -}}
{{- join " " $hosts -}}
{{- end -}}

{{- define "zookeeper.authPassword" -}}
{{- if .Values.auth.client.password -}}
{{- .Values.auth.client.password -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}

{{- define "zookeeper.jaasString" -}}
{{- printf "%s" . | replace "\\" "\\\\" | replace "\"" "\\\"" -}}
{{- end -}}

{{- define "zookeeper.externalSecretTargetName" -}}
{{- if .Values.externalSecrets.target.name -}}
{{- .Values.externalSecrets.target.name -}}
{{- else if and .Values.tls.client.enabled (not .Values.auth.client.enabled) -}}
{{- include "zookeeper.tlsPasswordsSecretName" . -}}
{{- else -}}
{{- include "zookeeper.authSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "zookeeper.authSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled (eq (include "zookeeper.externalSecretTargetName" .) (include "zookeeper.authSecretName" .)) -}}true{{- end -}}
{{- end -}}

{{- define "zookeeper.tlsPasswordsSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled (eq (include "zookeeper.externalSecretTargetName" .) (include "zookeeper.tlsPasswordsSecretName" .)) -}}true{{- end -}}
{{- end -}}

{{- define "zookeeper.hasChartManagedSensitiveSecret" -}}
{{- $authManaged := and .Values.auth.client.enabled (not .Values.auth.client.existingSecret) (not (include "zookeeper.authSecretManagedByExternalSecret" .)) -}}
{{- $tlsManaged := and .Values.tls.client.enabled (not .Values.tls.client.existingPasswordsSecret) (not (include "zookeeper.tlsPasswordsSecretManagedByExternalSecret" .)) -}}
{{- if or $authManaged $tlsManaged -}}true{{- end -}}
{{- end -}}

{{- define "zookeeper.fourLetterWordWhitelist" -}}
{{- $commands := list -}}
{{- range $command := splitList "," .Values.zookeeper.fourLetterWordWhitelist -}}
{{- $trimmed := trim $command -}}
{{- if $trimmed -}}
{{- $commands = append $commands $trimmed -}}
{{- end -}}
{{- end -}}
{{- if not (has "srvr" $commands) -}}
{{- $commands = append $commands "srvr" -}}
{{- end -}}
{{- join "," (uniq $commands) -}}
{{- end -}}

{{- define "zookeeper.validate" -}}
{{- if lt (.Values.replicaCount | int) 1 -}}
{{- fail "replicaCount must be at least 1" -}}
{{- end -}}
{{- if and (not .Values.allowEvenReplicas) (gt (.Values.replicaCount | int) 1) (eq (mod (.Values.replicaCount | int) 2) 0) -}}
{{- fail "replicaCount must be odd for quorum safety unless allowEvenReplicas=true" -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}
{{- fail "metrics.serviceMonitor.enabled requires metrics.enabled=true" -}}
{{- end -}}
{{- if and .Values.metrics.prometheusRule.enabled (not .Values.metrics.enabled) -}}
{{- fail "metrics.prometheusRule.enabled requires metrics.enabled=true" -}}
{{- end -}}
{{- if and .Values.tls.client.enabled (not .Values.tls.client.existingSecret) -}}
{{- fail "tls.client.enabled requires tls.client.existingSecret" -}}
{{- end -}}
{{- if and .Values.zookeeper.extraConfig (regexMatch "[ \t]" .Values.zookeeper.extraConfig) -}}
{{- fail "zookeeper.extraConfig cannot contain spaces or tabs because the official entrypoint splits ZOO_CFG_EXTRA on whitespace" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.enabled requires externalSecrets.secretStoreRef.name" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (ne .Values.externalSecrets.apiVersion "external-secrets.io/v1") -}}
{{- fail "externalSecrets.apiVersion must be external-secrets.io/v1" -}}
{{- end -}}
{{- end -}}
