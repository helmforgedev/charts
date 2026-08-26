{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "ente.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ente.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "ente.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ente.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ente.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ente.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ente.labels" -}}
helm.sh/chart: {{ include "ente.chart" . }}
{{ include "ente.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ente
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ente.componentLabels" -}}
{{ include "ente.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "ente.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ente.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "ente.databaseMode" -}}
{{- $mode := .Values.database.mode | default "auto" -}}
{{- $hasExternal := or .Values.database.external.host .Values.database.external.existingSecret -}}
{{- if eq $mode "auto" -}}
  {{- if and $hasExternal .Values.postgresql.enabled -}}
    {{- fail "ente database selection is ambiguous: configure external PostgreSQL or enable the postgresql subchart, not both" -}}
  {{- else if $hasExternal -}}external
  {{- else if .Values.postgresql.enabled -}}postgresql
  {{- else -}}{{- fail "ente requires PostgreSQL: enable postgresql.enabled or configure database.external.host" -}}
  {{- end -}}
{{- else if eq $mode "external" -}}
  {{- if not .Values.database.external.host -}}{{- fail "database.mode=external requires database.external.host" -}}{{- end -}}
  {{- if .Values.postgresql.enabled -}}{{- fail "database.mode=external requires postgresql.enabled=false to avoid deploying an unused PostgreSQL dependency" -}}{{- end -}}
external
{{- else if eq $mode "postgresql" -}}
  {{- if not .Values.postgresql.enabled -}}{{- fail "database.mode=postgresql requires postgresql.enabled=true" -}}{{- end -}}
postgresql
{{- else -}}
{{- fail (printf "database.mode must be one of: auto, postgresql, external (got %s)" $mode) -}}
{{- end -}}
{{- end -}}

{{- define "ente.databaseHost" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}
{{- .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "ente.databasePort" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}{{ .Values.database.external.port }}{{- else -}}5432{{- end -}}
{{- end -}}

{{- define "ente.databaseName" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}{{ .Values.database.external.name }}{{- else -}}{{ .Values.postgresql.auth.database }}{{- end -}}
{{- end -}}

{{- define "ente.databaseUsername" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}{{ .Values.database.external.username }}{{- else -}}{{ .Values.postgresql.auth.username }}{{- end -}}
{{- end -}}

{{- define "ente.databaseSslMode" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}{{ .Values.database.external.sslMode }}{{- else -}}disable{{- end -}}
{{- end -}}

{{- define "ente.databaseSecretName" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}
{{- default (printf "%s-database" (include "ente.fullname" .)) .Values.database.external.existingSecret -}}
{{- else -}}
{{- default (printf "%s-postgresql-auth" .Release.Name) .Values.postgresql.auth.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "ente.databaseSecretKey" -}}
{{- if eq (include "ente.databaseMode" .) "external" -}}
{{- .Values.database.external.existingSecretPasswordKey -}}
{{- else -}}
{{- default "user-password" .Values.postgresql.auth.existingSecretUserPasswordKey -}}
{{- end -}}
{{- end -}}

{{- define "ente.museumSecretName" -}}
{{- default (printf "%s-museum" (include "ente.fullname" .)) .Values.museum.existingSecret -}}
{{- end -}}

{{- define "ente.s3SecretName" -}}
{{- default (printf "%s-s3" (include "ente.fullname" .)) .Values.storage.s3.existingSecret -}}
{{- end -}}

{{- define "ente.smtpSecretName" -}}
{{- default (printf "%s-smtp" (include "ente.fullname" .)) .Values.smtp.existingSecret -}}
{{- end -}}

{{- define "ente.backupSecretName" -}}
{{- default (printf "%s-backup" (include "ente.fullname" .)) .Values.backup.s3.existingSecret -}}
{{- end -}}

{{- define "ente.routeServiceName" -}}
{{- $root := .root -}}
{{- $service := .service -}}
{{- if eq $service "museum" -}}
{{- printf "%s-museum" (include "ente.fullname" $root) -}}
{{- else if hasKey $root.Values.web.apps $service -}}
  {{- $app := get $root.Values.web.apps $service -}}
  {{- if not $app.enabled -}}{{- fail (printf "route service %q references a disabled web application" $service) -}}{{- end -}}
{{- printf "%s-%s" (include "ente.fullname" $root) $service -}}
{{- else -}}
{{- fail (printf "route service must be museum or an enabled web application (got %s)" $service) -}}
{{- end -}}
{{- end -}}

{{- define "ente.routeServicePort" -}}
{{- if eq .service "museum" -}}{{ .root.Values.museum.service.port }}{{- else -}}{{ .root.Values.web.service.port }}{{- end -}}
{{- end -}}

{{- define "ente.externalSecretName" -}}
{{- $root := .root -}}
{{- $item := .item -}}
{{- $index := .index -}}
{{- default (printf "%s-external-%d" (include "ente.fullname" $root) $index) $item.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ente.museumImage" -}}
{{- printf "%s:%s" .Values.museum.image.repository .Values.museum.image.tag -}}
{{- end -}}

{{- define "ente.webImage" -}}
{{- printf "%s:%s" .Values.web.image.repository .Values.web.image.tag -}}
{{- end -}}

{{- define "ente.firstWebApp" -}}
{{- $result := dict "name" "" "port" 0 -}}
{{- range $name, $app := .Values.web.apps -}}
{{- if and $app.enabled (not $result.name) -}}
{{- $_ := set $result "name" $name -}}
{{- $_ := set $result "port" $app.port -}}
{{- end -}}
{{- end -}}
{{- toJson $result -}}
{{- end -}}

{{- define "ente.validate" -}}
{{- $databaseMode := include "ente.databaseMode" . -}}
{{- if not .Values.storage.s3.endpoint -}}{{- fail "storage.s3.endpoint is required" -}}{{- end -}}
{{- if not .Values.storage.s3.region -}}{{- fail "storage.s3.region is required" -}}{{- end -}}
{{- if not .Values.storage.s3.bucket -}}{{- fail "storage.s3.bucket is required" -}}{{- end -}}
{{- if and (not .Values.storage.s3.existingSecret) (not .Values.storage.s3.accessKey) -}}{{- fail "storage.s3.accessKey or storage.s3.existingSecret is required" -}}{{- end -}}
{{- if and (not .Values.storage.s3.existingSecret) (not .Values.storage.s3.secretKey) -}}{{- fail "storage.s3.secretKey or storage.s3.existingSecret is required" -}}{{- end -}}
{{- if and .Values.museum.worker.enabled (not .Values.museum.api.skipBackgroundJobs) -}}{{- fail "museum.worker.enabled=true requires museum.api.skipBackgroundJobs=true to prevent duplicate cron jobs" -}}{{- end -}}
{{- if and (gt (int .Values.museum.api.replicaCount) 1) (not .Values.museum.api.skipBackgroundJobs) -}}{{- fail "museum.api.replicaCount greater than 1 requires museum.api.skipBackgroundJobs=true" -}}{{- end -}}
{{- if and .Values.museum.api.skipBackgroundJobs (not .Values.museum.worker.enabled) -}}{{- fail "museum.api.skipBackgroundJobs=true requires museum.worker.enabled=true so scheduled maintenance still runs" -}}{{- end -}}
{{- $concurrentMuseum := or (gt (int .Values.museum.api.replicaCount) 1) .Values.museum.worker.enabled .Values.autoscaling.museum.enabled -}}
{{- if and $concurrentMuseum (not .Values.museum.migrationGate.enabled) -}}{{- fail "concurrent Museum processes require museum.migrationGate.enabled=true to serialize database migrations" -}}{{- end -}}
{{- $firstApp := include "ente.firstWebApp" . | fromJson -}}
{{- if not $firstApp.name -}}{{- fail "at least one web.apps entry must be enabled" -}}{{- end -}}
{{- if .Values.productionMode -}}
  {{- if hasSuffix ".example.com" .Values.museum.externalUrl -}}{{- fail "productionMode=true requires a real museum.externalUrl" -}}{{- end -}}
  {{- if hasSuffix ".example.com" .Values.storage.s3.endpoint -}}{{- fail "productionMode=true requires a real storage.s3.endpoint" -}}{{- end -}}
  {{- if and (not .Values.storage.s3.existingSecret) (or (eq .Values.storage.s3.accessKey "change-me") (eq .Values.storage.s3.secretKey "change-me")) -}}{{- fail "productionMode=true requires storage.s3.existingSecret or non-placeholder S3 credentials" -}}{{- end -}}
  {{- if .Values.storage.s3.localBuckets -}}{{- fail "productionMode=true forbids storage.s3.localBuckets" -}}{{- end -}}
  {{- range $name, $app := .Values.web.apps -}}
    {{- if and $app.enabled (hasSuffix ".example.com" $app.externalUrl) -}}{{- fail (printf "productionMode=true requires a real web.apps.%s.externalUrl" $name) -}}{{- end -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.smtp.enabled (not .Values.smtp.host) -}}{{- fail "smtp.enabled=true requires smtp.host" -}}{{- end -}}
{{- if and .Values.smtp.enabled (not .Values.smtp.email) -}}{{- fail "smtp.enabled=true requires smtp.email" -}}{{- end -}}
{{- if and .Values.pdb.museum.enabled (lt (int .Values.museum.api.replicaCount) 2) (not .Values.autoscaling.museum.enabled) -}}{{- fail "pdb.museum.enabled=true requires at least two Museum API replicas or Museum autoscaling" -}}{{- end -}}
{{- if and .Values.pdb.web.enabled (lt (int .Values.web.replicaCount) 2) (not .Values.autoscaling.web.enabled) -}}{{- fail "pdb.web.enabled=true requires at least two web replicas or web autoscaling" -}}{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}{{- fail "metrics.serviceMonitor.enabled=true requires metrics.enabled=true" -}}{{- end -}}
{{- if and .Values.metrics.prometheusRule.enabled (not .Values.metrics.enabled) -}}{{- fail "metrics.prometheusRule.enabled=true requires metrics.enabled=true" -}}{{- end -}}
{{- if and .Values.ingress.enabled (empty .Values.ingress.hosts) -}}{{- fail "ingress.enabled=true requires ingress.hosts" -}}{{- end -}}
{{- range $index, $host := .Values.ingress.hosts }}
  {{- if not $host.host -}}{{- fail (printf "ingress.hosts[%d].host is required" $index) -}}{{- end -}}
  {{- if not $host.service -}}{{- fail (printf "ingress.hosts[%d].service is required" $index) -}}{{- end -}}
  {{- $_ := include "ente.routeServiceName" (dict "root" $ "service" $host.service) -}}
{{- end -}}
{{- if and .Values.gateway.enabled (empty .Values.gateway.routes) -}}{{- fail "gateway.enabled=true requires gateway.routes" -}}{{- end -}}
{{- range $index, $route := .Values.gateway.routes }}
  {{- if not $route.name -}}{{- fail (printf "gateway.routes[%d].name is required" $index) -}}{{- end -}}
  {{- if not $route.service -}}{{- fail (printf "gateway.routes[%d].service is required" $index) -}}{{- end -}}
  {{- if and (empty ($route.parentRefs | default list)) (empty $.Values.gateway.parentRefs) -}}{{- fail (printf "gateway.routes[%d] requires parentRefs or gateway.parentRefs" $index) -}}{{- end -}}
  {{- $_ := include "ente.routeServiceName" (dict "root" $ "service" $route.service) -}}
{{- end -}}
{{- if .Values.backup.enabled }}
  {{- if not .Values.backup.s3.endpoint -}}{{- fail "backup.enabled=true requires backup.s3.endpoint" -}}{{- end -}}
  {{- if not .Values.backup.s3.bucket -}}{{- fail "backup.enabled=true requires backup.s3.bucket" -}}{{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.accessKey) -}}{{- fail "backup.enabled=true requires backup.s3.accessKey or backup.s3.existingSecret" -}}{{- end -}}
  {{- if and (not .Values.backup.s3.existingSecret) (not .Values.backup.s3.secretKey) -}}{{- fail "backup.enabled=true requires backup.s3.secretKey or backup.s3.existingSecret" -}}{{- end -}}
{{- end }}
{{- end -}}

{{- define "ente.museumEnv" -}}
- name: GIN_MODE
  value: release
- name: ENTE_DB_USER
  value: {{ include "ente.databaseUsername" . | quote }}
- name: ENTE_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.databaseSecretName" . }}
      key: {{ include "ente.databaseSecretKey" . }}
- name: ENTE_KEY_ENCRYPTION
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.museumSecretName" . }}
      key: {{ .Values.museum.secretKeys.encryptionKey }}
- name: ENTE_KEY_HASH
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.museumSecretName" . }}
      key: {{ .Values.museum.secretKeys.hashKey }}
- name: ENTE_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.museumSecretName" . }}
      key: {{ .Values.museum.secretKeys.jwtSecret }}
- name: ENTE_S3_B2_EU_CEN_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.s3SecretName" . }}
      key: {{ .Values.storage.s3.existingSecretAccessKeyKey }}
- name: ENTE_S3_B2_EU_CEN_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.s3SecretName" . }}
      key: {{ .Values.storage.s3.existingSecretSecretKeyKey }}
{{- if .Values.smtp.enabled }}
- name: ENTE_SMTP_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.smtpSecretName" . }}
      key: {{ .Values.smtp.existingSecretUsernameKey }}
- name: ENTE_SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ente.smtpSecretName" . }}
      key: {{ .Values.smtp.existingSecretPasswordKey }}
{{- end }}
{{- with .Values.museum.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "ente.museumPodSpec" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $configKey := .configKey -}}
{{- $resources := .resources -}}
{{- $migrationGate := and $root.Values.museum.migrationGate.enabled (or (gt (int $root.Values.museum.api.replicaCount) 1) $root.Values.museum.worker.enabled $root.Values.autoscaling.museum.enabled) -}}
{{- with $root.Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "ente.serviceAccountName" $root }}
automountServiceAccountToken: {{ $root.Values.serviceAccount.automountServiceAccountToken }}
securityContext:
  {{- toYaml $root.Values.museum.podSecurityContext | nindent 2 }}
terminationGracePeriodSeconds: {{ $root.Values.terminationGracePeriodSeconds }}
initContainers:
  - name: wait-for-postgresql
    image: {{ $root.Values.waitForDatabase.image }}
    imagePullPolicy: {{ $root.Values.waitForDatabase.pullPolicy }}
    securityContext:
      {{- toYaml $root.Values.waitForDatabase.securityContext | nindent 6 }}
    {{- with $root.Values.waitForDatabase.resources }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    command: ["sh", "-ec"]
    args:
      - until nc -z -w2 {{ include "ente.databaseHost" $root }} {{ include "ente.databasePort" $root }}; do sleep 2; done
containers:
  - name: museum
    image: {{ include "ente.museumImage" $root | quote }}
    imagePullPolicy: {{ $root.Values.museum.image.pullPolicy }}
    securityContext:
      {{- toYaml $root.Values.museum.securityContext | nindent 6 }}
    {{- if $migrationGate }}
    command: ["/bin/sh", "-ec"]
    args:
      - until [ -f /migration-gate/start ]; do sleep 1; done; exec /museum
    {{- end }}
    ports:
      - name: http
        containerPort: 8080
        protocol: TCP
      - name: metrics
        containerPort: 2112
        protocol: TCP
    env:
      {{- include "ente.museumEnv" $root | nindent 6 }}
    {{- if $root.Values.museum.probes.startup.enabled }}
    startupProbe:
      httpGet:
        path: /ping
        port: http
      initialDelaySeconds: {{ $root.Values.museum.probes.startup.initialDelaySeconds }}
      periodSeconds: {{ $root.Values.museum.probes.startup.periodSeconds }}
      timeoutSeconds: {{ $root.Values.museum.probes.startup.timeoutSeconds }}
      failureThreshold: {{ $root.Values.museum.probes.startup.failureThreshold }}
    {{- end }}
    {{- if $root.Values.museum.probes.readiness.enabled }}
    readinessProbe:
      httpGet:
        path: /ping
        port: http
      periodSeconds: {{ $root.Values.museum.probes.readiness.periodSeconds }}
      timeoutSeconds: {{ $root.Values.museum.probes.readiness.timeoutSeconds }}
      failureThreshold: {{ $root.Values.museum.probes.readiness.failureThreshold }}
    {{- end }}
    {{- if $root.Values.museum.probes.liveness.enabled }}
    livenessProbe:
      tcpSocket:
        port: http
      initialDelaySeconds: {{ $root.Values.museum.probes.liveness.initialDelaySeconds }}
      periodSeconds: {{ $root.Values.museum.probes.liveness.periodSeconds }}
      timeoutSeconds: {{ $root.Values.museum.probes.liveness.timeoutSeconds }}
      failureThreshold: {{ $root.Values.museum.probes.liveness.failureThreshold }}
    {{- end }}
    resources:
      {{- toYaml $resources | nindent 6 }}
    volumeMounts:
      - name: config
        mountPath: /museum.yaml
        subPath: {{ $configKey }}
        readOnly: true
      - name: tmp
        mountPath: /tmp
      {{- if $migrationGate }}
      - name: migration-gate
        mountPath: /migration-gate
      {{- end }}
      {{- with $root.Values.museum.extraVolumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
  {{- if $migrationGate }}
  - name: migration-gate
    image: {{ printf "%s:%s" $root.Values.museum.migrationGate.image.repository $root.Values.museum.migrationGate.image.tag | quote }}
    imagePullPolicy: {{ $root.Values.museum.migrationGate.image.pullPolicy }}
    securityContext:
      {{- toYaml $root.Values.museum.migrationGate.securityContext | nindent 6 }}
    env:
      - name: PGPASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ include "ente.databaseSecretName" $root }}
            key: {{ include "ente.databaseSecretKey" $root }}
      - name: PGSSLMODE
        value: {{ include "ente.databaseSslMode" $root | quote }}
      - name: PSQL_HISTORY
        value: /tmp/.psql_history
    command: ["bash", "-ec"]
    args:
      - |
        rm -f /migration-gate/start
        cat > /tmp/acquire-migration-lock.sql <<'ACQUIRE_SQL'
        SELECT pg_try_advisory_lock({{ printf "%d" (int64 $root.Values.museum.migrationGate.advisoryLockId) }}) AS acquired \gset
        \if :acquired
        \else
        \! sleep 1
        \i /tmp/acquire-migration-lock.sql
        \endif
        ACQUIRE_SQL
        psql \
          --host={{ include "ente.databaseHost" $root }} \
          --port={{ include "ente.databasePort" $root }} \
          --username={{ include "ente.databaseUsername" $root }} \
          --dbname={{ include "ente.databaseName" $root }} \
          --no-psqlrc \
          --set=ON_ERROR_STOP=1 <<'SQL'
        \i /tmp/acquire-migration-lock.sql
        \! touch /migration-gate/start
        \! until bash -c 'echo > /dev/tcp/127.0.0.1/8080' >/dev/null 2>&1; do sleep 1; done
        SELECT pg_advisory_unlock({{ printf "%d" (int64 $root.Values.museum.migrationGate.advisoryLockId) }});
        SQL
        exec sleep infinity
    resources:
      {{- toYaml $root.Values.museum.migrationGate.resources | nindent 6 }}
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: migration-gate
        mountPath: /migration-gate
  {{- end }}
volumes:
  - name: config
    configMap:
      name: {{ include "ente.fullname" $root }}-config
  - name: tmp
    emptyDir: {}
  {{- if $migrationGate }}
  - name: migration-gate
    emptyDir: {}
  {{- end }}
  {{- with $root.Values.museum.extraVolumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- with $root.Values.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with $root.Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $root.Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $root.Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $root.Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
