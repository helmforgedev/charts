{{- define "keycloak.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "keycloak.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "keycloak.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "keycloak.labels" -}}
helm.sh/chart: {{ include "keycloak.chart" . }}
{{ include "keycloak.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "keycloak.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keycloak.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "keycloak.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "keycloak.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.isProduction" -}}
{{- if eq .Values.mode "production" -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.validateAll" -}}
{{- $mode := .Values.mode | default "dev" -}}
{{- if not (has $mode (list "dev" "production")) -}}
  {{- fail "mode must be one of: dev, production" -}}
{{- end -}}
{{- $databaseMode := include "keycloak.databaseMode" . -}}
{{- if and (eq $mode "dev") (gt (int .Values.replicaCount) 1) -}}
  {{- fail "mode=dev does not support replicaCount > 1; use mode=production with a real database for multi-replica deployments" -}}
{{- end -}}
{{- if eq $mode "production" -}}
  {{- if not .Values.hostname.hostname -}}
    {{- fail "hostname.hostname is required in production mode" -}}
  {{- end -}}
  {{- if eq $databaseMode "embedded" -}}
    {{- fail "production mode requires a database: set postgresql.enabled, mysql.enabled, or database.external.host" -}}
  {{- end -}}
  {{- if and .Values.ingress.admin.enabled (not .Values.hostname.admin) -}}
    {{- fail "hostname.admin is required when ingress.admin.enabled is true in production mode" -}}
  {{- end -}}
  {{- if and .Values.gateway.admin.enabled (not .Values.hostname.admin) (not .Values.gateway.admin.hostnames) -}}
    {{- fail "hostname.admin or gateway.admin.hostnames is required when gateway.admin.enabled is true in production mode" -}}
  {{- end -}}
  {{- if and (gt (int .Values.replicaCount) 1) (not .Values.cache.enabled) -}}
    {{- fail "production multi-replica deployments require cache.enabled=true" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.proxy.trustedAddresses (not .Values.proxy.headers) -}}
  {{- fail "proxy.trustedAddresses requires proxy.headers to be set" -}}
{{- end -}}
{{- if and .Values.proxy.protocolEnabled .Values.proxy.headers -}}
  {{- fail "proxy.protocolEnabled cannot be used together with proxy.headers; set proxy.headers to an empty string" -}}
{{- end -}}
{{- if and .Values.optimized.enabled (ne $mode "production") -}}
  {{- fail "optimized.enabled requires mode=production" -}}
{{- end -}}
{{- range $feature := .Values.features.enabled -}}
  {{- if has $feature $.Values.features.disabled -}}
    {{- fail (printf "feature %s cannot be present in both features.enabled and features.disabled" $feature) -}}
  {{- end -}}
{{- end -}}
{{- $strategyType := .Values.deployment.strategy.type | default "RollingUpdate" -}}
{{- if not (has $strategyType (list "RollingUpdate" "Recreate")) -}}
  {{- fail "deployment.strategy.type must be one of: RollingUpdate, Recreate" -}}
{{- end -}}
{{- $capacityProfile := .Values.capacity.profile | default "custom" -}}
{{- if not (has $capacityProfile (list "custom" "small" "medium" "large")) -}}
  {{- fail "capacity.profile must be one of: custom, small, medium, large" -}}
{{- end -}}
{{- if and (ne $capacityProfile "custom") .Values.resources -}}
  {{- fail "capacity.profile cannot be used together with explicit resources; set capacity.profile=custom or remove resources" -}}
{{- end -}}
{{- if and .Values.management.relativePath (not (hasPrefix "/" .Values.management.relativePath)) -}}
  {{- fail "management.relativePath must start with / when set" -}}
{{- end -}}
{{- if and .Values.telemetry.metricsEnabled (not .Values.metrics.enabled) -}}
  {{- fail "telemetry.metricsEnabled requires metrics.enabled=true" -}}
{{- end -}}
{{- if and .Values.metrics.userEvents (not .Values.metrics.enabled) -}}
  {{- fail "metrics.userEvents requires metrics.enabled=true" -}}
{{- end -}}
{{- if and .Values.metrics.cacheHistograms (not .Values.metrics.enabled) -}}
  {{- fail "metrics.cacheHistograms requires metrics.enabled=true" -}}
{{- end -}}
{{- if .Values.database.tls.trustStorePasswordSecret -}}
  {{- if not .Values.database.tls.trustStoreFile -}}
    {{- fail "database.tls.trustStorePasswordSecret requires database.tls.trustStoreFile" -}}
  {{- end -}}
{{- end -}}
{{- with .Values.database.external.pool -}}
  {{- if and .minSize .initialSize (gt (int .minSize) (int .initialSize)) -}}
    {{- fail "database.external.pool.minSize must be lower than or equal to initialSize" -}}
  {{- end -}}
  {{- if and .initialSize .maxSize (gt (int .initialSize) (int .maxSize)) -}}
    {{- fail "database.external.pool.initialSize must be lower than or equal to maxSize" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.gateway.public.enabled -}}
  {{- if not .Values.gateway.public.parentRefs -}}
    {{- fail "gateway.public.parentRefs is required when gateway.public.enabled is true" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.gateway.admin.enabled -}}
  {{- if not .Values.gateway.admin.parentRefs -}}
    {{- fail "gateway.admin.parentRefs is required when gateway.admin.enabled is true" -}}
  {{- end -}}
{{- end -}}
{{- if .Values.externalSecrets.enabled -}}
  {{- if not .Values.externalSecrets.secretStoreRef.name -}}
    {{- fail "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled is true" -}}
  {{- end -}}
  {{- if .Values.externalSecrets.admin.enabled -}}
    {{- if not .Values.externalSecrets.admin.usernameRemoteRef.key -}}
      {{- fail "externalSecrets.admin.usernameRemoteRef.key is required when externalSecrets.admin.enabled is true" -}}
    {{- end -}}
    {{- if not .Values.externalSecrets.admin.passwordRemoteRef.key -}}
      {{- fail "externalSecrets.admin.passwordRemoteRef.key is required when externalSecrets.admin.enabled is true" -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.externalSecrets.database.enabled -}}
    {{- if not (include "keycloak.hasDatabase" .) -}}
      {{- fail "externalSecrets.database.enabled requires a configured database" -}}
    {{- end -}}
    {{- if not .Values.externalSecrets.database.passwordRemoteRef.key -}}
      {{- fail "externalSecrets.database.passwordRemoteRef.key is required when externalSecrets.database.enabled is true" -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.externalSecrets.truststore.enabled -}}
    {{- if not .Values.truststore.enabled -}}
      {{- fail "externalSecrets.truststore.enabled requires truststore.enabled=true" -}}
    {{- end -}}
    {{- if and (not .Values.externalSecrets.truststore.targetName) (not .Values.truststore.existingSecret) -}}
      {{- fail "externalSecrets.truststore.targetName or truststore.existingSecret is required when externalSecrets.truststore.enabled is true" -}}
    {{- end -}}
    {{- if not .Values.externalSecrets.truststore.data -}}
      {{- fail "externalSecrets.truststore.data is required when externalSecrets.truststore.enabled is true" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.pdb.enabled .Values.pdb.minAvailable (ge (int .Values.pdb.minAvailable) (int .Values.replicaCount)) -}}
  {{- fail "pdb.minAvailable must be lower than replicaCount to avoid blocking voluntary disruptions" -}}
{{- end -}}
{{- if .Values.backup.enabled -}}
  {{- $_ := include "keycloak.backupEnabled" . -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.admin.enabled .Values.externalSecrets.admin.targetName -}}
{{- .Values.externalSecrets.admin.targetName -}}
{{- else -}}
{{- printf "%s-admin" (include "keycloak.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.adminSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.admin.enabled -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.databaseMode" -}}
{{- $hasExternal := or (ne (.Values.database.external.host | default "") "") (ne (.Values.database.external.existingSecret | default "") "") -}}
{{- $hasPostgresql := .Values.postgresql.enabled | default false -}}
{{- $hasMysql := .Values.mysql.enabled | default false -}}
{{- $count := 0 -}}
{{- if $hasExternal -}}{{- $count = add1 $count -}}{{- end -}}
{{- if $hasPostgresql -}}{{- $count = add1 $count -}}{{- end -}}
{{- if $hasMysql -}}{{- $count = add1 $count -}}{{- end -}}
{{- if gt $count 1 -}}
  {{- fail "keycloak database selection is ambiguous: configure only one of database.external.host, postgresql.enabled, or mysql.enabled" -}}
{{- end -}}
{{- if $hasExternal -}}external
{{- else if $hasPostgresql -}}postgresql
{{- else if $hasMysql -}}mysql
{{- else -}}embedded
{{- end -}}
{{- end -}}

{{- define "keycloak.hasDatabase" -}}
{{- if ne (include "keycloak.databaseMode" .) "embedded" -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.databaseVendor" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.vendor | default "postgres" -}}
{{- else if eq $mode "postgresql" -}}
postgres
{{- else if eq $mode "mysql" -}}
mysql
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databaseHost" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.host -}}
{{- else if eq $mode "postgresql" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if eq $mode "mysql" -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databasePort" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if eq $mode "external" -}}
  {{- if .Values.database.external.port -}}
    {{- .Values.database.external.port | toString -}}
  {{- else -}}
    {{- $vendor := .Values.database.external.vendor | default "postgres" -}}
    {{- if eq $vendor "postgres" -}}5432{{- else -}}3306{{- end -}}
  {{- end -}}
{{- else if eq $mode "postgresql" -}}
5432
{{- else if eq $mode "mysql" -}}
3306
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databaseName" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.name -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.database -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.database -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databaseUsername" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.username -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.username -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.username -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databasePasswordValue" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if eq $mode "external" -}}
{{- .Values.database.external.password -}}
{{- else if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.password -}}
{{- else if eq $mode "mysql" -}}
{{- .Values.mysql.auth.password -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databaseSecretName" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecret -}}
{{- else if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled .Values.externalSecrets.database.targetName -}}
{{- .Values.externalSecrets.database.targetName -}}
{{- else -}}
{{- printf "%s-db" (include "keycloak.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databaseSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.database.enabled -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.databaseSecretPasswordKey" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{- define "keycloak.databasePassword" -}}
{{- $mode := include "keycloak.databaseMode" . -}}
{{- if and (eq $mode "external") .Values.database.external.existingSecret -}}
{{- "" -}}
{{- else -}}
  {{- $password := include "keycloak.databasePasswordValue" . -}}
  {{- if $password -}}
    {{- $password -}}
  {{- else -}}
    {{- $secretName := include "keycloak.databaseSecretName" . -}}
    {{- $secretKey := include "keycloak.databaseSecretPasswordKey" . -}}
    {{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
    {{- if and $existing $existing.data (hasKey $existing.data $secretKey) -}}
      {{- index $existing.data $secretKey | b64dec -}}
    {{- else -}}
      {{- randAlphaNum 32 -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.realmImportConfigMapName" -}}
{{- printf "%s-realm-import" (include "keycloak.fullname" .) -}}
{{- end -}}

{{- define "keycloak.adminPassword" -}}
{{- $secretName := include "keycloak.adminSecretName" . -}}
{{- if .Values.admin.existingSecret -}}
{{- "" -}}
{{- else if .Values.admin.password -}}
{{- .Values.admin.password -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.admin.existingSecretPasswordKey) -}}
{{- index $existing.data .Values.admin.existingSecretPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.databaseUrl" -}}
{{- $vendor := include "keycloak.databaseVendor" . -}}
{{- $host := include "keycloak.databaseHost" . -}}
{{- $port := include "keycloak.databasePort" . -}}
{{- $name := include "keycloak.databaseName" . -}}
{{- $params := list -}}
{{- if and (eq (include "keycloak.databaseMode" .) "external") .Values.database.external.jdbcParameters -}}
{{- $params = append $params .Values.database.external.jdbcParameters -}}
{{- end -}}
{{- if and .Values.database.tls.enabled (eq $vendor "postgres") -}}
{{- $params = append $params (printf "sslmode=%s" .Values.database.tls.sslMode) -}}
{{- if or .Values.database.tls.existingSecret .Values.database.tls.existingConfigMap -}}
{{- $params = append $params (printf "sslrootcert=%s" (include "keycloak.databaseTlsRootCertPath" .)) -}}
{{- end -}}
{{- end -}}
{{- if eq $vendor "postgres" -}}
jdbc:postgresql://{{ $host }}:{{ $port }}/{{ $name }}
{{- else if or (eq $vendor "mysql") (eq $vendor "mariadb") -}}
jdbc:{{ $vendor }}://{{ $host }}:{{ $port }}/{{ $name }}
{{- else -}}
{{- fail "database vendor must be one of: postgres, mysql, mariadb" -}}
{{- end -}}
{{- if gt (len $params) 0 }}?{{ join "&" $params }}{{- end -}}
{{- end -}}

{{- define "keycloak.databaseTlsRootCertPath" -}}
{{- printf "%s/%s" .Values.database.tls.mountPath .Values.database.tls.rootCertFilename -}}
{{- end -}}

{{- define "keycloak.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret -}}
{{- .Values.backup.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-backup" (include "keycloak.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.backupDatabaseVendor" -}}
{{- $vendor := include "keycloak.databaseVendor" . -}}
{{- if or (eq $vendor "mysql") (eq $vendor "mariadb") -}}
mysql
{{- else -}}
{{- $vendor -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.backupEnabled" -}}
{{- if .Values.backup.enabled -}}
  {{- if not (include "keycloak.hasDatabase" .) -}}
    {{- fail "backup.enabled requires a real database; embedded H2 is not supported for backups" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.endpoint -}}
    {{- fail "backup.s3.endpoint is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.backup.s3.bucket -}}
    {{- fail "backup.s3.bucket is required when backup.enabled is true" -}}
  {{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (or (not .Values.backup.s3.accessKey) (not .Values.backup.s3.secretKey)) -}}
    {{- fail "backup requires either backup.s3.existingSecret or both backup.s3.accessKey and backup.s3.secretKey" -}}
  {{- end -}}
true
{{- end -}}
{{- end -}}

{{- define "keycloak.hasDatabaseTlsVolume" -}}
{{- if and .Values.database.tls.enabled (or .Values.database.tls.existingSecret .Values.database.tls.existingConfigMap) -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.hasTruststoreVolume" -}}
{{- if and .Values.truststore.enabled (or .Values.truststore.existingSecret .Values.truststore.existingConfigMap (include "keycloak.truststoreSecretManagedByExternalSecret" .)) -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.truststoreSecretName" -}}
{{- if .Values.truststore.existingSecret -}}
{{- .Values.truststore.existingSecret -}}
{{- else if .Values.externalSecrets.truststore.targetName -}}
{{- .Values.externalSecrets.truststore.targetName -}}
{{- else -}}
{{- printf "%s-truststore" (include "keycloak.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.truststoreSecretManagedByExternalSecret" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.truststore.enabled -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.startCommand" -}}
{{- if eq .Values.mode "dev" -}}start-dev{{- else -}}start{{- end -}}
{{- end -}}

{{- define "keycloak.relativePath" -}}
{{- if eq .Values.http.relativePath "/" -}}/{{- else -}}{{ trimSuffix "/" .Values.http.relativePath }}{{- end -}}
{{- end -}}

{{- define "keycloak.commandArgs" -}}
- {{ include "keycloak.startCommand" . }}
{{- if .Values.optimized.enabled }}
- --optimized
{{- end }}
{{- if .Values.realmImport.enabled }}
- --import-realm
{{- end }}
{{- end -}}

{{- define "keycloak.managementRelativePath" -}}
{{- if not .Values.management.relativePath -}}
{{- "" -}}
{{- else if eq .Values.management.relativePath "/" -}}
{{- "" -}}
{{- else -}}
{{- trimSuffix "/" .Values.management.relativePath -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.managementEndpointPath" -}}
{{- $base := include "keycloak.managementRelativePath" .root -}}
{{- if $base -}}{{ printf "%s%s" $base .path }}{{- else -}}{{ .path }}{{- end -}}
{{- end -}}

{{- define "keycloak.httpEnv" -}}
- name: KC_HTTP_ENABLED
  value: {{ ternary "true" "false" .Values.http.enabled | quote }}
- name: KC_HTTP_PORT
  value: {{ .Values.http.port | quote }}
- name: KC_HTTP_MANAGEMENT_PORT
  value: {{ .Values.http.managementPort | quote }}
- name: KC_HTTP_RELATIVE_PATH
  value: {{ include "keycloak.relativePath" . | quote }}
{{- if .Values.management.healthEnabled }}
- name: KC_HTTP_MANAGEMENT_HEALTH_ENABLED
  value: "true"
{{- else }}
- name: KC_HTTP_MANAGEMENT_HEALTH_ENABLED
  value: "false"
{{- end }}
{{- if .Values.management.relativePath }}
- name: KC_HTTP_MANAGEMENT_RELATIVE_PATH
  value: {{ .Values.management.relativePath | quote }}
{{- end }}
{{- if include "keycloak.isProduction" . }}
- name: KC_HOSTNAME
  value: {{ required "hostname.hostname is required in production mode" .Values.hostname.hostname | quote }}
{{- if .Values.ingress.admin.enabled }}
- name: KC_HOSTNAME_ADMIN
  value: {{ required "hostname.admin is required when ingress.admin.enabled is true in production mode" .Values.hostname.admin | quote }}
{{- else if .Values.hostname.admin }}
- name: KC_HOSTNAME_ADMIN
  value: {{ .Values.hostname.admin | quote }}
{{- end }}
- name: KC_HOSTNAME_STRICT
  value: {{ ternary "true" "false" .Values.hostname.strict | quote }}
- name: KC_HOSTNAME_BACKCHANNEL_DYNAMIC
  value: {{ ternary "true" "false" .Values.hostname.backchannelDynamic | quote }}
{{- if .Values.proxy.headers }}
- name: KC_PROXY_HEADERS
  value: {{ .Values.proxy.headers | quote }}
{{- end }}
{{- if .Values.proxy.trustedAddresses }}
- name: KC_PROXY_TRUSTED_ADDRESSES
  value: {{ .Values.proxy.trustedAddresses | quote }}
{{- end }}
{{- if .Values.proxy.protocolEnabled }}
- name: KC_PROXY_PROTOCOL_ENABLED
  value: "true"
{{- end }}
{{- end }}
{{- end -}}

{{- define "keycloak.runtimeEnv" -}}
{{ include "keycloak.httpEnv" . }}
- name: KC_BOOTSTRAP_ADMIN_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "keycloak.adminSecretName" . }}
      key: {{ .Values.admin.existingSecretUsernameKey }}
- name: KC_BOOTSTRAP_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "keycloak.adminSecretName" . }}
      key: {{ .Values.admin.existingSecretPasswordKey }}
- name: KC_HEALTH_ENABLED
  value: {{ ternary "true" "false" .Values.health.enabled | quote }}
- name: KC_METRICS_ENABLED
  value: {{ ternary "true" "false" .Values.metrics.enabled | quote }}
{{- if .Values.metrics.userEvents }}
- name: KC_EVENT_METRICS_USER_ENABLED
  value: "true"
{{- end }}
{{- if .Values.metrics.cacheHistograms }}
- name: KC_CACHE_METRICS_HISTOGRAMS_ENABLED
  value: "true"
{{- end }}
{{- if .Values.telemetry.metricsEnabled }}
- name: KC_TELEMETRY_METRICS_ENABLED
  value: "true"
{{- end }}
{{- if .Values.telemetry.endpoint }}
- name: KC_TELEMETRY_ENDPOINT
  value: {{ .Values.telemetry.endpoint | quote }}
{{- end }}
{{- if .Values.telemetry.metricsEndpoint }}
- name: KC_TELEMETRY_METRICS_ENDPOINT
  value: {{ .Values.telemetry.metricsEndpoint | quote }}
{{- end }}
{{- if .Values.tracing.enabled }}
- name: KC_TRACING_ENABLED
  value: "true"
{{- with .Values.tracing.endpoint }}
- name: KC_TRACING_ENDPOINT
  value: {{ . | quote }}
{{- end }}
{{- with .Values.tracing.samplerType }}
- name: KC_TRACING_SAMPLER_TYPE
  value: {{ . | quote }}
{{- end }}
{{- with .Values.tracing.samplerRatio }}
- name: KC_TRACING_SAMPLER_RATIO
  value: {{ . | quote }}
{{- end }}
{{- with .Values.tracing.resourceAttributes }}
- name: KC_TRACING_RESOURCE_ATTRIBUTES
  value: {{ . | quote }}
{{- end }}
- name: KC_TRACING_JDBC_ENABLED
  value: {{ ternary "true" "false" .Values.tracing.jdbcEnabled | quote }}
- name: KC_TRACING_INFINISPAN_ENABLED
  value: {{ ternary "true" "false" .Values.tracing.infinispanEnabled | quote }}
{{- end }}
{{- if .Values.logging.level }}
- name: KC_LOG_LEVEL
  value: {{ .Values.logging.level | quote }}
{{- end }}
{{- if .Values.logging.console.output }}
- name: KC_LOG_CONSOLE_OUTPUT
  value: {{ .Values.logging.console.output | quote }}
{{- end }}
{{- if .Values.logging.console.level }}
- name: KC_LOG_CONSOLE_LEVEL
  value: {{ .Values.logging.console.level | quote }}
{{- end }}
{{- if and (eq .Values.logging.console.output "json") .Values.logging.console.jsonFormat }}
- name: KC_LOG_CONSOLE_JSON_FORMAT
  value: {{ .Values.logging.console.jsonFormat | quote }}
{{- end }}
{{- if .Values.logging.access.enabled }}
- name: KC_HTTP_ACCESS_LOG_ENABLED
  value: "true"
{{- with .Values.logging.access.pattern }}
- name: KC_HTTP_ACCESS_LOG_PATTERN
  value: {{ . | quote }}
{{- end }}
{{- with .Values.logging.access.exclude }}
- name: KC_HTTP_ACCESS_LOG_EXCLUDE
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.truststore.enabled }}
- name: KC_TRUSTSTORE_PATHS
  value: {{ .Values.truststore.mountPath | quote }}
- name: KC_TLS_HOSTNAME_VERIFIER
  value: {{ .Values.truststore.tlsHostnameVerifier | quote }}
{{- end }}
- name: KC_TRUSTSTORE_KUBERNETES_ENABLED
  value: {{ ternary "true" "false" .Values.truststore.kubernetes.enabled | quote }}
{{- if include "keycloak.hasDatabase" . }}
- name: KC_DB
  value: {{ include "keycloak.databaseVendor" . | quote }}
- name: KC_DB_URL
  value: {{ include "keycloak.databaseUrl" . | quote }}
- name: KC_DB_USERNAME
  value: {{ include "keycloak.databaseUsername" . | quote }}
- name: KC_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "keycloak.databaseSecretName" . }}
      key: {{ include "keycloak.databaseSecretPasswordKey" . }}
{{- with .Values.database.external.schema }}
- name: KC_DB_SCHEMA
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.external.pool.initialSize }}
- name: KC_DB_POOL_INITIAL_SIZE
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.external.pool.minSize }}
- name: KC_DB_POOL_MIN_SIZE
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.external.pool.maxSize }}
- name: KC_DB_POOL_MAX_SIZE
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.external.pool.maxLifetime }}
- name: KC_DB_POOL_MAX_LIFETIME
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.external.logSlowQueriesThreshold }}
- name: KC_DB_LOG_SLOW_QUERIES_THRESHOLD
  value: {{ . | quote }}
{{- end }}
{{- if ne (toString .Values.database.external.transaction.xaEnabled) "" }}
- name: KC_TRANSACTION_XA_ENABLED
  value: {{ .Values.database.external.transaction.xaEnabled | quote }}
{{- end }}
{{- with .Values.database.external.transaction.timeout }}
- name: KC_TRANSACTION_TIMEOUT
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.tls.mode }}
- name: KC_DB_TLS_MODE
  value: {{ . | quote }}
{{- end }}
{{- with .Values.database.tls.trustStoreFile }}
- name: KC_DB_TLS_TRUST_STORE_FILE
  value: {{ . | quote }}
{{- end }}
{{- if .Values.database.tls.trustStorePasswordSecret }}
- name: KC_DB_TLS_TRUST_STORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.tls.trustStorePasswordSecret }}
      key: {{ .Values.database.tls.trustStorePasswordKey }}
{{- end }}
{{- with .Values.database.tls.trustStoreType }}
- name: KC_DB_TLS_TRUST_STORE_TYPE
  value: {{ . | quote }}
{{- end }}
{{- else if include "keycloak.isProduction" . }}
{{- fail "production mode requires a database: set postgresql.enabled, mysql.enabled, or database.external.host" }}
{{- end }}
{{- if and (include "keycloak.isProduction" .) (gt (int .Values.replicaCount) 1) .Values.cache.enabled }}
- name: KC_CACHE
  value: ispn
- name: KC_CACHE_STACK
  value: {{ .Values.cache.stack | quote }}
{{- end }}
{{- if .Values.features.enabled }}
- name: KC_FEATURES
  value: {{ join "," .Values.features.enabled | quote }}
{{- end }}
{{- if .Values.features.disabled }}
- name: KC_FEATURES_DISABLED
  value: {{ join "," .Values.features.disabled | quote }}
{{- end }}
{{- end -}}

{{- define "keycloak.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "keycloak.serviceAccountName" . }}
automountServiceAccountToken: {{ ternary "true" "false" .Values.serviceAccount.automountServiceAccountToken }}
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
{{- else if include "keycloak.defaultAffinityEnabled" . }}
affinity:
  podAntiAffinity:
    {{- if eq .Values.cache.multiReplicaDefaults.podAntiAffinity "required" }}
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            {{- include "keycloak.selectorLabels" . | nindent 12 }}
        topologyKey: kubernetes.io/hostname
    {{- else }}
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              {{- include "keycloak.selectorLabels" . | nindent 14 }}
          topologyKey: kubernetes.io/hostname
    {{- end }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml .Values.topologySpreadConstraints | nindent 2 }}
{{- else if include "keycloak.defaultTopologySpreadEnabled" . }}
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: {{ .Values.cache.multiReplicaDefaults.topologySpread.topologyKey }}
    whenUnsatisfiable: {{ .Values.cache.multiReplicaDefaults.topologySpread.whenUnsatisfiable }}
    labelSelector:
      matchLabels:
        {{- include "keycloak.selectorLabels" . | nindent 8 }}
{{- end }}
{{- end -}}

{{- define "keycloak.resources" -}}
{{- $profile := .Values.capacity.profile | default "custom" -}}
{{- if ne $profile "custom" -}}
{{- toYaml (index .Values.capacity.profiles $profile) -}}
{{- else -}}
{{- toYaml .Values.resources -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.defaultAffinityEnabled" -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.cache.multiReplicaDefaults.enabled (ne .Values.cache.multiReplicaDefaults.podAntiAffinity "none") -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.defaultTopologySpreadEnabled" -}}
{{- if and (gt (int .Values.replicaCount) 1) .Values.cache.multiReplicaDefaults.enabled .Values.cache.multiReplicaDefaults.topologySpread.enabled -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.probeValue" -}}
{{- $root := .root -}}
{{- $probe := .probe -}}
{{- $field := .field -}}
{{- $profile := default "default" $root.Values.probes.profile -}}
{{- if eq $profile "heavy-startup" -}}
  {{- if and (eq $probe "liveness") (eq $field "initialDelaySeconds") -}}120
  {{- else if and (eq $probe "liveness") (eq $field "periodSeconds") -}}20
  {{- else if and (eq $probe "liveness") (eq $field "timeoutSeconds") -}}5
  {{- else if and (eq $probe "liveness") (eq $field "failureThreshold") -}}6
  {{- else if and (eq $probe "readiness") (eq $field "initialDelaySeconds") -}}60
  {{- else if and (eq $probe "readiness") (eq $field "periodSeconds") -}}10
  {{- else if and (eq $probe "readiness") (eq $field "timeoutSeconds") -}}5
  {{- else if and (eq $probe "readiness") (eq $field "failureThreshold") -}}12
  {{- else if and (eq $probe "startup") (eq $field "initialDelaySeconds") -}}40
  {{- else if and (eq $probe "startup") (eq $field "periodSeconds") -}}10
  {{- else if and (eq $probe "startup") (eq $field "timeoutSeconds") -}}5
  {{- else if and (eq $probe "startup") (eq $field "failureThreshold") -}}90
  {{- end -}}
{{- else -}}
  {{- if eq $probe "liveness" -}}
    {{- index $root.Values.probes.liveness $field -}}
  {{- else if eq $probe "readiness" -}}
    {{- index $root.Values.probes.readiness $field -}}
  {{- else if eq $probe "startup" -}}
    {{- index $root.Values.probes.startup $field -}}
  {{- end -}}
{{- end -}}
{{- end -}}
