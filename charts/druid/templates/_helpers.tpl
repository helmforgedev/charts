{{- define "druid.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "druid.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "druid.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "druid.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "druid.labels" -}}
helm.sh/chart: {{ include "druid.chart" . }}
{{ include "druid.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "druid.selectorLabels" -}}
app.kubernetes.io/name: {{ include "druid.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "druid.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{- define "druid.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "druid.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Metadata Storage (PostgreSQL)
# =============================================================================

{{- define "druid.metadataHost" -}}
{{- if eq .Values.metadata.mode "external" -}}
{{- .Values.metadata.external.host -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "druid.metadataPort" -}}
{{- if eq .Values.metadata.mode "external" -}}
{{- .Values.metadata.external.port | toString -}}
{{- else -}}
5432
{{- end -}}
{{- end -}}

{{- define "druid.metadataName" -}}
{{- if eq .Values.metadata.mode "external" -}}
{{- .Values.metadata.external.name -}}
{{- else -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "druid.metadataUsername" -}}
{{- if eq .Values.metadata.mode "external" -}}
{{- .Values.metadata.external.username -}}
{{- else -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}
{{- end -}}

{{- define "druid.metadataType" -}}
{{- if eq .Values.metadata.mode "external" -}}
{{- .Values.metadata.external.type -}}
{{- else -}}
postgresql
{{- end -}}
{{- end -}}

{{- define "druid.metadataSecretName" -}}
{{- if and (eq .Values.metadata.mode "external") .Values.metadata.external.existingSecret -}}
{{- .Values.metadata.external.existingSecret -}}
{{- else if eq .Values.metadata.mode "external" -}}
{{- printf "%s-metadata" (include "druid.fullname" .) -}}
{{- else -}}
{{- printf "%s-postgresql-auth" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "druid.metadataSecretKey" -}}
{{- if and (eq .Values.metadata.mode "external") .Values.metadata.external.existingSecret -}}
{{- .Values.metadata.external.existingSecretPasswordKey -}}
{{- else if eq .Values.metadata.mode "external" -}}
metadata-password
{{- else -}}
user-password
{{- end -}}
{{- end -}}

{{- define "druid.metadataConnectUri" -}}
{{- $type := include "druid.metadataType" . -}}
{{- if eq $type "mysql" -}}
jdbc:mysql://{{ include "druid.metadataHost" . }}:{{ include "druid.metadataPort" . }}/{{ include "druid.metadataName" . }}
{{- else -}}
jdbc:postgresql://{{ include "druid.metadataHost" . }}:{{ include "druid.metadataPort" . }}/{{ include "druid.metadataName" . }}
{{- end -}}
{{- end -}}

# =============================================================================
# ZooKeeper
# =============================================================================

{{- define "druid.zookeeperHosts" -}}
{{- if eq .Values.zookeeperConfig.mode "external" -}}
{{- .Values.zookeeperConfig.external.hosts -}}
{{- else -}}
{{- printf "%s-zookeeper:2181" .Release.Name -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Deep Storage
# =============================================================================

{{- define "druid.deepStorageSecretName" -}}
{{- if .Values.deepStorage.s3.existingSecret -}}
{{- .Values.deepStorage.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-deep-storage" (include "druid.fullname" .) -}}
{{- end -}}
{{- end -}}

# =============================================================================
# Common environment variables
# =============================================================================

{{- define "druid.commonEnv" -}}
- name: DRUID_METADATA_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "druid.metadataSecretName" . }}
      key: {{ include "druid.metadataSecretKey" . }}
{{- if eq .Values.deepStorage.type "s3" }}
- name: DRUID_S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "druid.deepStorageSecretName" . }}
      key: {{ if .Values.deepStorage.s3.existingSecret }}{{ .Values.deepStorage.s3.existingSecretAccessKeyKey }}{{ else }}access-key{{ end }}
- name: DRUID_S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "druid.deepStorageSecretName" . }}
      key: {{ if .Values.deepStorage.s3.existingSecret }}{{ .Values.deepStorage.s3.existingSecretSecretKeyKey }}{{ else }}secret-key{{ end }}
{{- end }}
{{- with .Values.druid.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

# =============================================================================
# Init containers
# =============================================================================

{{- define "druid.initContainers" -}}
- name: prepare-dirs
  image: busybox:1.37
  securityContext:
    runAsUser: 0
  command:
    - sh
    - -c
    - |
      mkdir -p /opt/druid/var/druid/segments /opt/druid/var/druid/indexing-logs /opt/druid/var/druid/task /opt/druid/var/druid/hadoop-tmp /opt/druid/var/druid/segment-cache /opt/druid/var/tmp
      chown -R 1000:1000 /opt/druid/var
  volumeMounts:
    - name: druid-var
      mountPath: /opt/druid/var
- name: wait-for-postgresql
  image: busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ include "druid.metadataHost" . }}:{{ include "druid.metadataPort" . }} ..."
      until nc -z -w2 {{ include "druid.metadataHost" . }} {{ include "druid.metadataPort" . }}; do
        sleep 2
      done
      echo "PostgreSQL is reachable."
{{- if eq .Values.zookeeperConfig.mode "subchart" }}
- name: wait-for-zookeeper
  image: busybox:1.37
  command:
    - sh
    - -c
    - |
      echo "Waiting for {{ printf "%s-zookeeper" .Release.Name }}:2181 ..."
      until nc -z -w2 {{ printf "%s-zookeeper" .Release.Name }} 2181; do
        sleep 2
      done
      echo "ZooKeeper is reachable."
{{- end }}
{{- end -}}
