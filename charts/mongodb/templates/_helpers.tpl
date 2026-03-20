{{/*
Expand the name of the chart.
*/}}
{{- define "mongodb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name.
*/}}
{{- define "mongodb.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart label.
*/}}
{{- define "mongodb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "mongodb.labels" -}}
helm.sh/chart: {{ include "mongodb.chart" . }}
{{ include "mongodb.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: database
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "mongodb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mongodb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "mongodb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "mongodb.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Headless service name (for StatefulSet DNS).
*/}}
{{- define "mongodb.headlessServiceName" -}}
{{- printf "%s-headless" (include "mongodb.fullname" .) -}}
{{- end -}}

{{/*
Auth secret name.
*/}}
{{- define "mongodb.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- include "mongodb.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
KeyFile secret name.
*/}}
{{- define "mongodb.keySecretName" -}}
{{- if .Values.auth.existingKeySecret -}}
{{- .Values.auth.existingKeySecret -}}
{{- else -}}
{{- printf "%s-keyfile" (include "mongodb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if any initdb scripts should be mounted (manual scripts, configmap, or auth.users).
*/}}
{{- define "mongodb.hasInitdbScripts" -}}
{{- if or .Values.initdbScripts .Values.initdbScriptsConfigMap .Values.auth.users -}}true{{- end -}}
{{- end -}}

{{/*
Init scripts ConfigMap name.
*/}}
{{- define "mongodb.initdbScriptsConfigMap" -}}
{{- if .Values.initdbScriptsConfigMap -}}
{{- .Values.initdbScriptsConfigMap -}}
{{- else -}}
{{- printf "%s-initdb" (include "mongodb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Mongod config ConfigMap name.
*/}}
{{- define "mongodb.configConfigMap" -}}
{{- printf "%s-config" (include "mongodb.fullname" .) -}}
{{- end -}}

{{/*
Return true if architecture is standalone.
*/}}
{{- define "mongodb.isStandalone" -}}
{{- if eq .Values.architecture "standalone" -}}true{{- end -}}
{{- end -}}

{{/*
Return true if architecture is replicaset.
*/}}
{{- define "mongodb.isReplicaSet" -}}
{{- if eq .Values.architecture "replicaset" -}}true{{- end -}}
{{- end -}}

{{/*
Return true if architecture is sharded.
*/}}
{{- define "mongodb.isSharded" -}}
{{- if eq .Values.architecture "sharded" -}}true{{- end -}}
{{- end -}}

{{/*
Return true if keyFile is needed (replicaset or sharded with auth).
*/}}
{{- define "mongodb.needsKeyFile" -}}
{{- if and .Values.auth.enabled (or (include "mongodb.isReplicaSet" .) (include "mongodb.isSharded" .)) -}}true{{- end -}}
{{- end -}}

{{/*
Replica count for data members.
*/}}
{{- define "mongodb.replicaCount" -}}
{{- if include "mongodb.isStandalone" . -}}
1
{{- else if include "mongodb.isReplicaSet" . -}}
{{- .Values.replicaSet.members | default 3 -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

{{/*
MongoDB connection URI for probes (handles auth).
*/}}
{{- define "mongodb.probeCommand" -}}
{{- if .Values.auth.enabled -}}
mongosh --quiet --eval "db.adminCommand('ping')" -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin
{{- else -}}
mongosh --quiet --eval "db.adminCommand('ping')"
{{- end -}}
{{- end -}}

{{/*
Common mongod args.
*/}}
{{- define "mongodb.mongodArgs" -}}
{{- if include "mongodb.isReplicaSet" . -}}
- "--replSet"
- {{ .Values.replicaSet.name | quote }}
- "--bind_ip_all"
{{- if include "mongodb.needsKeyFile" . }}
- "--keyFile"
- "/etc/mongodb/keyfile/replica-set-key"
{{- end -}}
{{- else if include "mongodb.isStandalone" . -}}
- "--bind_ip_all"
{{- end -}}
{{- end -}}

{{/*
Pod template for MongoDB members (used by standalone and replicaset StatefulSets).
Accepts a dict with: root (top-level context), component (string: "mongodb" or "mongos" etc.)
*/}}
{{- define "mongodb.podTemplate" -}}
metadata:
  labels:
    {{- include "mongodb.selectorLabels" .root | nindent 4 }}
    app.kubernetes.io/component: {{ .component }}
  {{- with .root.Values.podLabels }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .root.Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .root.Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "mongodb.serviceAccountName" .root }}
  terminationGracePeriodSeconds: {{ .root.Values.terminationGracePeriodSeconds }}
  {{- with .root.Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .root.Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .root.Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .root.Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .root.Values.topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .root.Values.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  {{- if include "mongodb.isReplicaSet" .root }}
  initContainers:
    - name: init-keyfile
      image: "{{ .root.Values.image.repository }}:{{ .root.Values.image.tag }}"
      imagePullPolicy: {{ .root.Values.image.pullPolicy }}
      command:
        - bash
        - -c
        - |
          cp /etc/mongodb/keyfile-readonly/replica-set-key /etc/mongodb/keyfile/replica-set-key
          chmod 400 /etc/mongodb/keyfile/replica-set-key
          chown 999:999 /etc/mongodb/keyfile/replica-set-key
      securityContext:
        runAsUser: 0
      volumeMounts:
        - name: keyfile-readonly
          mountPath: /etc/mongodb/keyfile-readonly
          readOnly: true
        - name: keyfile
          mountPath: /etc/mongodb/keyfile
  {{- end }}
  containers:
    - name: mongod
      image: "{{ .root.Values.image.repository }}:{{ .root.Values.image.tag }}"
      imagePullPolicy: {{ .root.Values.image.pullPolicy }}
      {{- if or (include "mongodb.isReplicaSet" .root) (include "mongodb.isStandalone" .root) }}
      args:
        {{- include "mongodb.mongodArgs" .root | nindent 8 }}
      {{- end }}
      ports:
        - name: mongodb
          containerPort: {{ .root.Values.port }}
          protocol: TCP
      env:
        {{- if .root.Values.auth.enabled }}
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: {{ include "mongodb.secretName" .root }}
              key: mongodb-root-username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "mongodb.secretName" .root }}
              key: mongodb-root-password
        {{- end }}
        {{- with .root.Values.initdbDatabase }}
        - name: MONGO_INITDB_DATABASE
          value: {{ . | quote }}
        {{- end }}
        {{- with .root.Values.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .root.Values.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .root.Values.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .root.Values.startupProbe }}
      startupProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.resources | default .root.Values.resources) }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .root.Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        - name: data
          mountPath: /data/db
        {{- if .root.Values.config }}
        - name: config
          mountPath: /etc/mongo/mongod.conf
          subPath: mongod.conf
          readOnly: true
        {{- end }}
        {{- if include "mongodb.hasInitdbScripts" .root }}
        - name: initdb-scripts
          mountPath: /docker-entrypoint-initdb.d
          readOnly: true
        {{- end }}
        {{- if include "mongodb.needsKeyFile" .root }}
        - name: keyfile
          mountPath: /etc/mongodb/keyfile
          readOnly: true
        {{- end }}
        {{- with .root.Values.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    {{- if .root.Values.metrics.enabled }}
    - name: exporter
      image: "{{ .root.Values.metrics.image.repository }}:{{ .root.Values.metrics.image.tag }}"
      imagePullPolicy: {{ .root.Values.metrics.image.pullPolicy }}
      args:
        - "--mongodb.uri=mongodb://$(MONGO_INITDB_ROOT_USERNAME):$(MONGO_INITDB_ROOT_PASSWORD)@localhost:{{ .root.Values.port }}/admin"
        - "--web.listen-address=:{{ .root.Values.metrics.port }}"
        - "--collect-all"
        {{- with .root.Values.metrics.extraArgs }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- if .root.Values.auth.enabled }}
      env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: {{ include "mongodb.secretName" .root }}
              key: mongodb-root-username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "mongodb.secretName" .root }}
              key: mongodb-root-password
      {{- end }}
      ports:
        - name: metrics
          containerPort: {{ .root.Values.metrics.port }}
          protocol: TCP
      livenessProbe:
        httpGet:
          path: /
          port: metrics
        initialDelaySeconds: 15
      {{- with .root.Values.metrics.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
  volumes:
    {{- if .root.Values.config }}
    - name: config
      configMap:
        name: {{ include "mongodb.configConfigMap" .root }}
    {{- end }}
    {{- if include "mongodb.hasInitdbScripts" .root }}
    - name: initdb-scripts
      configMap:
        name: {{ include "mongodb.initdbScriptsConfigMap" .root }}
    {{- end }}
    {{- if include "mongodb.needsKeyFile" .root }}
    - name: keyfile-readonly
      secret:
        secretName: {{ include "mongodb.keySecretName" .root }}
        defaultMode: 0400
    - name: keyfile
      emptyDir: {}
    {{- end }}
    {{- if not .root.Values.persistence.enabled }}
    - name: data
      emptyDir: {}
    {{- end }}
    {{- with .root.Values.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end -}}
