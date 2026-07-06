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

{{/*
Service name of the bundled Elasticsearch subchart. Mirrors the subchart's own
`elasticsearch.fullname` (charts/elasticsearch/templates/_helpers.tpl) against the
aliased `bundled-elasticsearch` values so Kibana resolves the SAME Service the
subchart renders -- including long release-name truncation (trunc 63) and any
`nameOverride`/`fullnameOverride` set on the subchart. The dependency alias is
`bundled-elasticsearch`, so the subchart's default name is that alias.
*/}}
{{- define "kibana.bundledElasticsearchFullname" -}}
{{- $es := index .Values "bundled-elasticsearch" | default dict -}}
{{- if $es.fullnameOverride -}}
{{- $es.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "bundled-elasticsearch" $es.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Whether the bundled Elasticsearch subchart runs with security enabled. Mirrors
the subchart's `elasticsearch.security.enabled` (explicit `security.enabled` OR
`clusterProfile=production-ha`). In that mode the subchart serves HTTPS on 9200
with self-signed TLS and auth -- which bundled mode here does NOT wire (it only
points Kibana at the plain-HTTP Service URL). validate() rejects that combo.
*/}}
{{- define "kibana.bundledElasticsearchSecured" -}}
{{- $es := index .Values "bundled-elasticsearch" | default dict -}}
{{- $sec := $es.security | default dict -}}
{{- if or $sec.enabled (eq ($es.clusterProfile | default "dev") "production-ha") -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
Effective Elasticsearch hosts. When the bundled Elasticsearch subchart is
enabled, point Kibana at its in-cluster Service (derived to match the subchart's
fullname) so the chart is self-sufficient with ANY release name or subchart name
override. Otherwise use the configured external `elasticsearch.hosts`.
*/}}
{{- define "kibana.elasticsearchHosts" -}}
{{- if .Values.bundledElasticsearch.enabled -}}
{{- list (printf "http://%s:9200" (include "kibana.bundledElasticsearchFullname" .)) | toYaml -}}
{{- else -}}
{{- .Values.elasticsearch.hosts | toYaml -}}
{{- end -}}
{{- end -}}

{{- define "kibana.elasticsearchFirstHost" -}}
{{- if .Values.bundledElasticsearch.enabled -}}
{{- printf "http://%s:9200" (include "kibana.bundledElasticsearchFullname" .) -}}
{{- else -}}
{{- .Values.elasticsearch.hosts | first -}}
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

{{- define "kibana.waitForElasticsearchEnabled" -}}
{{- $externalPlainHTTP := and (not .Values.bundledElasticsearch.enabled) (eq .Values.elasticsearch.auth.type "none") (not .Values.elasticsearch.tls.enabled) -}}
{{- if and .Values.waitForElasticsearch.enabled (or .Values.bundledElasticsearch.enabled $externalPlainHTTP) -}}true{{- else -}}false{{- end -}}
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
{{- if and .Values.bundledElasticsearch.enabled (eq (include "kibana.bundledElasticsearchSecured" .) "true") -}}
{{- fail "bundled Elasticsearch with security enabled (bundled-elasticsearch.security.enabled=true or clusterProfile=production-ha) is not supported in bundled mode: this chart wires only the plain-HTTP Service URL, not TLS CA verification or auth, so Kibana would connect to the wrong (https) endpoint. Use external mode instead -- set bundledElasticsearch.enabled=false and configure elasticsearch.hosts + elasticsearch.tls + elasticsearch.auth against your secured cluster." -}}
{{- end -}}
{{- if and .Values.bundledElasticsearch.enabled (ne $auth "none") -}}
{{- fail "elasticsearch.auth.type must be none when bundledElasticsearch.enabled=true because the bundled dev profile is unauthenticated plain HTTP. Disable bundledElasticsearch to use external secured Elasticsearch." -}}
{{- end -}}
{{- if and .Values.bundledElasticsearch.enabled .Values.elasticsearch.tls.enabled -}}
{{- fail "elasticsearch.tls.enabled must be false when bundledElasticsearch.enabled=true because the bundled dev profile is plain HTTP. Disable bundledElasticsearch to use external TLS Elasticsearch." -}}
{{- end -}}
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
{{- $externalSecretData := .Values.externalSecrets.data | default list -}}
{{- $externalSecretDataFrom := .Values.externalSecrets.dataFrom | default list -}}
{{- if and .Values.externalSecrets.enabled (eq (add (len $externalSecretData) (len $externalSecretDataFrom)) 0) -}}
{{- fail "externalSecrets.data or externalSecrets.dataFrom must not be empty when externalSecrets.enabled=true" -}}
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
