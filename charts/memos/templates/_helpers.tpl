{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "memos.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "memos.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "memos.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "memos.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "memos.selectorLabels" -}}
app.kubernetes.io/name: {{ include "memos.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "memos.labels" -}}
helm.sh/chart: {{ include "memos.chart" . }}
{{ include "memos.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "memos.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "memos.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "memos.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}
{{- define "memos.databaseSecretName" -}}{{- default (printf "%s-database" (include "memos.fullname" .)) .Values.database.existingSecret -}}{{- end -}}

{{- define "memos.validate" -}}
{{- if and (gt (int .Values.replicaCount) 1) (eq .Values.database.driver "sqlite") -}}
{{- fail "replicaCount > 1 requires database.driver=mysql or database.driver=postgres because SQLite cannot safely share state across Memos pods" -}}
{{- end -}}
{{- if and (ne .Values.database.driver "sqlite") (not (or .Values.database.dsn .Values.database.existingSecret)) -}}
{{- fail "database.dsn or database.existingSecret is required when database.driver is mysql or postgres" -}}
{{- end -}}
{{- if and (ne .Values.database.driver "sqlite") (not .Values.persistence.enabled) (not .Values.persistence.existingClaim) -}}
{{- fail "persistence.enabled or persistence.existingClaim is required with external databases because Memos still stores local assets in MEMOS_DATA" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (ne .Values.database.driver "sqlite") (not .Values.persistence.existingClaim) -}}
{{- fail "replicaCount > 1 with mysql or postgres requires persistence.existingClaim backed by shared storage because generated StatefulSet PVCs are per-pod and Memos can store local assets in MEMOS_DATA" -}}
{{- end -}}
{{- $podLabels := .Values.podLabels | default dict -}}
{{- range $key := (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}
{{- if hasKey $podLabels $key -}}
{{- fail (printf "podLabels must not override the selector label %s" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
