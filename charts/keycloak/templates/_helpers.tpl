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

{{- define "keycloak.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "keycloak.fullname" .) -}}
{{- end -}}
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
{{- else -}}
{{- printf "%s-db" (include "keycloak.fullname" .) -}}
{{- end -}}
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

{{- define "keycloak.hasDatabaseTlsVolume" -}}
{{- if and .Values.database.tls.enabled (or .Values.database.tls.existingSecret .Values.database.tls.existingConfigMap) -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.hasTruststoreVolume" -}}
{{- if and .Values.truststore.enabled (or .Values.truststore.existingSecret .Values.truststore.existingConfigMap) -}}true{{- end -}}
{{- end -}}

{{- define "keycloak.startCommand" -}}
{{- if eq .Values.mode "dev" -}}start-dev{{- else -}}start{{- end -}}
{{- end -}}

{{- define "keycloak.relativePath" -}}
{{- if eq .Values.http.relativePath "/" -}}/{{- else -}}{{ trimSuffix "/" .Values.http.relativePath }}{{- end -}}
{{- end -}}

{{- define "keycloak.commandArgs" -}}
- {{ include "keycloak.startCommand" . }}
{{- if .Values.realmImport.enabled }}
- --import-realm
{{- end }}
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
{{- if .Values.truststore.enabled }}
- name: KC_TRUSTSTORE_PATHS
  value: {{ .Values.truststore.mountPath | quote }}
- name: KC_TLS_HOSTNAME_VERIFIER
  value: {{ .Values.truststore.tlsHostnameVerifier | quote }}
{{- end }}
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
{{- else if include "keycloak.isProduction" . }}
{{- fail "production mode requires a database: set postgresql.enabled, mysql.enabled, or database.external.host" }}
{{- end }}
{{- if and (include "keycloak.isProduction" .) (gt (int .Values.replicaCount) 1) .Values.cache.enabled }}
- name: KC_CACHE
  value: ispn
- name: KC_CACHE_STACK
  value: {{ .Values.cache.stack | quote }}
{{- end }}
{{- end -}}

{{- define "keycloak.podSpecCommon" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "keycloak.serviceAccountName" . }}
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
