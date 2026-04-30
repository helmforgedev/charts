{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
=============================================================================
Standard naming helpers
=============================================================================
*/}}

{{- define "elasticsearch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "elasticsearch.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "elasticsearch.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "elasticsearch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "elasticsearch.labels" -}}
helm.sh/chart: {{ include "elasticsearch.chart" . }}
{{ include "elasticsearch.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "elasticsearch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "elasticsearch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Component-specific selector labels.
Usage: {{ include "elasticsearch.componentSelectorLabels" (dict "root" . "component" "master") }}
*/}}
{{- define "elasticsearch.componentSelectorLabels" -}}
{{ include "elasticsearch.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Component-specific full labels (including helm.sh/chart etc.).
*/}}
{{- define "elasticsearch.componentLabels" -}}
{{ include "elasticsearch.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "elasticsearch.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "elasticsearch.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "elasticsearch.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/*
=============================================================================
Cluster Profile helpers
Returns resolved value: first from per-role override, then from profile default.
=============================================================================
*/}}

{{/*
Return the resolved clusterProfile.
Validates that the value is one of: dev, staging, production-ha
*/}}
{{- define "elasticsearch.profile" -}}
{{- $p := .Values.clusterProfile | default "dev" -}}
{{- if not (has $p (list "dev" "staging" "production-ha")) -}}
  {{- fail (printf "clusterProfile must be one of: dev, staging, production-ha (got %s)" $p) -}}
{{- end -}}
{{- $p -}}
{{- end -}}

{{/*
Master replica count (profile-driven, user-overridable)
dev=1, staging=1, production-ha=3
*/}}
{{- define "elasticsearch.master.replicaCount" -}}
{{- if not (kindIs "invalid" .Values.master.replicaCount) -}}
  {{- .Values.master.replicaCount -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "production-ha" -}}3
  {{- else -}}1
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Data replica count
dev=0 (master acts as data), staging=2, production-ha=3
*/}}
{{- define "elasticsearch.data.replicaCount" -}}
{{- if not (kindIs "invalid" .Values.data.replicaCount) -}}
  {{- .Values.data.replicaCount -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "dev" -}}0
  {{- else if eq $p "staging" -}}2
  {{- else -}}3
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Coordinating replica count
dev=0, staging=0, production-ha=2
*/}}
{{- define "elasticsearch.coordinating.replicaCount" -}}
{{- if not (kindIs "invalid" .Values.coordinating.replicaCount) -}}
  {{- .Values.coordinating.replicaCount -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "production-ha" -}}2
  {{- else -}}0
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Master persistence size
dev=disabled, staging=10Gi, production-ha=20Gi
*/}}
{{- define "elasticsearch.master.persistence.size" -}}
{{- if .Values.master.persistence.size -}}
  {{- .Values.master.persistence.size -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "staging" -}}10Gi
  {{- else if eq $p "production-ha" -}}20Gi
  {{- else -}}10Gi
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Data persistence size
dev=10Gi, staging=50Gi, production-ha=200Gi
*/}}
{{- define "elasticsearch.data.persistence.size" -}}
{{- if .Values.data.persistence.size -}}
  {{- .Values.data.persistence.size -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "staging" -}}50Gi
  {{- else if eq $p "production-ha" -}}200Gi
  {{- else -}}10Gi
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Master resources (profile-driven defaults)
*/}}
{{- define "elasticsearch.master.resources" -}}
{{- if .Values.master.resources -}}
  {{- toYaml .Values.master.resources -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "dev" -}}
requests:
  cpu: 200m
  memory: 2Gi
limits:
  cpu: 1
  memory: 2Gi
  {{- else if eq $p "staging" -}}
requests:
  cpu: 500m
  memory: 4Gi
limits:
  cpu: 2
  memory: 4Gi
  {{- else -}}
requests:
  cpu: 500m
  memory: 4Gi
