{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "booklore.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "booklore.fullname" -}}
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

{{- define "booklore.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "booklore.labels" -}}
helm.sh/chart: {{ include "booklore.chart" . }}
{{ include "booklore.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "booklore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "booklore.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "booklore.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "booklore.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "booklore.nameWithSuffix" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $max := int (default 63 .max) -}}
{{- $baseMax := int (sub $max (len $suffix)) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc $max | trimSuffix "-" -}}
{{- end -}}

{{- define "booklore.appSecretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "booklore.nameWithSuffix" (dict "base" (include "booklore.fullname" .) "suffix" "-app") -}}
{{- end -}}
{{- end -}}

{{- define "booklore.mariadb.fullname" -}}
{{- if .Values.mariadb.fullnameOverride -}}
{{- .Values.mariadb.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "mariadb" .Values.mariadb.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "booklore.dbHost" -}}
{{- if .Values.mariadb.enabled -}}
{{- include "booklore.mariadb.fullname" . -}}
{{- else -}}
{{- .Values.database.external.host -}}
{{- end -}}
{{- end -}}

{{- define "booklore.dbPort" -}}
{{- if .Values.mariadb.enabled -}}
{{- dig "service" "port" 3306 .Values.mariadb -}}
{{- else -}}
{{- .Values.database.external.port | default "3306" -}}
{{- end -}}
{{- end -}}

{{- define "booklore.dbName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.database | default "booklore" -}}
{{- else -}}
{{- .Values.database.external.name | default "booklore" -}}
{{- end -}}
{{- end -}}

{{- define "booklore.dbUsername" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.username | default "booklore" -}}
{{- else -}}
{{- .Values.database.external.username | default "root" -}}
{{- end -}}
{{- end -}}

{{- define "booklore.dbSecretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecret -}}
{{- .Values.mariadb.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "booklore.mariadb.fullname" .) -}}
{{- end -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- include "booklore.nameWithSuffix" (dict "base" (include "booklore.fullname" .) "suffix" "-db") -}}
{{- end -}}
{{- end -}}

{{- define "booklore.dbSecretPasswordKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecretUserPasswordKey -}}
{{- .Values.mariadb.auth.existingSecretUserPasswordKey -}}
{{- else -}}
mariadb-user-password
{{- end -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey | default "password" -}}
{{- else -}}
password
{{- end -}}
{{- end -}}

{{- define "booklore.dbUrl" -}}
jdbc:mariadb://{{ include "booklore.dbHost" . }}:{{ include "booklore.dbPort" . }}/{{ include "booklore.dbName" . }}?createDatabaseIfNotExist=true&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true
{{- end -}}

{{- define "booklore.persistenceClaimName" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $persistence := index $root.Values.persistence $name -}}
{{- if $persistence.existingClaim -}}
{{- $persistence.existingClaim -}}
{{- else -}}
{{- include "booklore.nameWithSuffix" (dict "base" (include "booklore.fullname" $root) "suffix" (printf "-%s" $name)) -}}
{{- end -}}
{{- end -}}

{{- define "booklore.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := .index | default 0 -}}
{{- if $route.name -}}
{{- $suffix := printf "-%s" $route.name -}}
{{- $base := include "booklore.fullname" $root | trunc (int (max 1 (sub 63 (len $suffix)))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix | trunc 63 | trimSuffix "-" -}}
{{- else if gt (int $index) 0 -}}
{{- $suffix := printf "-%d" (int $index) -}}
{{- $base := include "booklore.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "booklore.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "booklore.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- $suffix := printf "-%s" $item.name -}}
{{- $base := include "booklore.fullname" $root | trunc (int (max 1 (sub 63 (len $suffix)))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix | trunc 63 | trimSuffix "-" -}}
{{- else if gt $index 0 -}}
{{- $suffix := printf "-%d" $index -}}
{{- $base := include "booklore.fullname" $root | trunc (int (sub 63 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- else -}}
{{- include "booklore.appSecretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "booklore.validate" -}}
{{- if and (not .Values.mariadb.enabled) (empty .Values.database.external.host) -}}
{{- fail "database.external.host is required when mariadb.enabled=false" -}}
{{- end -}}
{{- if and (not .Values.mariadb.enabled) (not .Values.database.external.existingSecret) (empty .Values.database.external.password) -}}
{{- fail "database.external.password or database.external.existingSecret is required when mariadb.enabled=false" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}
{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}
{{- end -}}
{{- if and (not .Values.mariadb.enabled) .Values.networkPolicy.egress.enabled (not .Values.networkPolicy.egress.databaseTo) -}}
{{- fail "networkPolicy.egress.databaseTo must contain at least one peer when mariadb.enabled=false and networkPolicy.egress.enabled=true" -}}
{{- end -}}
{{- if and (not .Values.mariadb.enabled) .Values.networkPolicy.egress.enabled .Values.networkPolicy.egress.databaseTo (empty .Values.networkPolicy.egress.databaseTo) -}}
{{- fail "networkPolicy.egress.databaseTo must not be empty when mariadb.enabled=false and networkPolicy.egress.enabled=true" -}}
{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/name" -}}
{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}
{{- fail "podLabels must not override the selector label app.kubernetes.io/instance" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}
{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if and .Values.autoscaling.enabled (gt (int .Values.autoscaling.maxReplicas) 1) .Values.persistence.data.enabled (ne .Values.persistence.data.accessMode "ReadWriteMany") -}}
{{- fail "autoscaling.maxReplicas > 1 with persistence.data.accessMode=ReadWriteOnce will cause volume scheduling failures; set persistence.data.accessMode=ReadWriteMany or disable persistence" -}}
{{- end -}}
{{- end -}}
