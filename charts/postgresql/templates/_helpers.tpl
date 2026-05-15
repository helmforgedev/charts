{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "postgresql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "postgresql.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "postgresql.labels" -}}
helm.sh/chart: {{ include "postgresql.chart" . }}
{{ include "postgresql.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "postgresql.componentLabels" -}}
{{ include "postgresql.selectorLabels" .root }}
app.kubernetes.io/component: postgresql
app.kubernetes.io/part-of: postgresql
{{- if .role }}
app.kubernetes.io/role: {{ .role }}
{{- end }}
{{- end -}}

{{- define "postgresql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "postgresql.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else if include "postgresql.authSecretManagedByExternalSecret" . -}}
{{- default (printf "%s-auth" (include "postgresql.fullname" .)) .Values.externalSecrets.auth.targetName -}}
{{- else -}}
{{- printf "%s-auth" (include "postgresql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.configMapName" -}}
{{- printf "%s-config" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.initdbConfigMapName" -}}
{{- printf "%s-initdb" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.generatedInitdbEnabled" -}}
{{- if or .Values.initdb.runDefaultScript .Values.initdb.scripts -}}true{{- end -}}
{{- end -}}

{{- define "postgresql.initdbVolumeEnabled" -}}
{{- if or (include "postgresql.generatedInitdbEnabled" .) .Values.initdb.existingConfigMap -}}true{{- end -}}
{{- end -}}

{{- define "postgresql.postgresDbEnv" -}}
{{- if .Values.initdb.runDefaultScript -}}
{{- .Values.auth.database -}}
{{- else -}}
{{- include "postgresql.maintenanceDatabase" . -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.tlsSecretName" -}}
{{- if .Values.tls.enabled -}}
{{- if .Values.tls.existingSecret -}}
{{- .Values.tls.existingSecret -}}
{{- else if include "postgresql.tlsSecretManagedByExternalSecret" . -}}
{{- default (printf "%s-tls" (include "postgresql.fullname" .)) .Values.externalSecrets.tls.targetName -}}
{{- else -}}
{{- required "tls.existingSecret or externalSecrets.tls.enabled is required when tls.enabled=true" .Values.tls.existingSecret -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.primaryServiceName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-primary" (include "postgresql.fullname" .) -}}
{{- else -}}
{{- include "postgresql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.clientServiceName" -}}
{{- include "postgresql.fullname" . -}}
{{- end -}}

{{- define "postgresql.replicasServiceName" -}}
{{- printf "%s-replicas" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.metricsServiceName" -}}
{{- printf "%s-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryMetricsServiceName" -}}
{{- printf "%s-primary-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.replicasMetricsServiceName" -}}
{{- printf "%s-replicas-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryHeadlessServiceName" -}}
{{- printf "%s-primary-headless" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.replicasHeadlessServiceName" -}}
{{- printf "%s-replicas-headless" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryStatefulSetName" -}}
{{- if eq .Values.architecture "replication" -}}
{{- printf "%s-primary" (include "postgresql.fullname" .) -}}
{{- else -}}
{{- include "postgresql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.replicaStatefulSetName" -}}
{{- printf "%s-replicas" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.primaryPvcName" -}}
{{- printf "data-%s-0" (include "postgresql.primaryStatefulSetName" .) -}}
{{- end -}}

{{- define "postgresql.primaryPersistenceEnabled" -}}
{{- if ternary .Values.replication.primary.persistence.enabled .Values.standalone.persistence.enabled (eq .Values.architecture "replication") -}}true{{- end -}}
{{- end -}}

{{- define "postgresql.detectedPrimaryPvc" -}}
{{- if include "postgresql.primaryPersistenceEnabled" . -}}
{{- $pvc := lookup "v1" "PersistentVolumeClaim" .Release.Namespace (include "postgresql.primaryPvcName" .) -}}
{{- if $pvc -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.validatePasswordGeneration" -}}
{{- if and (not .Values.auth.existingSecret) (include "postgresql.detectedPrimaryPvc" .) (not .Values.auth.allowPasswordGenerationWithExistingData) -}}
{{- $secretName := include "postgresql.secretName" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- $hasPostgres := and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretPostgresPasswordKey) -}}
{{- $hasUser := and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretUserPasswordKey) -}}
{{- $hasReplication := and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretReplicationPasswordKey) -}}
{{- $needsPostgres := and (not .Values.auth.postgresPassword) (not $hasPostgres) -}}
{{- $needsUser := and (not .Values.auth.password) (not $hasUser) -}}
{{- $needsReplication := and (eq .Values.architecture "replication") (not .Values.auth.replicationPassword) (not $hasReplication) -}}
{{- if or $needsPostgres $needsUser $needsReplication -}}
{{- fail (printf "Refusing to auto-generate PostgreSQL passwords because existing PVC %q was detected but the managed Secret is missing one or more required password keys. Restore/reuse the existing Secret, set explicit auth passwords that match the database, or set auth.allowPasswordGenerationWithExistingData=true only for an empty/reinitialized data directory." (include "postgresql.primaryPvcName" .)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.postgresPassword" -}}
{{- $secretName := include "postgresql.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else if .Values.auth.postgresPassword -}}
{{- .Values.auth.postgresPassword -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretPostgresPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretPostgresPasswordKey | b64dec -}}
{{- else -}}
{{- include "postgresql.validatePasswordGeneration" . -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.userPassword" -}}
{{- $secretName := include "postgresql.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else if .Values.auth.password -}}
{{- .Values.auth.password -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretUserPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretUserPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.replicationPassword" -}}
{{- $secretName := include "postgresql.secretName" . -}}
{{- if .Values.auth.existingSecret -}}
{{- "" -}}
{{- else if .Values.auth.replicationPassword -}}
{{- .Values.auth.replicationPassword -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.auth.existingSecretReplicationPasswordKey) -}}
{{- index $existing.data .Values.auth.existingSecretReplicationPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.maintenanceDatabase" -}}
postgres
{{- end -}}

{{- define "postgresql.libpqEnvExports" -}}
{{- if .Values.tls.enabled }}export PGSSLMODE={{ .Values.tls.sslMode | quote }}; export PGSSLROOTCERT=/tls/{{ .Values.tls.caFilename }}; {{- end -}}
{{- end -}}

{{- define "postgresql.probeCommandString" -}}
{{- include "postgresql.libpqEnvExports" . }}PGPASSWORD="${POSTGRES_PASSWORD}" pg_isready -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d {{ include "postgresql.maintenanceDatabase" . }}
{{- end -}}

{{- define "postgresql.primaryStartupProbeCommandString" -}}
{{ include "postgresql.ensureMaintenanceDatabaseCommandString" . }}
{{- end -}}

{{- define "postgresql.primaryReadinessCommandString" -}}
{{ include "postgresql.ensureMaintenanceDatabaseCommandString" . }}
{{ if and (eq .Values.architecture "replication") .Values.replication.primary.probes.requireWritable -}}
{{- include "postgresql.libpqEnvExports" . }}PGPASSWORD="${POSTGRES_PASSWORD}" psql -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d {{ include "postgresql.maintenanceDatabase" . }} -tAc "SELECT CASE WHEN pg_is_in_recovery() THEN 1 ELSE 0 END" | grep -qx 0
{{- else -}}
{{ include "postgresql.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "postgresql.replicaReadinessCommandString" -}}
{{- if and (eq .Values.architecture "replication") .Values.replication.readReplicas.probes.requireRecoveryMode -}}
{{- include "postgresql.libpqEnvExports" . }}PGPASSWORD="${POSTGRES_PASSWORD}" psql -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d {{ include "postgresql.maintenanceDatabase" . }} -tAc "SELECT CASE WHEN pg_is_in_recovery() THEN 1 ELSE 0 END" | grep -qx 1
{{- else -}}
{{ include "postgresql.probeCommandString" . }}
{{- end -}}
{{- end -}}

{{- define "postgresql.ensureMaintenanceDatabaseCommandString" -}}
DATA_DIR="${PGDATA:-/var/lib/postgresql/data/pgdata}"
if [ ! -s "${DATA_DIR}/PG_VERSION" ]; then
  exit 1
fi
{{ include "postgresql.libpqEnvExports" . }}export PGPASSWORD="${POSTGRES_PASSWORD}"
if psql -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d template1 -tAc "SELECT 1" >/dev/null 2>&1; then
  if ! psql -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} -d template1 -tAc "SELECT 1 FROM pg_database WHERE datname = '{{ include "postgresql.maintenanceDatabase" . }}'" | grep -qx 1; then
    createdb -U postgres -h 127.0.0.1 -p {{ .Values.service.port }} {{ include "postgresql.maintenanceDatabase" . }}
  fi
else
  echo "Unable to verify or repair the {{ include "postgresql.maintenanceDatabase" . }} database on this PostgreSQL data directory." >&2
  exit 1
fi
{{- end -}}

{{- define "postgresql.metricsEnv" -}}
- name: DATA_SOURCE_URI
  value: 127.0.0.1:{{ .Values.service.port }}/{{ include "postgresql.maintenanceDatabase" . }}?sslmode={{ if .Values.tls.enabled }}{{ .Values.tls.sslMode }}{{ else }}disable{{ end }}{{ if and .Values.tls.enabled (or (eq .Values.tls.sslMode "verify-ca") (eq .Values.tls.sslMode "verify-full")) }}&sslrootcert=/tls/{{ .Values.tls.caFilename }}{{ end }}
- name: DATA_SOURCE_USER
  value: postgres
- name: DATA_SOURCE_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "postgresql.secretName" . }}
      key: {{ .Values.auth.existingSecretPostgresPasswordKey }}
{{- end -}}

{{- define "postgresql.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else if include "postgresql.backupSecretManagedByExternalSecret" . -}}
{{- default (printf "%s-backup" (include "postgresql.fullname" .)) .Values.externalSecrets.backup.targetName -}}
{{- else -}}
{{- printf "%s-backup" (include "postgresql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not (include "postgresql.backupSecretManagedByExternalSecret" .)) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "postgresql.authSecretManagedByExternalSecret" -}}
{{- $externalSecrets := .Values.externalSecrets | default dict -}}
{{- $auth := get $externalSecrets "auth" | default dict -}}
{{- if and (get $externalSecrets "enabled") (get $auth "enabled") -}}true{{- end -}}
{{- end -}}

{{- define "postgresql.tlsSecretManagedByExternalSecret" -}}
{{- $externalSecrets := .Values.externalSecrets | default dict -}}
{{- $tls := get $externalSecrets "tls" | default dict -}}
{{- if and (get $externalSecrets "enabled") (get $tls "enabled") -}}true{{- end -}}
{{- end -}}

{{- define "postgresql.backupSecretManagedByExternalSecret" -}}
{{- $externalSecrets := .Values.externalSecrets | default dict -}}
{{- $backup := get $externalSecrets "backup" | default dict -}}
{{- if and (get $externalSecrets "enabled") (get $backup "enabled") -}}true{{- end -}}
{{- end -}}

{{- define "postgresql.validateExternalSecrets" -}}
{{- $externalSecrets := .Values.externalSecrets | default dict -}}
{{- $secretStoreRef := get $externalSecrets "secretStoreRef" | default dict -}}
{{- $auth := get $externalSecrets "auth" | default dict -}}
{{- $tls := get $externalSecrets "tls" | default dict -}}
{{- $backup := get $externalSecrets "backup" | default dict -}}
{{- if get $externalSecrets "enabled" -}}
  {{- if not (get $secretStoreRef "name") -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled is true" -}}
  {{- end -}}
  {{- if get $auth "enabled" -}}
    {{- $postgresPasswordRemoteRef := get $auth "postgresPasswordRemoteRef" | default dict -}}
    {{- $userPasswordRemoteRef := get $auth "userPasswordRemoteRef" | default dict -}}
    {{- $replicationPasswordRemoteRef := get $auth "replicationPasswordRemoteRef" | default dict -}}
    {{- if not (get $postgresPasswordRemoteRef "key") -}}
      {{- fail "externalSecrets.auth.postgresPasswordRemoteRef.key is required when externalSecrets.auth.enabled is true" -}}
    {{- end -}}
    {{- if not (get $userPasswordRemoteRef "key") -}}
      {{- fail "externalSecrets.auth.userPasswordRemoteRef.key is required when externalSecrets.auth.enabled is true" -}}
    {{- end -}}
    {{- if and (eq .Values.architecture "replication") (not (get $replicationPasswordRemoteRef "key")) -}}
      {{- fail "externalSecrets.auth.replicationPasswordRemoteRef.key is required in replication mode when externalSecrets.auth.enabled is true" -}}
    {{- end -}}
  {{- end -}}
  {{- if get $tls "enabled" -}}
    {{- $certRemoteRef := get $tls "certRemoteRef" | default dict -}}
    {{- $keyRemoteRef := get $tls "keyRemoteRef" | default dict -}}
    {{- $caRemoteRef := get $tls "caRemoteRef" | default dict -}}
    {{- if not .Values.tls.enabled -}}
      {{- fail "externalSecrets.tls.enabled requires tls.enabled=true" -}}
    {{- end -}}
    {{- if not (get $certRemoteRef "key") -}}
      {{- fail "externalSecrets.tls.certRemoteRef.key is required when externalSecrets.tls.enabled is true" -}}
    {{- end -}}
    {{- if not (get $keyRemoteRef "key") -}}
      {{- fail "externalSecrets.tls.keyRemoteRef.key is required when externalSecrets.tls.enabled is true" -}}
    {{- end -}}
    {{- if not (get $caRemoteRef "key") -}}
      {{- fail "externalSecrets.tls.caRemoteRef.key is required when externalSecrets.tls.enabled is true" -}}
    {{- end -}}
  {{- end -}}
  {{- if get $backup "enabled" -}}
    {{- $accessKeyRemoteRef := get $backup "accessKeyRemoteRef" | default dict -}}
    {{- $secretKeyRemoteRef := get $backup "secretKeyRemoteRef" | default dict -}}
    {{- if not .Values.backup.enabled -}}
      {{- fail "externalSecrets.backup.enabled requires backup.enabled=true" -}}
    {{- end -}}
    {{- if not (get $accessKeyRemoteRef "key") -}}
      {{- fail "externalSecrets.backup.accessKeyRemoteRef.key is required when externalSecrets.backup.enabled is true" -}}
    {{- end -}}
    {{- if not (get $secretKeyRemoteRef "key") -}}
      {{- fail "externalSecrets.backup.secretKeyRemoteRef.key is required when externalSecrets.backup.enabled is true" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "postgresql.backupHost" -}}
{{- include "postgresql.primaryServiceName" . -}}
{{- end -}}

{{- define "postgresql.configPreset" -}}
{{- if eq .Values.config.preset "small" -}}
max_connections = 100
shared_buffers = '256MB'
effective_cache_size = '768MB'
work_mem = '4MB'
maintenance_work_mem = '64MB'
{{- else if eq .Values.config.preset "medium" -}}
max_connections = 200
shared_buffers = '512MB'
effective_cache_size = '1536MB'
work_mem = '8MB'
maintenance_work_mem = '128MB'
{{- else if eq .Values.config.preset "large" -}}
max_connections = 400
shared_buffers = '1GB'
effective_cache_size = '3GB'
work_mem = '16MB'
maintenance_work_mem = '256MB'
{{- end -}}
{{- end -}}

{{- define "postgresql.pgHbaEntries" -}}
{{- range .Values.config.pgHbaEntries }}
{{ .type | default "host" }} {{ .database | default "all" }} {{ .user | default "all" }} {{ .address | default "0.0.0.0/0" }} {{ .method | default "scram-sha-256" }}{{- if .options }} {{ .options }}{{- end }}
{{- end -}}
{{- end -}}

{{- define "postgresql.pgHbaClientCIDRRules" -}}
{{- $type := ternary "hostssl" "host" .Values.tls.enabled -}}
{{- range .Values.config.allowedClientCIDRs }}
{{ $type }} all             all             {{ . }}            scram-sha-256
{{- end -}}
{{- end -}}

{{- define "postgresql.pgHbaReplicationCIDRRules" -}}
{{- $type := ternary "hostssl" "host" .Values.tls.enabled -}}
{{- range .Values.config.allowedReplicationCIDRs }}
{{ $type }} postgres        {{ $.Values.auth.replicationUsername }}  {{ . }}    scram-sha-256
{{ $type }} replication     {{ $.Values.auth.replicationUsername }}  {{ . }}    scram-sha-256
{{- end -}}
{{- end -}}

{{- define "postgresql.tlsVolumeMountName" -}}
{{- if and .Values.tls.enabled .Values.tls.volumePermissions.enabled -}}tls-fixed{{- else -}}tls{{- end -}}
{{- end -}}

{{- define "postgresql.tlsVolume" -}}
{{- if .Values.tls.enabled }}
{{- if .Values.tls.volumePermissions.enabled }}
- name: tls-source
  secret:
    secretName: {{ include "postgresql.tlsSecretName" . }}
- name: tls-fixed
  emptyDir: {}
{{- else }}
- name: tls
  secret:
    secretName: {{ include "postgresql.tlsSecretName" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "postgresql.tlsVolumePermissionsInitContainer" -}}
{{- if and .Values.tls.enabled .Values.tls.volumePermissions.enabled }}
{{- $postgresSecurityContext := .Values.securityContext | default dict -}}
{{- $tlsRunAsUser := 999 -}}
{{- if hasKey $postgresSecurityContext "runAsUser" -}}
{{- $tlsRunAsUser = get $postgresSecurityContext "runAsUser" -}}
{{- end -}}
{{- $tlsRunAsGroup := $tlsRunAsUser -}}
{{- if hasKey $postgresSecurityContext "runAsGroup" -}}
{{- $tlsRunAsGroup = get $postgresSecurityContext "runAsGroup" -}}
{{- end -}}
- name: tls-volume-permissions
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - sh
    - -ec
    - |
      set -eu
      cp "/tls-source/{{ .Values.tls.certFilename }}" "/tls-fixed/{{ .Values.tls.certFilename }}"
      cp "/tls-source/{{ .Values.tls.keyFilename }}" "/tls-fixed/{{ .Values.tls.keyFilename }}"
      cp "/tls-source/{{ .Values.tls.caFilename }}" "/tls-fixed/{{ .Values.tls.caFilename }}"
      chown {{ $tlsRunAsUser }}:{{ $tlsRunAsGroup }} "/tls-fixed/{{ .Values.tls.certFilename }}" "/tls-fixed/{{ .Values.tls.keyFilename }}" "/tls-fixed/{{ .Values.tls.caFilename }}"
      chmod 0644 "/tls-fixed/{{ .Values.tls.certFilename }}" "/tls-fixed/{{ .Values.tls.caFilename }}"
      chmod 0600 "/tls-fixed/{{ .Values.tls.keyFilename }}"
  securityContext:
    {{- toYaml .Values.tls.volumePermissions.securityContext | nindent 4 }}
  volumeMounts:
    - name: tls-source
      mountPath: /tls-source
      readOnly: true
    - name: tls-fixed
      mountPath: /tls-fixed
{{- end }}
{{- end }}

{{- define "postgresql.resourcesPreset" -}}
{{- $preset := default "none" .preset -}}
{{- if eq $preset "small" -}}
requests:
  cpu: 250m
  memory: 512Mi
limits:
  cpu: 500m
  memory: 1Gi
{{- else if eq $preset "medium" -}}
requests:
  cpu: 500m
  memory: 1Gi
limits:
  cpu: "1"
  memory: 2Gi
{{- else if eq $preset "large" -}}
requests:
  cpu: "1"
  memory: 2Gi
limits:
  cpu: "2"
  memory: 4Gi
{{- end -}}
{{- end -}}

{{- define "postgresql.metricsResourcesPreset" -}}
{{- $preset := default "none" .Values.metrics.resourcesPreset -}}
{{- if eq $preset "small" -}}
requests:
  cpu: 25m
  memory: 64Mi
limits:
  cpu: 100m
  memory: 128Mi
{{- else if eq $preset "medium" -}}
requests:
  cpu: 50m
  memory: 128Mi
limits:
  cpu: 200m
  memory: 256Mi
{{- end -}}
{{- end -}}

{{- define "postgresql.volumeClaimTemplate" -}}
- metadata:
    name: data
    labels:
      {{- include "postgresql.selectorLabels" .root | nindent 6 }}
  spec:
    accessModes:
      {{- toYaml .persistence.accessModes | nindent 6 }}
    {{- if .persistence.storageClass }}
    storageClassName: {{ .persistence.storageClass | quote }}
    {{- end }}
    resources:
      requests:
        storage: {{ .persistence.size }}
{{- end -}}

{{- define "postgresql.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "postgresql.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- with .Values.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with .Values.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.affinity }}
affinity:
  {{- toYaml .Values.affinity | nindent 2 }}
{{- else if and (eq .Values.architecture "replication") .Values.replication.scheduling.enableDefaultPodAntiAffinity }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              {{- include "postgresql.selectorLabels" . | nindent 14 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml .Values.topologySpreadConstraints | nindent 2 }}
{{- else if and (eq .Values.architecture "replication") .Values.replication.scheduling.enableDefaultTopologySpread }}
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: {{ .Values.replication.scheduling.topologyKey | quote }}
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        {{- include "postgresql.selectorLabels" . | nindent 8 }}
{{- end }}
{{- end -}}

{{- define "postgresql.pdbEnabled" -}}
{{- if eq .Values.architecture "replication" -}}
{{- if .Values.replication.pdb.enabled -}}true{{- end -}}
{{- else -}}
{{- if .Values.pdb.enabled -}}true{{- end -}}
{{- end -}}
{{- end -}}