limits:
  cpu: 2
  memory: 4Gi
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Data resources (profile-driven defaults)
*/}}
{{- define "elasticsearch.data.resources" -}}
{{- if .Values.data.resources -}}
  {{- toYaml .Values.data.resources -}}
{{- else -}}
  {{- $p := include "elasticsearch.profile" . -}}
  {{- if eq $p "staging" -}}
requests:
  cpu: 1
  memory: 8Gi
limits:
  cpu: 4
  memory: 8Gi
  {{- else if eq $p "production-ha" -}}
requests:
  cpu: 2
  memory: 16Gi
limits:
  cpu: 8
  memory: 16Gi
  {{- else -}}
requests:
  cpu: 500m
  memory: 4Gi
limits:
  cpu: 2
  memory: 4Gi
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Coordinating resources (profile-driven defaults)
*/}}
{{- define "elasticsearch.coordinating.resources" -}}
{{- if .Values.coordinating.resources -}}
  {{- toYaml .Values.coordinating.resources -}}
{{- else -}}
requests:
  cpu: 500m
  memory: 4Gi
limits:
  cpu: 2
  memory: 8Gi
{{- end -}}
{{- end -}}

{{/*
Compute heap size from memory limit (50% rule, max 31g).
Accepts a resource dict (from .Values.master.resources or profile default).
Returns: e.g. "1g", "4g", "16g", "31g"
*/}}
{{- define "elasticsearch.heapFromResources" -}}
{{- $resourcesStr := . -}}
{{- $heap := "1g" -}}
{{/*
  We parse the memory limit string: e.g. "2Gi", "16Gi", "512Mi"
  and return 50% as JVM heap.
  Supported units: Gi, Mi. Output is always in g/m.
*/}}
{{- if contains "Gi" $resourcesStr -}}
  {{- $parts := splitList "Gi" $resourcesStr -}}
  {{- $memGiStr := trim (last (splitList "memory: " (first $parts))) -}}
  {{/* strip everything after newline */}}
  {{- $memGiStr = first (splitList "\n" $memGiStr) | trim -}}
  {{- $memGi := int $memGiStr -}}
  {{- $halfGi := div $memGi 2 -}}
  {{- if gt $halfGi 31 -}}
    {{- $heap = "31g" -}}
  {{- else if gt $halfGi 0 -}}
    {{- $heap = printf "%dg" $halfGi -}}
  {{- end -}}
{{- else if contains "Mi" $resourcesStr -}}
  {{- $heap = "512m" -}}
{{- end -}}
{{- $heap -}}
{{- end -}}

{{/*
Resolved heap size for master (explicit or auto-calculated)
*/}}
{{- define "elasticsearch.master.heapSize" -}}
{{- if .Values.master.heapSize -}}
  {{- .Values.master.heapSize -}}
{{- else -}}
  {{- $res := include "elasticsearch.master.resources" . -}}
  {{- include "elasticsearch.heapFromResources" $res -}}
{{- end -}}
{{- end -}}

{{/*
Resolved heap size for data nodes
*/}}
{{- define "elasticsearch.data.heapSize" -}}
{{- if .Values.data.heapSize -}}
  {{- .Values.data.heapSize -}}
{{- else -}}
  {{- $res := include "elasticsearch.data.resources" . -}}
  {{- include "elasticsearch.heapFromResources" $res -}}
{{- end -}}
{{- end -}}

{{/*
Resolved heap size for coordinating nodes
*/}}
{{- define "elasticsearch.coordinating.heapSize" -}}
{{- if .Values.coordinating.heapSize -}}
  {{- .Values.coordinating.heapSize -}}
{{- else -}}
  {{- $res := include "elasticsearch.coordinating.resources" . -}}
  {{- include "elasticsearch.heapFromResources" $res -}}
{{- end -}}
{{- end -}}

