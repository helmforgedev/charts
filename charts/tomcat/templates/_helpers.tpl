{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "tomcat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tomcat.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "tomcat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tomcat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tomcat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "tomcat.labels" -}}
helm.sh/chart: {{ include "tomcat.chart" . }}
{{ include "tomcat.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: tomcat
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "tomcat.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tomcat.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "tomcat.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{- define "tomcat.configMapName" -}}
{{- printf "%s-config" (include "tomcat.fullname" .) }}
{{- end }}

{{- define "tomcat.defaultRootConfigMapName" -}}
{{- printf "%s-root-webapp" (include "tomcat.fullname" .) }}
{{- end }}

{{- define "tomcat.webappsPvcName" -}}
{{- default (printf "%s-webapps" (include "tomcat.fullname" .)) .Values.webapps.persistence.existingClaim }}
{{- end }}

{{- define "tomcat.logsPvcName" -}}
{{- default (printf "%s-logs" (include "tomcat.fullname" .)) .Values.logs.persistence.existingClaim }}
{{- end }}

{{- define "tomcat.jmxOpts" -}}
{{- if .Values.jmx.enabled -}}
-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port={{ .Values.jmx.port }} -Dcom.sun.management.jmxremote.rmi.port={{ .Values.jmx.rmiPort }} -Dcom.sun.management.jmxremote.authenticate={{ .Values.jmx.authenticate }} -Dcom.sun.management.jmxremote.ssl={{ .Values.jmx.ssl }} -Djava.rmi.server.hostname={{ default "$(POD_IP)" .Values.jmx.hostname }}{{ with .Values.jmx.extraOpts }} {{ . }}{{ end }}
{{- end -}}
{{- end }}

{{- define "tomcat.probe" -}}
{{- $probe := .probe -}}
{{- if eq $probe.mode "tcp" }}
tcpSocket:
  port: http
{{- else }}
httpGet:
  path: {{ $probe.path }}
  port: http
{{- end }}
initialDelaySeconds: {{ $probe.initialDelaySeconds }}
periodSeconds: {{ $probe.periodSeconds }}
timeoutSeconds: {{ $probe.timeoutSeconds }}
failureThreshold: {{ $probe.failureThreshold }}
{{- end }}

{{- define "tomcat.validate" -}}
{{- if and .Values.gatewayAPI.enabled (empty .Values.gatewayAPI.parentRefs) -}}
{{- fail "gatewayAPI.parentRefs must contain at least one parentRef when gatewayAPI.enabled=true" -}}
{{- end -}}
{{- end }}
