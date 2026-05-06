{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "phpmyadmin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "phpmyadmin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "phpmyadmin.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "phpmyadmin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "phpmyadmin.labels" -}}
helm.sh/chart: {{ include "phpmyadmin.chart" . }}
{{ include "phpmyadmin.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "phpmyadmin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "phpmyadmin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "phpmyadmin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "phpmyadmin.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "phpmyadmin.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{/* ExternalSecret auth is active only when both flags are enabled */}}
{{- define "phpmyadmin.externalSecretAuthEnabled" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.auth.enabled -}}true{{- end -}}
{{- end -}}

{{/* Auth secret name */}}
{{- define "phpmyadmin.authSecretName" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.auth.enabled .Values.externalSecrets.auth.targetName -}}
{{- .Values.externalSecrets.auth.targetName -}}
{{- else if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-auth" (include "phpmyadmin.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Config ConfigMap name */}}
{{- define "phpmyadmin.configMapName" -}}
{{- if .Values.config.existingConfigMap -}}
{{- .Values.config.existingConfigMap -}}
{{- else -}}
{{- printf "%s-config" (include "phpmyadmin.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* phpMyAdmin settings that must be applied through config.user.inc.php */}}
{{- define "phpmyadmin.needsGeneratedConfig" -}}
{{- if or (ne .Values.phpmyadmin.authType "cookie") .Values.auth.blowfishSecret .Values.auth.existingSecret (eq (include "phpmyadmin.externalSecretAuthEnabled" .) "true") -}}true{{- end -}}
{{- end -}}

{{- define "phpmyadmin.needsConfigMount" -}}
{{- if or .Values.config.customConfig .Values.config.existingConfigMap (eq (include "phpmyadmin.needsGeneratedConfig" .) "true") -}}true{{- end -}}
{{- end -}}

{{- define "phpmyadmin.csvRepeatForHosts" -}}
{{- $items := list -}}
{{- range splitList "," .hosts -}}
{{- $items = append $items $.value -}}
{{- end -}}
{{- join "," $items -}}
{{- end -}}

{{- define "phpmyadmin.generatedConfig" -}}
<?php
{{- if ne .Values.phpmyadmin.authType "cookie" }}
$cfg['Servers'][$i]['auth_type'] = {{ .Values.phpmyadmin.authType | quote }};
{{- end }}
{{- if or .Values.auth.blowfishSecret .Values.auth.existingSecret (eq (include "phpmyadmin.externalSecretAuthEnabled" .) "true") }}
$helmforgeBlowfishSecret = getenv('HELMFORGE_BLOWFISH_SECRET');
if ($helmforgeBlowfishSecret !== false && $helmforgeBlowfishSecret !== '') {
    $cfg['blowfish_secret'] = $helmforgeBlowfishSecret;
}
{{- end }}
{{- end -}}

{{/* ExternalSecret remoteRef item */}}
{{- define "phpmyadmin.externalSecretDataItem" -}}
- secretKey: {{ .secretKey | quote }}
  remoteRef:
    {{- if not .remoteRef.key }}
    {{- fail (printf "%s.key is required when externalSecrets.auth.enabled=true" .remoteRefName) }}
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
{{- end -}}

{{/* Validate ExternalSecret settings */}}
{{- define "phpmyadmin.validateExternalSecrets" -}}
{{- if and .Values.externalSecrets.auth.enabled (not .Values.externalSecrets.enabled) -}}
{{- fail "externalSecrets.enabled must be true when externalSecrets.auth.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled .Values.auth.existingSecret .Values.externalSecrets.auth.enabled -}}
{{- fail "auth.existingSecret and externalSecrets.auth.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.auth.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.auth.enabled=true" -}}
{{- end -}}
{{- end -}}

{{/* Validate Gateway API settings */}}
{{- define "phpmyadmin.validateGatewayAPI" -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.parentRefs) -}}
{{- fail "gatewayAPI.parentRefs must contain at least one parentRef when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- end -}}