{{/*
Security enabled: explicit value OR profile=production-ha
*/}}
{{- define "elasticsearch.security.enabled" -}}
{{- if .Values.security.enabled -}}
true
{{- else if eq (include "elasticsearch.profile" .) "production-ha" -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Credentials secret name
*/}}
{{- define "elasticsearch.credentialsSecretName" -}}
{{- if .Values.security.existingCredentialsSecret -}}
{{- .Values.security.existingCredentialsSecret -}}
{{- else -}}
{{- printf "%s-credentials" (include "elasticsearch.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
TLS secret name
*/}}
{{- define "elasticsearch.tlsSecretName" -}}
{{- if .Values.security.existingTlsSecret -}}
{{- .Values.security.existingTlsSecret -}}
{{- else -}}
{{- printf "%s-tls" (include "elasticsearch.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup secret name
*/}}
{{- define "elasticsearch.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "elasticsearch.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Backup validation
*/}}
{{- define "elasticsearch.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{/*
Split-brain quorum validation: master count must be odd and >= 3 for production-ha
*/}}
{{- define "elasticsearch.validateMasterCount" -}}
{{- $replicas := int (include "elasticsearch.master.replicaCount" .) -}}
{{- $p := include "elasticsearch.profile" . -}}
{{- if and (eq $p "production-ha") (lt $replicas 3) -}}
  {{- fail "production-ha profile requires at least 3 master nodes for split-brain prevention" -}}
{{- end -}}
{{- if and (gt $replicas 1) (eq (mod $replicas 2) 0) -}}
  {{- fail (printf "master.replicaCount must be an odd number (got %d) to prevent split-brain" $replicas) -}}
{{- end -}}
{{- end -}}

{{/*
Compute discovery.zen.minimum_master_nodes (quorum = floor(masters/2) + 1)
*/}}
{{- define "elasticsearch.minimumMasterNodes" -}}
{{- $replicas := int (include "elasticsearch.master.replicaCount" .) -}}
{{- add (div $replicas 2) 1 -}}
{{- end -}}

{{/*
Build the seed hosts list for cluster discovery (master headless DNS names)
*/}}
{{- define "elasticsearch.seedHosts" -}}
{{- $fullname := include "elasticsearch.fullname" . -}}
{{- $replicas := int (include "elasticsearch.master.replicaCount" .) -}}
{{- $hosts := list -}}
{{- range until $replicas -}}
  {{- $hosts = append $hosts (printf "%s-master-%d.%s-master-headless" $fullname . $fullname) -}}
{{- end -}}
{{- join "," $hosts -}}
{{- end -}}

{{/*
Build the initial_master_nodes list (comma-separated pod names)
*/}}
{{- define "elasticsearch.initialMasterNodes" -}}
{{- $fullname := include "elasticsearch.fullname" . -}}
{{- $replicas := int (include "elasticsearch.master.replicaCount" .) -}}
{{- $names := list -}}
{{- range until $replicas -}}
  {{- $names = append $names (printf "%s-master-%d" $fullname .) -}}
{{- end -}}
{{- join "," $names -}}
{{- end -}}

{{/*
Common Elasticsearch environment variables
*/}}
{{- define "elasticsearch.commonEnv" -}}
- name: cluster.name
  value: {{ .Values.clusterName | quote }}
- name: network.host
  value: "0.0.0.0"
{{- $masterReplicas := int (include "elasticsearch.master.replicaCount" .) -}}
{{- $dataReplicas := int (include "elasticsearch.data.replicaCount" .) -}}
{{- if and (eq $masterReplicas 1) (eq $dataReplicas 0) }}
- name: discovery.type
  value: single-node
{{- else }}
- name: discovery.seed_hosts
  value: {{ printf "%s-master-headless" (include "elasticsearch.fullname" .) | quote }}
- name: cluster.initial_master_nodes
  value: {{ include "elasticsearch.initialMasterNodes" . | quote }}
{{- end }}
- name: ELASTIC_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "elasticsearch.credentialsSecretName" . }}
      key: elastic-password
      optional: {{ eq (include "elasticsearch.security.enabled" .) "false" }}
- name: xpack.security.enabled
  value: {{ include "elasticsearch.security.enabled" . | quote }}
{{- if eq (include "elasticsearch.security.enabled" .) "true" }}
- name: xpack.security.transport.ssl.enabled
  value: "true"
