{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "rustfs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Reserve 11 characters for the StatefulSet revision suffix: hyphen + 10-digit hash. */}}
{{- define "rustfs.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 52 | trimSuffix "-" -}}
{{- else -}}
{{- $raw := printf "%s-%s" .Release.Name (include "rustfs.name" .) -}}
{{- if gt (len $raw) 52 -}}
{{- printf "%s-%s" ($raw | trunc 43 | trimSuffix "-") ($raw | sha256sum | trunc 8) -}}
{{- else -}}
{{- $raw -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "rustfs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "rustfs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rustfs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "rustfs.labels" -}}
helm.sh/chart: {{ include "rustfs.chart" . }}
{{ include "rustfs.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "rustfs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "rustfs.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "rustfs.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}


{{- define "rustfs.secretName" -}}
{{- default (include "rustfs.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}
{{- define "rustfs.volumes" -}}
{{- if has .Values.architecture (list "distributed" "cluster") -}}
{{- printf "http://%s-{0...%d}.%s-headless.%s.svc.%s:%d/data" (include "rustfs.fullname" .) (sub (int .Values.replicaCount) 1) (include "rustfs.fullname" .) .Release.Namespace .Values.clusterDomain (int .Values.containerPorts.api) -}}
{{- else -}}/data{{- end -}}
{{- end -}}
{{/* Auxiliary pods retain common metadata without matching storage Service selectors. */}}
{{- define "rustfs.auxiliaryLabels" -}}
{{- $labels := omit (include "rustfs.labels" .root | fromYaml) "app.kubernetes.io/name" -}}
{{- $_ := set $labels "app.kubernetes.io/component" .component -}}
{{- toYaml $labels -}}
{{- end -}}

{{- define "rustfs.replicationLocalEndpoint" -}}
{{- default (printf "http://%s.%s.svc.%s:%v" (include "rustfs.fullname" .) .Release.Namespace .Values.clusterDomain .Values.service.port) .Values.replication.localEndpoint | trimSuffix "/" -}}
{{- end -}}

{{- define "rustfs.validate" -}}
{{- if and (eq .Values.architecture "standalone") (ne (int .Values.replicaCount) 1) -}}
{{- fail "standalone requires replicaCount=1" -}}{{- end -}}
{{- if has .Values.architecture (list "distributed" "cluster") -}}
{{- if lt (int .Values.replicaCount) 4 -}}{{- fail "distributed requires replicaCount>=4" -}}{{- end -}}
{{- if or (not .Values.persistence.enabled) .Values.persistence.existingClaim -}}{{- fail "distributed requires persistence.enabled=true and a separate claim per pod (no existingClaim)" -}}{{- end -}}
{{- end -}}
{{- if and (not .Values.persistence.enabled) .Values.persistence.existingClaim -}}
{{- fail "persistence.existingClaim requires persistence.enabled=true" -}}
{{- end -}}
{{- if .Values.replication.enabled -}}
{{- $names := dict -}}
{{- $endpoints := dict -}}
{{- range .Values.replication.peers -}}
{{- if hasKey $names .name -}}{{- fail "replication peer names must be unique" -}}{{- end -}}
{{- $_ := set $names .name true -}}
{{- $endpoint := trimSuffix "/" .endpoint -}}
{{- if hasKey $endpoints $endpoint -}}{{- fail "replication peer endpoints must be unique" -}}{{- end -}}
{{- $_ := set $endpoints $endpoint true -}}
{{- if eq (trimSuffix "/" .endpoint) (include "rustfs.replicationLocalEndpoint" $) -}}{{- fail "replication peer endpoint must differ from localEndpoint" -}}{{- end -}}
{{- end -}}
{{- $ids := dict -}}{{- $priorities := dict -}}
{{- range .Values.replication.buckets -}}
{{- if not (hasKey $names .destinationPeer) -}}{{- fail "replication bucket destinationPeer must reference a configured peer" -}}{{- end -}}
{{- $id := printf "%s/%s" .sourceBucket .id -}}
{{- $priority := printf "%s/%v" .sourceBucket .priority -}}
{{- if hasKey $ids $id -}}{{- fail "replication rule IDs must be unique per source bucket" -}}{{- end -}}
{{- if hasKey $priorities $priority -}}{{- fail "replication rule priorities must be unique per source bucket" -}}{{- end -}}
{{- $_ := set $ids $id true -}}{{- $_ := set $priorities $priority true -}}
{{- end -}}
{{- end -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if hasKey (include "rustfs.selectorLabels" $ | fromYaml) $key -}}{{- fail "podLabels must not override selector labels" -}}{{- end -}}
{{- end -}}
{{- range $key, $_ := .Values.commonLabels -}}
{{- if hasKey (include "rustfs.selectorLabels" $ | fromYaml) $key -}}{{- fail "commonLabels must not override selector labels" -}}{{- end -}}
{{- end -}}
{{- range $i := list .Values.ingress .Values.consoleIngress -}}
{{- if and $i.enabled (empty $i.hosts) -}}{{- fail "enabled ingress requires hosts" -}}{{- end -}}
{{- end -}}
{{- if and .Values.consoleIngress.enabled (not .Values.config.consoleEnabled) -}}{{- fail "consoleIngress requires config.consoleEnabled=true" -}}{{- end -}}
{{- if and .Values.config.consoleEnabled (eq (int .Values.containerPorts.api) (int .Values.containerPorts.console)) -}}
{{- fail "containerPorts.api and containerPorts.console must differ when the console is enabled" -}}
{{- end -}}
{{- end -}}
