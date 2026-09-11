{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "mssql.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 40 | trimSuffix "-" }}{{- end -}}
{{- define "mssql.fullname" -}}{{ default (printf "%s-%s" .Release.Name (include "mssql.name" .)) .Values.fullnameOverride | trunc 40 | trimSuffix "-" }}{{- end -}}
{{- define "mssql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mssql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "mssql.labels" -}}
{{ include "mssql.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{ end }}
{{- end -}}
{{- define "mssql.image" -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- define "mssql.authSecret" -}}{{ default (printf "%s-auth" (include "mssql.fullname" .)) .Values.auth.existingSecret }}{{- end -}}
{{- define "mssql.tlsSecret" -}}{{ default (printf "%s-tls" (include "mssql.fullname" .)) .Values.tls.existingSecret }}{{- end -}}
{{- define "mssql.dataClaim" -}}{{ default (printf "%s-data" (include "mssql.fullname" .)) .Values.persistence.existingClaim }}{{- end -}}
{{- define "mssql.backupClaim" -}}{{ default (printf "%s-backup" (include "mssql.fullname" .)) .Values.backup.staging.existingClaim }}{{- end -}}
{{- define "mssql.serviceAccountName" -}}{{ if .Values.serviceAccount.create }}{{ default (include "mssql.fullname" .) .Values.serviceAccount.name }}{{ else }}{{ default "default" .Values.serviceAccount.name }}{{ end }}{{- end -}}
{{- define "mssql.edition" -}}{{ if and (hasPrefix "2025-" .Values.image.tag) (eq .Values.sql.edition "Developer") }}EnterpriseDeveloper{{ else }}{{ .Values.sql.edition }}{{ end }}{{- end -}}
{{- define "mssql.externalSecretName" -}}{{ if .item.fullnameOverride }}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" (include "mssql.fullname" .root) (default "auth" .item.name) | trunc 63 | trimSuffix "-" }}{{ end }}{{- end -}}
{{- define "mssql.validateExternalSecrets" -}}
{{- $names := dict -}}{{- range .Values.externalSecrets.items -}}{{- $name := include "mssql.externalSecretName" (dict "root" $ "item" .) -}}{{- if hasKey $names $name -}}{{ fail "ExternalSecret names must be unique after rendering and truncation" }}{{- end -}}{{- $_ := set $names $name true -}}{{- end -}}
{{- end -}}
{{- define "mssql.credentials" -}}
{{- if not (hasKey . "mssqlCredentials") -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "mssql.authSecret" .) -}}
{{- $data := dict -}}{{- range $key := list "sa-password" "probe-password" "metrics-password" "backup-password" -}}
{{- $password := printf "Hf9!%s" (randAlphaNum 44) -}}
{{- if and $existing (hasKey $existing.data $key) -}}{{- $password = index $existing.data $key | b64dec -}}{{- end -}}
{{- $_ := set $data $key $password -}}{{- end -}}{{- $_ := set . "mssqlCredentials" $data -}}
{{- end -}}
{{- toJson .mssqlCredentials -}}
{{- end -}}
{{- define "mssql.validate" -}}
{{- if and (hasPrefix "2025-" .Values.image.tag) (eq .Values.sql.edition "Web") -}}{{ fail "Web edition is unavailable on SQL Server 2025" }}{{- end -}}
{{- if and (hasPrefix "2022-" .Values.image.tag) (has .Values.sql.edition (list "StandardDeveloper" "EnterpriseDeveloper")) -}}{{ fail "SQL Server 2022 uses Developer, not the 2025 developer edition names" }}{{- end -}}
{{- if and .Values.sql.agent.enabled (eq .Values.sql.edition "Express") -}}{{ fail "SQL Server Agent is unavailable in Express" }}{{- end -}}
{{- if and (eq .Values.sql.edition "ProductKey") (not .Values.license.existingSecret) -}}{{ fail "ProductKey edition requires license.existingSecret" }}{{- end -}}
{{- if and .Values.backup.compression (has .Values.sql.edition (list "Express" "Web")) -}}{{ fail "backup compression is unavailable in Express and Web editions" }}{{- end -}}
{{- if and .Values.backup.enabled (or (not .Values.persistence.enabled) (not .Values.backup.databases) (not .Values.backup.s3.bucket)) -}}{{ fail "backup requires persistent storage, explicit databases and an S3 bucket" }}{{- end -}}
{{- if and .Values.backup.enabled (eq (not .Values.backup.s3.existingSecret) (not .Values.backup.workloadIdentity.enabled)) -}}{{ fail "backup requires exactly one static S3 Secret or workload identity" }}{{- end -}}
{{- if and .Values.backup.workloadIdentity.enabled (not .Values.backup.workloadIdentity.roleArn) -}}{{ fail "workload identity requires roleArn" }}{{- end -}}
{{- if and .Values.backup.enabled .Values.networkPolicy.enabled (not .Values.backup.egress) -}}{{ fail "backup.egress must explicitly authorize the object storage endpoint" }}{{- end -}}
{{- if and .Values.metrics.enabled (not .Values.metrics.ingressFrom) -}}{{ fail "metrics.ingressFrom must explicitly authorize Prometheus peers" }}{{- end -}}
{{- if and .Values.metrics.enabled .Values.auth.existingSecret (not .Values.metrics.existingSecret) -}}{{ fail "external auth with metrics requires metrics.existingSecret containing the matching TLS DSN" }}{{- end -}}
{{- if and (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) (not .Values.metrics.enabled) -}}{{ fail "monitoring resources require metrics.enabled" }}{{- end -}}
{{- if and .Values.metrics.prometheusRule.enabled (not .Values.metrics.serviceMonitor.enabled) -}}{{ fail "PrometheusRule requires ServiceMonitor" }}{{- end -}}
{{- if ne (get .Values.nodeSelector "kubernetes.io/arch" | default "amd64") "amd64" -}}{{ fail "Microsoft SQL Server containers require linux/amd64" }}{{- end -}}
{{- if ne (get .Values.nodeSelector "kubernetes.io/os" | default "linux") "linux" -}}{{ fail "Microsoft SQL Server containers require Linux" }}{{- end -}}
{{- $limit := .Values.resources.limits.memory | toString -}}{{- $mi := 0 -}}{{- if hasSuffix "Gi" $limit -}}{{- $mi = mul (trimSuffix "Gi" $limit | int) 1024 -}}{{- else if hasSuffix "Mi" $limit -}}{{- $mi = trimSuffix "Mi" $limit | int -}}{{- end -}}
{{- if or (lt (int $mi) 3072) (gt (int .Values.sql.memoryLimitMB) (sub (int $mi) 512)) -}}{{ fail "memory limit must be at least 3072Mi and exceed sql.memoryLimitMB by at least 512Mi" }}{{- end -}}
{{- $dbs := dict -}}{{- $users := dict -}}{{- range .Values.initdb.databases -}}
{{- if has (lower .name) (list "master" "model" "msdb" "tempdb") -}}{{ fail "initdb cannot manage system databases" }}{{- end -}}
{{- if hasKey $dbs (lower .name) -}}{{ fail "initdb database names must be unique" }}{{- end -}}{{- $_ := set $dbs (lower .name) true -}}
{{- if and .username (or (hasPrefix "hf_" (lower .username)) (eq (lower .username) "sa") (hasKey $users (lower .username))) -}}{{ fail "application usernames must be unique and cannot use sa or reserved hf_ names" }}{{- end -}}
{{- if and .username (not .existingSecret) -}}{{ fail "application logins require an existing password Secret" }}{{- end -}}{{- if .username -}}{{- $_ := set $users (lower .username) true -}}{{- end -}}
{{- end -}}
{{- range $labels := list .Values.commonLabels .Values.podLabels -}}{{- range $key := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" -}}{{- if hasKey $labels $key -}}{{ fail (printf "selector label %s cannot be overridden" $key) }}{{- end -}}{{- end -}}{{- end -}}
{{- end -}}