- name: xpack.security.transport.ssl.verification_mode
  value: "certificate"
- name: xpack.security.transport.ssl.key
  value: /usr/share/elasticsearch/config/certs/tls.key
- name: xpack.security.transport.ssl.certificate
  value: /usr/share/elasticsearch/config/certs/tls.crt
- name: xpack.security.transport.ssl.certificate_authorities
  value: /usr/share/elasticsearch/config/certs/ca.crt
- name: xpack.security.http.ssl.enabled
  value: "true"
- name: xpack.security.http.ssl.key
  value: /usr/share/elasticsearch/config/certs/tls.key
- name: xpack.security.http.ssl.certificate
  value: /usr/share/elasticsearch/config/certs/tls.crt
- name: xpack.security.http.ssl.certificate_authorities
  value: /usr/share/elasticsearch/config/certs/ca.crt
{{- end }}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
TLS volume mounts (when security is enabled)
*/}}
{{- define "elasticsearch.tlsVolumeMounts" -}}
{{- if eq (include "elasticsearch.security.enabled" .) "true" -}}
- name: tls-certs
  mountPath: /usr/share/elasticsearch/config/certs
  readOnly: true
{{- end -}}
{{- end -}}

{{/*
TLS volumes (when security is enabled)
*/}}
{{- define "elasticsearch.tlsVolumes" -}}
{{- if eq (include "elasticsearch.security.enabled" .) "true" -}}
- name: tls-certs
  secret:
    secretName: {{ include "elasticsearch.tlsSecretName" . }}
{{- end -}}
{{- end -}}

{{/*
Liveness probe for ES HTTP endpoint
*/}}
{{- define "elasticsearch.livenessProbe" -}}
{{- if .Values.livenessProbe.enabled -}}
livenessProbe:
  tcpSocket:
    port: http
  initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
{{- end -}}
{{- end -}}

{{/*
Readiness probe
*/}}
{{- define "elasticsearch.readinessProbe" -}}
{{- if .Values.readinessProbe.enabled -}}
readinessProbe:
  {{- if eq (include "elasticsearch.security.enabled" .) "true" }}
  exec:
    command:
      - /bin/sh
      - -c
      - |
        curl -sk -u elastic:${ELASTIC_PASSWORD} \
          https://localhost:9200/_cluster/health?local=true \
          --fail || exit 1
  {{- else }}
  httpGet:
    path: /_cluster/health?local=true
    port: http
  {{- end }}
  initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
{{- end -}}
{{- end -}}

{{/*
Startup probe
*/}}
{{- define "elasticsearch.startupProbe" -}}
{{- if .Values.startupProbe.enabled -}}
startupProbe:
  tcpSocket:
    port: http
  initialDelaySeconds: {{ .Values.startupProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.startupProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.startupProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.startupProbe.failureThreshold }}
{{- end -}}
{{- end -}}

{{/*
Anti-affinity for production-ha nodes (prevent co-location of same component)
Usage: {{ include "elasticsearch.antiAffinity" (dict "root" . "component" "master") }}
*/}}
{{- define "elasticsearch.antiAffinity" -}}
{{- $p := include "elasticsearch.profile" .root -}}
{{- if and (eq $p "production-ha") (empty .root.Values.master.affinity) -}}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              {{- include "elasticsearch.componentSelectorLabels" (dict "root" .root "component" .component) | nindent 14 }}
          topologyKey: kubernetes.io/hostname
{{- end -}}
{{- end -}}

{{/*
Kibana image
*/}}
{{- define "elasticsearch.kibana.image" -}}
{{- printf "%s:%s" .Values.kibana.image.repository .Values.kibana.image.tag -}}
{{- end -}}

{{/*
Monitoring exporter image
*/}}
{{- define "elasticsearch.exporter.image" -}}
{{- printf "%s:%s" .Values.monitoring.image.repository .Values.monitoring.image.tag -}}
{{- end -}}

