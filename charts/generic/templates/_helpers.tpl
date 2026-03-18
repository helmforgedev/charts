{{/*
Expand the name of the chart.
*/}}
{{- define "chart.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name, truncated to 63 chars.
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Release.Name .Values.nameOverride -}}
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
{{- define "chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to all resources.
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels for matchLabels.
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "chart.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Returns non-empty string if the workload is enabled, empty string if not.
*/}}
{{- define "chart.hasWorkload" -}}
{{- if .Values.workload.enabled -}}true{{- end -}}
{{- end -}}

{{/*
Returns the workload kind (Deployment, StatefulSet, DaemonSet).
*/}}
{{- define "chart.workloadKind" -}}
{{- .Values.workload.type | default "Deployment" -}}
{{- end -}}

{{/*
Returns true if the workload type is the given kind.
Usage: {{ include "chart.isWorkload" (dict "root" . "kind" "Deployment") }}
*/}}
{{- define "chart.isWorkload" -}}
{{- if and .root.Values.workload.enabled (eq (.root.Values.workload.type | default "Deployment") .kind) -}}true{{- end -}}
{{- end -}}

{{/*
Container image string.
Accepts a dict with: root (global context), container (container spec).
If the container defines image.repository, it overrides the global.
Tag format: if global imageTagFormat is "named", uses "{name}-{tag}", otherwise just "{tag}".
*/}}
{{- define "chart.containerImage" -}}
{{- $globalRepo := .root.Values.image.repository -}}
{{- $globalTag := .root.Values.image.tag -}}
{{- $repo := $globalRepo -}}
{{- $tag := $globalTag -}}
{{- if .container.image -}}
  {{- if .container.image.repository -}}
    {{- $repo = .container.image.repository -}}
  {{- end -}}
  {{- if .container.image.tag -}}
    {{- $tag = .container.image.tag -}}
  {{- end -}}
{{- end -}}
{{- if eq (.root.Values.imageTagFormat | default "named") "named" -}}
{{ printf "%s:%s-%s" $repo .container.name ($tag | toString) }}
{{- else -}}
{{ printf "%s:%s" $repo ($tag | toString) }}
{{- end -}}
{{- end -}}

{{/*
Reusable container spec.
Accepts a dict with: root (global context), container (container spec).
Used by deployment, job, and cronjob templates to avoid duplication.
*/}}
{{- define "chart.containerSpec" -}}
{{- $isFirst := eq (.index | default 0 | int) 0 -}}
{{- $applyGlobalProbes := and $isFirst (not .skipGlobalProbes) -}}
- name: {{ .container.name }}
  image: {{ include "chart.containerImage" (dict "root" .root "container" .container) | quote }}
  imagePullPolicy: {{ .container.imagePullPolicy | default .root.Values.image.pullPolicy | default "Always" }}
  {{- with .container.command }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .container.args }}
  args:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .container.workingDir }}
  workingDir: {{ . }}
  {{- end }}
  {{- if or .root.Values.env .container.env }}
  env:
    {{- with .root.Values.env }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with .container.env }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if or .root.Values.envFrom .container.envFrom }}
  envFrom:
    {{- with .root.Values.envFrom }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with .container.envFrom }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- with .container.ports }}
  ports:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if or .container.livenessProbe (and $applyGlobalProbes .root.Values.livenessProbe) }}
  livenessProbe:
    {{- toYaml (.container.livenessProbe | default .root.Values.livenessProbe) | nindent 4 }}
  {{- end }}
  {{- if or .container.readinessProbe (and $applyGlobalProbes .root.Values.readinessProbe) }}
  readinessProbe:
    {{- toYaml (.container.readinessProbe | default .root.Values.readinessProbe) | nindent 4 }}
  {{- end }}
  {{- if or .container.startupProbe (and $applyGlobalProbes .root.Values.startupProbe) }}
  startupProbe:
    {{- toYaml (.container.startupProbe | default .root.Values.startupProbe) | nindent 4 }}
  {{- end }}
  {{- if or .container.resources .root.Values.resources }}
  resources:
    {{- toYaml (.container.resources | default .root.Values.resources) | nindent 4 }}
  {{- end }}
  {{- if or .container.securityContext .root.Values.securityContext }}
  securityContext:
    {{- toYaml (.container.securityContext | default .root.Values.securityContext) | nindent 4 }}
  {{- end }}
  {{- if or .container.volumeMounts .root.Values.persistence.mounts }}
  volumeMounts:
    {{- with .root.Values.persistence.mounts }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with .container.volumeMounts }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- with .container.lifecycle }}
  lifecycle:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
Pod spec shared by deployment, job, and cronjob.
Accepts a dict with: root (global context), containers (list), podSpec (optional overrides).
*/}}
{{- define "chart.podSpec" -}}
{{- with .root.Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "chart.serviceAccountName" .root }}
{{- if hasKey .root.Values.serviceAccount "automountServiceAccountToken" }}
automountServiceAccountToken: {{ .root.Values.serviceAccount.automountServiceAccountToken }}
{{- end }}
{{- with (.podSpec).priorityClassName | default .root.Values.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- if or .root.Values.podSecurityContext (.podSpec).podSecurityContext }}
securityContext:
  {{- toYaml ((.podSpec).podSecurityContext | default .root.Values.podSecurityContext) | nindent 2 }}
{{- end }}
{{- with (.podSpec).terminationGracePeriodSeconds | default .root.Values.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ . }}
{{- end }}
{{- if or .root.Values.initContainers (.podSpec).initContainers }}
initContainers:
  {{- range (.podSpec).initContainers | default .root.Values.initContainers }}
  {{- include "chart.containerSpec" (dict "root" $.root "container" .) | nindent 2 }}
  {{- end }}
{{- end }}
containers:
  {{- $root := .root }}
  {{- $skip := .skipGlobalProbes }}
  {{- range $i, $c := .containers }}
  {{- include "chart.containerSpec" (dict "root" $root "container" $c "index" $i "skipGlobalProbes" $skip) | nindent 2 }}
  {{- end }}
{{- if or .root.Values.persistence.volumes (.podSpec).volumes }}
volumes:
  {{- with .root.Values.persistence.volumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with (.podSpec).volumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
{{- with (.podSpec).nodeSelector | default .root.Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (.podSpec).affinity | default .root.Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (.podSpec).tolerations | default .root.Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (.podSpec).topologySpreadConstraints | default .root.Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (.podSpec).dnsPolicy }}
dnsPolicy: {{ . }}
{{- end }}
{{- with (.podSpec).dnsConfig }}
dnsConfig:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
