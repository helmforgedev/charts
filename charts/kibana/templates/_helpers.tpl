{{/* SPDX-License-Identifier: Apache-2.0 */}}

{{- define "kibana.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kibana.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "kibana.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kibana.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kibana.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kibana.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kibana.labels" -}}
helm.sh/chart: {{ include "kibana.chart" . }}
{{ include "kibana.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "kibana.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "kibana.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "kibana.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- if eq .Values.image.flavor "default" -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- else if eq .Values.image.flavor "wolfi" -}}
{{- printf "%s:%s" .Values.image.wolfiRepository $tag -}}
{{- else -}}
{{- fail "image.flavor must be one of: default, wolfi" -}}
{{- end -}}
{{- end -}}

{{- define "kibana.secretName" -}}
{{- if .Values.elasticsearch.auth.existingSecret -}}
{{- .Values.elasticsearch.auth.existingSecret -}}
{{- else if .Values.encryptionKeys.existingSecret -}}
{{- .Values.encryptionKeys.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "kibana.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "kibana.elasticsearchAuthSecretName" -}}
{{- if .Values.elasticsearch.auth.existingSecret -}}
{{- .Values.elasticsearch.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "kibana.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "kibana.encryptionSecretName" -}}
{{- if .Values.encryptionKeys.existingSecret -}}
{{- .Values.encryptionKeys.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "kibana.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "kibana.managedSecretNeeded" -}}
{{- $auth := .Values.elasticsearch.auth.type -}}
{{- $needsAuth := and (ne $auth "none") (not .Values.externalSecrets.enabled) (not .Values.elasticsearch.auth.existingSecret) -}}
{{- $needsKeys := and (not .Values.externalSecrets.enabled) (not .Values.encryptionKeys.existingSecret) (or .Values.encryptionKeys.securityKey .Values.encryptionKeys.reportingKey .Values.encryptionKeys.encryptedSavedObjectsKey) -}}
{{- if or $needsAuth $needsKeys -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "kibana.hasEnv" -}}
{{- $auth := ne .Values.elasticsearch.auth.type "none" -}}
{{- $keys := or .Values.encryptionKeys.existingSecret .Values.encryptionKeys.securityKey .Values.encryptionKeys.reportingKey .Values.encryptionKeys.encryptedSavedObjectsKey -}}
{{- if or $auth $keys .Values.extraEnv -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "kibana.probePath" -}}
{{- $basePath := trimSuffix "/" .Values.server.basePath -}}
{{- if $basePath -}}
{{- printf "%s/api/status" $basePath -}}
{{- else -}}
/api/status
{{- end -}}
{{- end -}}

{{- define "kibana.validate" -}}
{{- $auth := .Values.elasticsearch.auth.type -}}
{{- if not (has $auth (list "none" "basic" "serviceAccountToken")) -}}
{{- fail "elasticsearch.auth.type must be one of: none, basic, serviceAccountToken" -}}
{{- end -}}
{{- if and (eq $auth "basic") (not .Values.externalSecrets.enabled) (not .Values.elasticsearch.auth.existingSecret) (not .Values.elasticsearch.auth.password) -}}
{{- fail "elasticsearch.auth.password or elasticsearch.auth.existingSecret is required when elasticsearch.auth.type=basic" -}}
{{- end -}}
{{- if and (eq $auth "serviceAccountToken") (not .Values.externalSecrets.enabled) (not .Values.elasticsearch.auth.existingSecret) (not .Values.elasticsearch.auth.serviceAccountToken) -}}
{{- fail "elasticsearch.auth.serviceAccountToken or elasticsearch.auth.existingSecret is required when elasticsearch.auth.type=serviceAccountToken" -}}
{{- end -}}
{{- if and .Values.elasticsearch.tls.enabled (not (has .Values.elasticsearch.tls.verificationMode (list "full" "certificate" "none"))) -}}
{{- fail "elasticsearch.tls.verificationMode must be one of: full, certificate, none" -}}
{{- end -}}
{{- if and .Values.elasticsearch.tls.enabled (not .Values.elasticsearch.tls.certificateAuthoritiesSecret) -}}
{{- fail "elasticsearch.tls.certificateAuthoritiesSecret is required when elasticsearch.tls.enabled=true" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.encryptionKeys.requireForMultipleReplicas (not .Values.externalSecrets.enabled) (not .Values.encryptionKeys.existingSecret) (or (not .Values.encryptionKeys.securityKey) (not .Values.encryptionKeys.reportingKey) (not .Values.encryptionKeys.encryptedSavedObjectsKey)) -}}
{{- fail "replicaCount > 1 requires encryptionKeys.existingSecret or all static encryption key values when encryptionKeys.requireForMultipleReplicas=true" -}}
{{- end -}}
{{- if and .Values.gateway.enabled (not .Values.gateway.parentRefs) -}}
{{- fail "gateway.parentRefs is required when gateway.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.secretStoreRef.name) -}}
{{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.data) -}}
{{- fail "externalSecrets.data must not be empty when externalSecrets.enabled=true" -}}
{{- end -}}
{{- end -}}

{{- define "kibana.assertGatewayAPICRDs" -}}
{{- if and .Values.gateway.enabled (not .Values.gateway.skipCRDCheck) -}}
{{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "httproutes.gateway.networking.k8s.io" -}}
{{- if and $crd (not (hasKey $crd "metadata")) -}}
{{- fail "ERROR: Gateway API CRDs not found in cluster. Install Gateway API CRDs or set gateway.skipCRDCheck=true." -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kibana.assertExternalSecretsCRDs" -}}
{{- if and .Values.externalSecrets.enabled (not .Values.externalSecrets.skipCRDCheck) -}}
{{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "externalsecrets.external-secrets.io" -}}
{{- if and $crd (not (hasKey $crd "metadata")) -}}
{{- fail "ERROR: External Secrets Operator CRDs not found in cluster. Install ESO or set externalSecrets.skipCRDCheck=true." -}}
{{- end -}}
{{- end -}}
{{- end -}}