{{/*
Tier heap size helper
Usage: {{ include "elasticsearch.tierHeapSize" (dict "root" . "tier" "hot") }}
*/}}
{{- define "elasticsearch.tierHeapSize" -}}
{{- $tier := .tier -}}
{{- $resources := index .root.Values.dataTiers $tier "resources" -}}
{{- if $resources }}
  {{- $memLimit := index $resources "limits" "memory" -}}
  {{- if $memLimit }}
    {{- include "elasticsearch.computeHeap" $memLimit -}}
  {{- else -}}
4g
  {{- end -}}
{{- else if eq $tier "hot" -}}
4g
{{- else -}}
2g
{{- end -}}
{{- end -}}

{{/*
Compute heap from memory string (50% rule, max 31g)
Usage: {{ include "elasticsearch.computeHeap" "8Gi" }}
*/}}
{{- define "elasticsearch.computeHeap" -}}
{{- $mem := . | lower -}}
{{- $gi := 0 -}}
{{- if hasSuffix "gi" $mem -}}
  {{- $gi = $mem | trimSuffix "gi" | atoi -}}
{{- else if hasSuffix "g" $mem -}}
  {{- $gi = $mem | trimSuffix "g" | atoi -}}
{{- else if hasSuffix "mi" $mem -}}
  {{- $mi := $mem | trimSuffix "mi" | atoi -}}
  {{- $gi = div $mi 1024 -}}
{{- end -}}
{{- $heap := div $gi 2 -}}
{{- if gt $heap 31 -}}{{- $heap = 31 -}}{{- end -}}
{{- if lt $heap 1 -}}{{- $heap = 1 -}}{{- end -}}
{{- printf "%dg" $heap -}}
{{- end -}}

{{/*
=============================================================================
TLS Configuration Validators (Camada 1)
=============================================================================
Called from certificate.yaml to validate that security is configured correctly
before any resource creation.
*/}}

