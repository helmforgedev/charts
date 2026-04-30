{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{/*
Chart name, truncated to 63 characters.
*/}}
{{- define "pihole.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 characters.
*/}}
{{- define "pihole.fullname" -}}
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

{{/*
Chart label value.
*/}}
{{- define "pihole.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "pihole.labels" -}}
helm.sh/chart: {{ include "pihole.chart" . }}
{{ include "pihole.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: pihole
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod matching.
*/}}
{{- define "pihole.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pihole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "pihole.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pihole.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Secret name for admin password.
*/}}
{{- define "pihole.secretName" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecret }}
{{- else }}
{{- include "pihole.fullname" . }}
{{- end }}
{{- end }}

{{/*
Secret key for admin password.
*/}}
{{- define "pihole.secretKey" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecretKey }}
{{- else }}
{{- print "password" }}
{{- end }}
{{- end }}

{{/*
Image string with tag fallback to appVersion.
*/}}
{{- define "pihole.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}

{{/*
Upstream DNS value. When unbound is enabled, override to local sidecar.
*/}}
{{- define "pihole.upstreamDns" -}}
{{- if .Values.unbound.enabled }}
{{- printf "127.0.0.1#%d" (int .Values.unbound.port) }}
{{- else }}
{{- .Values.pihole.upstreamDns }}
{{- end }}
{{- end }}

{{/*
ConfigMap name for custom DNS and dnsmasq config.
*/}}
{{- define "pihole.configMapName" -}}
{{- printf "%s-config" (include "pihole.fullname" .) }}
{{- end }}

{{/*
Generate adlist URLs based on preset and custom lists.
Returns list.
*/}}
{{- define "pihole.adlists" -}}
{{- $lists := list }}
{{- $preset := .Values.dns.preset | default "none" }}

{{- if eq $preset "basic" }}
{{- $lists = append $lists "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" }}
{{- else if eq $preset "balanced" }}
{{- $lists = append $lists "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" }}
{{- $lists = append $lists "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/multi.txt" }}
{{- $lists = append $lists "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt" }}
{{- else if eq $preset "aggressive" }}
{{- $lists = append $lists "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" }}
{{- $lists = append $lists "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/pro.txt" }}
{{- $lists = append $lists "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/doh-vpn-proxy-bypass.txt" }}
{{- $lists = append $lists "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/tif.txt" }}
{{- else if eq $preset "gaming-friendly" }}
{{- $lists = append $lists "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" }}
{{- $lists = append $lists "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/multi.txt" }}
{{- end }}

{{- range .Values.dns.adlists }}
{{- $lists = append $lists . }}
{{- end }}

{{- $lists | toJson }}
{{- end }}

{{/*
Generate whitelist domains based on presets and custom lists.
Returns list.
*/}}
{{- define "pihole.whitelist" -}}
{{- $whitelist := list }}

{{- if .Values.dns.whitelistPresets.microsoft }}
{{- $whitelist = append $whitelist "*.microsoft.com" }}
{{- $whitelist = append $whitelist "*.windows.com" }}
{{- $whitelist = append $whitelist "*.windowsupdate.com" }}
{{- $whitelist = append $whitelist "*.office.com" }}
{{- $whitelist = append $whitelist "*.office365.com" }}
{{- $whitelist = append $whitelist "*.live.com" }}
{{- $whitelist = append $whitelist "*.msftconnecttest.com" }}
{{- end }}

{{- if .Values.dns.whitelistPresets.apple }}
{{- $whitelist = append $whitelist "*.apple.com" }}
{{- $whitelist = append $whitelist "*.icloud.com" }}
{{- $whitelist = append $whitelist "*.mzstatic.com" }}
{{- $whitelist = append $whitelist "*.itunes.com" }}
{{- $whitelist = append $whitelist "*.cdn-apple.com" }}
{{- end }}

{{- if .Values.dns.whitelistPresets.google }}
{{- $whitelist = append $whitelist "*.google.com" }}
{{- $whitelist = append $whitelist "*.googleapis.com" }}
{{- $whitelist = append $whitelist "*.youtube.com" }}
{{- $whitelist = append $whitelist "*.ytimg.com" }}
{{- $whitelist = append $whitelist "*.gstatic.com" }}
{{- $whitelist = append $whitelist "*.googleusercontent.com" }}
{{- end }}

{{- if .Values.dns.whitelistPresets.gaming }}
{{- $whitelist = append $whitelist "*.xboxlive.com" }}
{{- $whitelist = append $whitelist "*.xbox.com" }}
{{- $whitelist = append $whitelist "*.playstation.com" }}
{{- $whitelist = append $whitelist "*.playstation.net" }}
{{- $whitelist = append $whitelist "*.nintendo.com" }}
{{- $whitelist = append $whitelist "*.nintendo.net" }}
{{- $whitelist = append $whitelist "*.steamstatic.com" }}
{{- $whitelist = append $whitelist "*.steampowered.com" }}
{{- end }}

{{- if .Values.dns.whitelistPresets.smartHome }}
{{- $whitelist = append $whitelist "*.amazon.com" }}
{{- $whitelist = append $whitelist "*.alexa.com" }}
{{- $whitelist = append $whitelist "*.amazonaws.com" }}
{{- end }}

{{- if eq .Values.dns.preset "gaming-friendly" }}
{{- $whitelist = append $whitelist "*.xboxlive.com" }}
{{- $whitelist = append $whitelist "*.xbox.com" }}
{{- $whitelist = append $whitelist "*.playstation.com" }}
{{- $whitelist = append $whitelist "*.playstation.net" }}
{{- $whitelist = append $whitelist "*.nintendo.com" }}
{{- $whitelist = append $whitelist "*.nintendo.net" }}
{{- end }}

{{- range .Values.dns.whitelist }}
{{- $whitelist = append $whitelist . }}
{{- end }}

{{- $whitelist | toJson }}
{{- end }}
