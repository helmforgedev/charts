{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "atuin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "atuin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "atuin.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "atuin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "atuin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atuin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "atuin.labels" -}}
helm.sh/chart: {{ include "atuin.chart" . }}
{{ include "atuin.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "atuin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "atuin.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "atuin.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "atuin.healthPath" -}}
{{- $prefix := trimSuffix "/" .Values.atuin.path -}}
{{- printf "%s/healthz" $prefix -}}
{{- end -}}

{{- define "atuin.postgresqlSecretName" -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- include "postgresql.secretName" .Subcharts.postgresql -}}
{{- end -}}
{{- end -}}

{{- define "atuin.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := .index -}}
{{- coalesce $item.fullnameOverride $item.name (printf "%s-%d" (include "atuin.fullname" $root) $index) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "atuin.validate" -}}
{{- if not (has .Values.database.type (list "sqlite" "postgresql")) -}}
{{- fail "database.type must be sqlite or postgresql" -}}
{{- end -}}
{{- if and (eq .Values.database.type "sqlite") .Values.postgresql.enabled -}}
{{- fail "postgresql.enabled requires database.type=postgresql" -}}
{{- end -}}
{{- if and (eq .Values.database.type "sqlite") (ne (int .Values.replicaCount) 1) -}}
{{- fail "SQLite requires replicaCount=1" -}}
{{- end -}}
{{- if and (eq .Values.database.type "sqlite") .Values.autoscaling.enabled -}}
{{- fail "autoscaling is not supported with SQLite" -}}
{{- end -}}
{{- if and (eq .Values.database.type "sqlite") (not .Values.persistence.enabled) -}}
{{- fail "SQLite requires persistence.enabled=true" -}}
{{- end -}}
{{- if and (eq .Values.database.type "postgresql") (not .Values.postgresql.enabled) (not .Values.database.existingSecret) -}}
{{- fail "external PostgreSQL requires database.existingSecret containing the complete URI" -}}
{{- end -}}
{{- if and .Values.postgresql.enabled .Values.database.existingSecret -}}
{{- fail "database.existingSecret cannot be combined with postgresql.enabled=true" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}
{{- fail "ingress.enabled requires at least one ingress.hosts entry" -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}
{{- fail "gatewayAPI.enabled requires at least one gatewayAPI.httpRoutes entry" -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}
{{- fail "metrics.serviceMonitor.enabled requires metrics.enabled=true" -}}
{{- end -}}
{{- $selector := include "atuin.selectorLabels" . | fromYaml -}}
{{- range $key, $_ := .Values.podLabels -}}
{{- if hasKey $selector $key -}}
{{- fail (printf "podLabels must not override selector label %q" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