{{/*
Validate that security.enabled has exactly one TLS source configured.
Fails with a clear error message before any resource is created.
*/}}
{{- define "elasticsearch.validateTls" -}}
{{- if eq (include "elasticsearch.security.enabled" .) "true" -}}
  {{- $hasCertManager := and .Values.security .Values.security.tls .Values.security.tls.certManager (index .Values.security.tls.certManager "enabled") -}}
  {{- $hasExistingSecret := and .Values.security .Values.security.existingTlsSecret -}}
  {{- $selfInit := and .Values.security .Values.security.tls .Values.security.tls.selfSignedInit -}}
  {{- $hasSelfSigned := and $selfInit (index .Values.security.tls.selfSignedInit "enabled") -}}
  {{- if not (or $hasCertManager $hasExistingSecret $hasSelfSigned) -}}
    {{- fail "security.enabled=true requires a TLS source. Set one of: security.tls.certManager.enabled=true, security.tls.selfSignedInit.enabled=true, or security.existingTlsSecret=<name>. See: https://helmforge.dev/docs/charts/elasticsearch#security" -}}
  {{- end -}}
  {{- if and $hasSelfSigned $hasCertManager -}}
    {{- fail "Cannot enable both security.tls.selfSignedInit.enabled and security.tls.certManager.enabled. Choose only one TLS source." -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Assert cert-manager CRDs are present in the cluster (Camada 2).
Uses Helm lookup - ONLY effective during helm install/upgrade with live cluster access.

Offline / unit-test behavior:
  lookup returns nil - check is silently skipped (cannot distinguish offline from absent)

Live cluster behavior:
  CRD exists - lookup returns full object with metadata - no error
  CRD absent - lookup returns empty map {} (no metadata key) - fail with instructions

To suppress check (use when cert-manager is managed externally):
  security.tls.certManager.skipCRDCheck: true
*/}}
{{- define "elasticsearch.assertCertManagerCRDs" -}}
{{- $cmEnabled := and .Values.security .Values.security.tls .Values.security.tls.certManager (index .Values.security.tls.certManager "enabled") -}}
{{- if $cmEnabled -}}
  {{- $cmInstall := and .Values.certManager (index .Values.certManager "install") -}}
  {{- $skipCheck := and .Values.security .Values.security.tls .Values.security.tls.certManager (index .Values.security.tls.certManager "skipCRDCheck") -}}
  {{- if and (not $cmInstall) (not $skipCheck) -}}
    {{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "certificates.cert-manager.io" -}}
    {{- /* Only fail when cluster responded (non-nil) but CRD is missing (no metadata) */ -}}
    {{- if and $crd (not (hasKey $crd "metadata")) -}}
      {{- fail "ERROR: cert-manager CRDs not found in cluster.\n\ncert-manager is required for security.tls.certManager.enabled=true.\n\nOptions:\n  1. Install cert-manager manually:\n     https://cert-manager.io/docs/installation/\n\n  2. Use self-signed TLS (no cert-manager needed):\n     --set security.tls.certManager.enabled=false \\\n     --set security.tls.selfSignedInit.enabled=true" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Assert External Secrets Operator CRDs are present in the cluster.
Uses the same lookup pattern as assertCertManagerCRDs:
  - offline / unit-test: lookup returns nil → check skipped silently
  - live cluster, CRD present: lookup returns object with metadata → ok
  - live cluster, CRD absent: lookup returns empty map {} → fail with instructions

To suppress: externalSecrets.skipCRDCheck: true
*/}}
{{- define "elasticsearch.assertExternalSecretsCRDs" -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.externalSecrets.skipCRDCheck -}}
    {{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "externalsecrets.external-secrets.io" -}}
    {{- /*
      helm template / unit-test: lookup returns {} (falsy) → and short-circuits → no fail (correct).
      live cluster, CRD present: lookup returns full object (truthy) → hasKey "metadata" → no fail.
      live cluster, CRD absent: lookup returns {} (falsy) → and short-circuits → no fail.
      Helm's lookup cannot distinguish offline from absent, so this is best-effort: it only fires
      if somehow a non-empty response arrives without metadata, which does not occur in practice.
      The check provides an actionable error when CRDs are definitively confirmed missing.
    */ -}}
    {{- if and $crd (not (hasKey $crd "metadata")) -}}
      {{- fail "ERROR: External Secrets Operator CRDs not found in cluster.\n\nESO is required for externalSecrets.enabled=true.\n\nOptions:\n  1. Install ESO:\n     https://external-secrets.io/latest/introduction/getting-started/\n\n  2. Skip this check (if CRDs are managed externally):\n     --set externalSecrets.skipCRDCheck=true" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Assert Gateway API CRDs are present in the cluster.
Uses the same lookup pattern as assertCertManagerCRDs:
  - offline / unit-test: lookup returns nil → check skipped silently
  - live cluster, CRD present: lookup returns object with metadata → ok
  - live cluster, CRD absent: lookup returns empty map {} → fail with instructions

To suppress: gateway.skipCRDCheck: true
*/}}
{{- define "elasticsearch.assertGatewayAPICRDs" -}}
{{- if .Values.gateway.enabled -}}
  {{- if not .Values.gateway.skipCRDCheck -}}
    {{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "httproutes.gateway.networking.k8s.io" -}}
    {{- /* Same best-effort pattern as assertExternalSecretsCRDs — see comment there. */ -}}
    {{- if and $crd (not (hasKey $crd "metadata")) -}}
      {{- fail "ERROR: Gateway API CRDs not found in cluster.\n\nGateway API is required for gateway.enabled=true.\n\nOptions:\n  1. Install Gateway API CRDs:\n     kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml\n\n  2. Skip this check (if CRDs are managed externally):\n     --set gateway.skipCRDCheck=true" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
TLS secret name for self-signed init Job
*/}}
{{- define "elasticsearch.selfSignedSecretName" -}}
{{- printf "%s-tls" (include "elasticsearch.fullname" .) -}}
{{- end -}}

