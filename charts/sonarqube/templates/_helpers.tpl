{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "sonarqube.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sonarqube.fullname" -}}
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

{{- define "sonarqube.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sonarqube.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sonarqube.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sonarqube.labels" -}}
helm.sh/chart: {{ include "sonarqube.chart" . }}
{{ include "sonarqube.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: sonarqube
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "sonarqube.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sonarqube.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "sonarqube.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{- define "sonarqube.configMapName" -}}
{{- printf "%s-config" (include "sonarqube.fullname" .) }}
{{- end }}

{{- define "sonarqube.secretName" -}}
{{- printf "%s-secrets" (include "sonarqube.fullname" .) }}
{{- end }}

{{- define "sonarqube.dataClaimName" -}}
{{- default (printf "%s-data" (include "sonarqube.fullname" .)) .Values.persistence.data.existingClaim }}
{{- end }}

{{- define "sonarqube.extensionsClaimName" -}}
{{- default (printf "%s-extensions" (include "sonarqube.fullname" .)) .Values.persistence.extensions.existingClaim }}
{{- end }}

{{- define "sonarqube.logsClaimName" -}}
{{- default (printf "%s-logs" (include "sonarqube.fullname" .)) .Values.persistence.logs.existingClaim }}
{{- end }}

{{- define "sonarqube.databaseSecretName" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled .Values.externalSecrets.database.targetName -}}
{{- .Values.externalSecrets.database.targetName -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled -}}
{{- printf "%s-database" (include "sonarqube.fullname" .) -}}
{{- else if .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else -}}
{{- include "sonarqube.secretName" . -}}
{{- end -}}
{{- end }}

{{- define "sonarqube.databaseSecretKey" -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- end }}

{{- define "sonarqube.monitoringSecretName" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.monitoringPasscode.enabled .Values.externalSecrets.monitoringPasscode.targetName -}}
{{- .Values.externalSecrets.monitoringPasscode.targetName -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.monitoringPasscode.enabled -}}
{{- printf "%s-monitoring" (include "sonarqube.fullname" .) -}}
{{- else if .Values.sonarqube.existingMonitoringPasscodeSecret -}}
{{- .Values.sonarqube.existingMonitoringPasscodeSecret -}}
{{- else -}}
{{- include "sonarqube.secretName" . -}}
{{- end -}}
{{- end }}

{{- define "sonarqube.monitoringSecretKey" -}}
{{- .Values.sonarqube.existingMonitoringPasscodeSecretKey -}}
{{- end }}

{{- define "sonarqube.communityBranchJarUrl" -}}
{{- if .Values.communityBranchPlugin.jarUrl -}}
{{- .Values.communityBranchPlugin.jarUrl -}}
{{- else -}}
{{- printf "https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/%s/sonarqube-community-branch-plugin-%s.jar" .Values.communityBranchPlugin.version .Values.communityBranchPlugin.version -}}
{{- end -}}
{{- end }}

{{- define "sonarqube.communityBranchWebappUrl" -}}
{{- if .Values.communityBranchPlugin.webappUrl -}}
{{- .Values.communityBranchPlugin.webappUrl -}}
{{- else -}}
{{- printf "https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/%s/sonarqube-webapp.zip" .Values.communityBranchPlugin.version -}}
{{- end -}}
{{- end }}

{{- define "sonarqube.communityBranchJarName" -}}
{{- printf "sonarqube-community-branch-plugin-%s.jar" .Values.communityBranchPlugin.version }}
{{- end }}

{{- define "sonarqube.externalSecretDataItem" -}}
- secretKey: {{ .secretKey | quote }}
  remoteRef:
    {{- if not .remoteRef.key }}
    {{- fail (printf "%s.key is required when %s=true" .remoteRefName .enabledName) }}
    {{- end }}
    key: {{ .remoteRef.key | quote }}
    {{- with .remoteRef.property }}
    property: {{ . | quote }}
    {{- end }}
    {{- with .remoteRef.version }}
    version: {{ . | quote }}
    {{- end }}
    {{- with .remoteRef.decodingStrategy }}
    decodingStrategy: {{ . | quote }}
    {{- end }}
    {{- with .remoteRef.conversionStrategy }}
    conversionStrategy: {{ . | quote }}
    {{- end }}
{{- end }}

{{- define "sonarqube.validate" -}}
{{- if not (has .Values.sonarqube.databaseMode (list "embedded" "external")) -}}
{{- fail "sonarqube.databaseMode must be embedded or external" -}}
{{- end -}}
{{- if eq .Values.sonarqube.databaseMode "external" -}}
  {{- if not .Values.database.external.jdbcUrl -}}
    {{- fail "database.external.jdbcUrl is required when sonarqube.databaseMode=external" -}}
  {{- end -}}
  {{- if not .Values.database.external.username -}}
    {{- fail "database.external.username is required when sonarqube.databaseMode=external" -}}
  {{- end -}}
  {{- if and (not .Values.database.external.password) (not .Values.database.external.existingSecret) (not (and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled)) -}}
    {{- fail "database.external.password, database.external.existingSecret, or externalSecrets.database.enabled is required when sonarqube.databaseMode=external" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.parentRefs) -}}
{{- fail "gatewayAPI.parentRefs must contain at least one parentRef when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.database.enabled (not .Values.externalSecrets.enabled) -}}
{{- fail "externalSecrets.enabled must be true when externalSecrets.database.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.monitoringPasscode.enabled (not .Values.externalSecrets.enabled) -}}
{{- fail "externalSecrets.enabled must be true when externalSecrets.monitoringPasscode.enabled=true" -}}
{{- end -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- end }}
