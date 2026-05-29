{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "jenkins.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jenkins.fullname" -}}
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

{{- define "jenkins.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jenkins.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jenkins.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "jenkins.labels" -}}
helm.sh/chart: {{ include "jenkins.chart" . }}
{{ include "jenkins.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "jenkins.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "jenkins.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "jenkins.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- printf "%s-admin" (include "jenkins.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "jenkins.configMapName" -}}
{{- printf "%s-config" (include "jenkins.fullname" .) -}}
{{- end -}}

{{- define "jenkins.adminUser" -}}
{{- default "admin" .Values.admin.user -}}
{{- end -}}

{{- define "jenkins.adminPassword" -}}
{{- if .Values.admin.password -}}
{{- .Values.admin.password -}}
{{- else if .Values.admin.existingSecret -}}
{{- "" -}}
{{- else -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (include "jenkins.adminSecretName" .) -}}
{{- if and $secret $secret.data (hasKey $secret.data .Values.admin.existingSecretPasswordKey) -}}
{{- index $secret.data .Values.admin.existingSecretPasswordKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "jenkins.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "jenkins.controllerOpts" -}}
{{- $httpPortArg := printf "--httpPort=%v" .Values.controller.httpPort -}}
{{- if contains "--httpPort" (.Values.controller.jenkinsOpts | default "") -}}
{{- .Values.controller.jenkinsOpts -}}
{{- else -}}
{{- printf "%s %s" (.Values.controller.jenkinsOpts | default "") $httpPortArg | trim -}}
{{- end -}}
{{- end -}}

{{- define "jenkins.javaOpts" -}}
{{- $javaOpts := .Values.controller.javaOpts | default "" -}}
{{- if and .Values.admin.create (not (contains "jenkins.install.runSetupWizard" $javaOpts)) -}}
{{- printf "%s -Djenkins.install.runSetupWizard=false" $javaOpts | trim -}}
{{- else -}}
{{- $javaOpts -}}
{{- end -}}
{{- end -}}
