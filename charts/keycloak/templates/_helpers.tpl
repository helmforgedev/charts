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

{{- define "keycloak.databaseSecretName" -}}
{{- if .Values.database.existingSecret -}}
{{- .Values.database.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "keycloak.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.realmImportConfigMapName" -}}
{{- printf "%s-realm-import" (include "keycloak.fullname" .) -}}
{{- end -}}

{{- define "keycloak.databasePassword" -}}
{{- $secretName := include "keycloak.databaseSecretName" . -}}
{{- if .Values.database.existingSecret -}}
{{- "" -}}
{{- else if .Values.database.password -}}
{{- .Values.database.password -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existing $existing.data (hasKey $existing.data .Values.database.existingSecretPasswordKey) -}}
{{- index $existing.data .Values.database.existingSecretPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
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

{{- define "keycloak.databasePort" -}}
{{- if eq .Values.database.vendor "postgres" -}}5432
{{- else if eq .Values.database.vendor "mysql" -}}3306
{{- else if eq .Values.database.vendor "mariadb" -}}3306
{{- else -}}{{ .Values.database.port }}{{- end -}}
{{- end -}}

{{- define "keycloak.databaseUrl" -}}
{{- $port := default (include "keycloak.databasePort" .) .Values.database.port -}}
{{- $params := list -}}
{{- if .Values.database.jdbcParameters -}}
{{- $params = append $params .Values.database.jdbcParameters -}}
{{- end -}}
{{- if and .Values.database.tls.enabled (eq .Values.database.vendor "postgres") -}}
{{- $params = append $params (printf "sslmode=%s" .Values.database.tls.sslMode) -}}
{{- if or .Values.database.tls.existingSecret .Values.database.tls.existingConfigMap -}}
{{- $params = append $params (printf "sslrootcert=%s" (include "keycloak.databaseTlsRootCertPath" .)) -}}
{{- end -}}
{{- end -}}
{{- if eq .Values.database.vendor "postgres" -}}
jdbc:postgresql://{{ required "database.host is required in production mode" .Values.database.host }}:{{ $port }}/{{ required "database.name is required in production mode" .Values.database.name }}
{{- else if or (eq .Values.database.vendor "mysql") (eq .Values.database.vendor "mariadb") -}}
jdbc:{{ .Values.database.vendor }}://{{ required "database.host is required in production mode" .Values.database.host }}:{{ $port }}/{{ required "database.name is required in production mode" .Values.database.name }}
{{- else -}}
{{- fail "database.vendor must be one of: postgres, mysql, mariadb" -}}
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
{{- if .Values.hostname.admin }}
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
{{- if include "keycloak.isProduction" . }}
- name: KC_DB
  value: {{ .Values.database.vendor | quote }}
- name: KC_DB_URL
  value: {{ include "keycloak.databaseUrl" . | quote }}
- name: KC_DB_USERNAME
  value: {{ required "database.username is required in production mode" .Values.database.username | quote }}
- name: KC_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "keycloak.databaseSecretName" . }}
      key: {{ .Values.database.existingSecretPasswordKey }}
{{- if and (gt (int .Values.replicaCount) 1) .Values.cache.enabled }}
- name: KC_CACHE
  value: ispn
- name: KC_CACHE_STACK
  value: {{ .Values.cache.stack | quote }}
{{- end }}
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
