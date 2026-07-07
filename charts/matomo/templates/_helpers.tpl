{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "matomo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "matomo.fullname" -}}
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

{{- define "matomo.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{- define "matomo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "matomo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matomo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "matomo.labels" -}}
helm.sh/chart: {{ include "matomo.chart" . }}
{{ include "matomo.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "matomo.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default (printf "%s-apache" .Chart.AppVersion)) -}}
{{- end -}}

{{- define "matomo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "matomo.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "matomo.suffixedName" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $baseMax := int (max 1 (sub 63 (len $suffix))) -}}
{{- printf "%s%s" ($base | trunc $baseMax | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "matomo.configMapName" -}}
{{- include "matomo.suffixedName" (dict "base" (include "matomo.fullname" .) "suffix" "-config") -}}
{{- end -}}

{{- define "matomo.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- if not (has $mode (list "auto" "external" "mysql")) -}}
{{- fail (printf "database.mode must be one of: auto, external, mysql (got %s)" $mode) -}}
{{- end -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal $hasMysql -}}
    {{- fail "matomo database selection is ambiguous: configure only one of database.external.host or mysql.enabled" -}}
  {{- end -}}
  {{- if $hasExternal -}}external{{- else if $hasMysql -}}mysql{{- else -}}{{- fail "matomo requires a database: set database.external.host or mysql.enabled=true" -}}{{- end -}}
{{- else -}}
  {{- if and (eq $mode "external") (not $hasExternal) -}}{{- fail "database.mode=external requires database.external.host or database.external.existingSecret" -}}{{- end -}}
  {{- if and (eq $mode "external") $hasMysql -}}{{- fail "database.mode=external cannot be combined with mysql.enabled" -}}{{- end -}}
  {{- if and (eq $mode "mysql") (not $hasMysql) -}}{{- fail "database.mode=mysql requires mysql.enabled=true" -}}{{- end -}}
  {{- if and (eq $mode "mysql") $hasExternal -}}{{- fail "database.mode=mysql cannot be combined with database.external" -}}{{- end -}}
  {{- $mode -}}
{{- end -}}
{{- end -}}

{{- define "matomo.databaseHost" -}}
{{- if eq (include "matomo.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "matomo.databasePort" -}}
{{- if eq (include "matomo.databaseMode" .) "external" -}}
{{- .Values.database.external.port | default 3306 | toString -}}
{{- else -}}
{{- print "3306" -}}
{{- end -}}
{{- end -}}

{{- define "matomo.databaseName" -}}
{{- if eq (include "matomo.databaseMode" .) "external" -}}{{- .Values.database.external.name -}}{{- else -}}{{- .Values.mysql.auth.database -}}{{- end -}}
{{- end -}}

{{- define "matomo.databaseUsername" -}}
{{- if eq (include "matomo.databaseMode" .) "external" -}}{{- .Values.database.external.username -}}{{- else -}}{{- .Values.mysql.auth.username -}}{{- end -}}
{{- end -}}

{{- define "matomo.databaseSecretName" -}}
{{- if and (eq (include "matomo.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if eq (include "matomo.databaseMode" .) "mysql" -}}
{{- printf "%s-mysql-auth" .Release.Name -}}
{{- else -}}
{{- include "matomo.suffixedName" (dict "base" (include "matomo.fullname" .) "suffix" "-database") -}}
{{- end -}}
{{- end -}}

{{- define "matomo.databaseSecretKey" -}}
{{- if and (eq (include "matomo.databaseMode" .) "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else if eq (include "matomo.databaseMode" .) "mysql" -}}
{{- print "mysql-user-password" -}}
{{- else -}}
{{- print "database-password" -}}
{{- end -}}
{{- end -}}

{{- define "matomo.siteUrl" -}}
{{- if .Values.matomo.siteUrl -}}
{{- .Values.matomo.siteUrl -}}
{{- else -}}
{{- printf "http://%s.%s.svc.%s:%d" (include "matomo.fullname" .) (include "matomo.namespace" .) (.Values.clusterDomain | default "cluster.local") (.Values.service.port | int) -}}
{{- end -}}
{{- end -}}

{{- define "matomo.httpRouteName" -}}
{{- $root := .root -}}
{{- $route := .route -}}
{{- $index := int (.index | default 0) -}}
{{- if $route.name -}}
{{- include "matomo.suffixedName" (dict "base" (include "matomo.fullname" $root) "suffix" (printf "-%s" $route.name)) -}}
{{- else if gt $index 0 -}}
{{- include "matomo.suffixedName" (dict "base" (include "matomo.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "matomo.fullname" $root -}}
{{- end -}}
{{- end -}}

{{- define "matomo.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := int (.index | default 0) -}}
{{- if $item.fullnameOverride -}}
{{- $item.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if $item.name -}}
{{- include "matomo.suffixedName" (dict "base" (include "matomo.fullname" $root) "suffix" (printf "-%s" $item.name)) -}}
{{- else if gt $index 0 -}}
{{- include "matomo.suffixedName" (dict "base" (include "matomo.fullname" $root) "suffix" (printf "-%d" $index)) -}}
{{- else -}}
{{- include "matomo.databaseSecretName" $root -}}
{{- end -}}
{{- end -}}

{{- define "matomo.hasDatabaseExternalSecret" -}}
{{- $root := . -}}
{{- $databaseSecretName := include "matomo.databaseSecretName" . -}}
{{- $found := dict "value" false -}}
{{- if .Values.externalSecrets.enabled -}}
{{- range $index, $item := .Values.externalSecrets.items }}
{{- $externalSecretName := include "matomo.externalSecretName" (dict "root" $root "item" $item "index" $index) -}}
{{- $targetName := dig "spec" "target" "name" $externalSecretName $item -}}
{{- if eq (toString $targetName) $databaseSecretName -}}
{{- $_ := set $found "value" true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $found.value -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "matomo.validate" -}}
{{- $databaseMode := include "matomo.databaseMode" . -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{- fail "ingress.hosts must contain at least one host when ingress.enabled=true" -}}{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.httpRoutes) -}}{{- fail "gatewayAPI.httpRoutes must contain at least one route when gatewayAPI.enabled=true" -}}{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.serviceMonitor.interval) -}}{{- fail "metrics.serviceMonitor.interval is required when metrics.serviceMonitor.enabled=true" -}}{{- end -}}
{{- if and (eq $databaseMode "external") (not .Values.database.external.existingSecret) (not .Values.database.external.password) (ne (include "matomo.hasDatabaseExternalSecret" .) "true") -}}{{- fail "external database mode requires database.external.password, database.external.existingSecret, or ExternalSecret targeting the database secret" -}}{{- end -}}
{{- if .Values.podLabels -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/name" -}}{{- fail "podLabels must not override app.kubernetes.io/name" -}}{{- end -}}
{{- if hasKey .Values.podLabels "app.kubernetes.io/instance" -}}{{- fail "podLabels must not override app.kubernetes.io/instance" -}}{{- end -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (empty .Values.externalSecrets.items) -}}{{- fail "externalSecrets.items must contain at least one item when externalSecrets.enabled=true" -}}{{- end -}}
{{- range $i, $item := .Values.externalSecrets.items }}
{{- if and $.Values.externalSecrets.enabled (not $item.spec.secretStoreRef) (not $item.spec.data) (not $item.spec.dataFrom) -}}{{- fail (printf "externalSecrets.items[%d].spec must define secretStoreRef/data or dataFrom" $i) -}}{{- end -}}
{{- end -}}
{{- end -}}
