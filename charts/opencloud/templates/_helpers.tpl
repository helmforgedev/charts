{{/* SPDX-License-Identifier: Apache-2.0 */}}
{{- define "opencloud.name" -}}{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "opencloud.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "opencloud.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "opencloud.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}{{- end -}}
{{- define "opencloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opencloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "opencloud.labels" -}}
helm.sh/chart: {{ include "opencloud.chart" . }}
{{ include "opencloud.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helmforge
{{ with .Values.commonLabels }}{{ toYaml . }}{{- end }}
{{- end -}}
{{- define "opencloud.serviceAccountName" -}}{{- if .Values.serviceAccount.create -}}{{- default (include "opencloud.fullname" .) .Values.serviceAccount.name -}}{{- else -}}{{- default "default" .Values.serviceAccount.name -}}{{- end -}}{{- end -}}
{{- define "opencloud.image" -}}{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}{{- end -}}



{{- define "opencloud.claimName" -}}{{- default (include "opencloud.fullname" .) .Values.persistence.existingClaim -}}{{- end -}}
{{- define "opencloud.bootstrapSecretName" -}}{{- default (printf "%s-bootstrap" (include "opencloud.fullname" . | trunc 53 | trimSuffix "-")) .Values.bootstrap.existingSecret -}}{{- end -}}
{{- define "opencloud.externalSecretName" -}}{{- if .item.fullnameOverride -}}{{ .item.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ printf "%s-%s" (include "opencloud.fullname" .root | trunc 40 | trimSuffix "-") (.item.name | default "bootstrap") | trunc 63 | trimSuffix "-" }}{{- end -}}{{- end -}}
{{- define "opencloud.metricsSecretName" -}}{{- default (printf "%s-metrics" (include "opencloud.fullname" . | trunc 55 | trimSuffix "-")) .Values.metrics.existingSecret -}}{{- end -}}
{{- define "opencloud.validate" -}}
{{- if and .Values.gatewayAPI.enabled (not .Values.gatewayAPI.httpRoutes) -}}{{ fail "gatewayAPI.httpRoutes is required" }}{{- end -}}
{{- if and .Values.server.backendTLS.useSystemCAs .Values.server.backendTLS.caCertificateRefs -}}{{ fail "Backend TLS requires either system or custom CA trust" }}{{- end -}}
{{- if and .Values.gatewayAPI.enabled .Values.server.tls.enabled (not .Values.server.backendTLS.enabled) -}}{{ fail "Native HTTPS Gateway backends require BackendTLSPolicy" }}{{- end -}}
{{- if and .Values.gatewayAPI.enabled .Values.server.tls.enabled .Values.server.tls.existingSecret (not (or .Values.server.backendTLS.useSystemCAs .Values.server.backendTLS.caCertificateRefs)) -}}{{ fail "Existing TLS Secret requires explicit Gateway backend CA trust" }}{{- end -}}
{{- if and (not .Values.metrics.enabled) (or .Values.metrics.serviceMonitor.enabled .Values.metrics.prometheusRule.enabled) -}}{{ fail "Metrics must be enabled for ServiceMonitor or PrometheusRule" }}{{- end -}}
{{- if has (int .Values.metrics.port) (list (int .Values.server.port) 9205) -}}{{ fail "Metrics port must differ from application and debug ports" }}{{- end -}}
{{- range $labels := list .Values.podLabels .Values.commonLabels -}}{{- range $key, $_ := $labels -}}{{- if has $key (list "app.kubernetes.io/name" "app.kubernetes.io/instance") -}}{{ fail "Custom labels cannot override workload selectors" }}{{- end -}}{{- end -}}{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}{{ fail "OpenCloud requires one monolithic replica" }}{{- end -}}
{{- if and (not .Values.server.publicUrl) (ne (int .Values.server.port) (int .Values.service.port)) -}}{{ fail "Set server.publicUrl when Service and application ports differ" }}{{- end -}}
{{- if and (not .Values.server.publicUrl) (not .Values.server.tls.enabled) -}}{{ fail "Set the external HTTPS server.publicUrl when native TLS is disabled" }}{{- end -}}
{{- if and .Values.server.publicUrl (not (hasPrefix "https://" .Values.server.publicUrl)) -}}{{ fail "OpenCloud public URL requires HTTPS" }}{{- end -}}
{{- if and .Values.bootstrap.password .Values.bootstrap.existingSecret -}}{{ fail "Bootstrap password and existing Secret are mutually exclusive" }}{{- end -}}
{{- range .Values.extraEnv -}}{{- if has .name (list "OC_URL" "OC_INSECURE" "OC_CONFIG_DIR" "OC_BASE_DATA_PATH" "IDM_CREATE_DEMO_USERS" "IDM_ADMIN_PASSWORD" "PROXY_TLS" "PROXY_HTTP_ADDR" "PROXY_DEBUG_ADDR" "PROXY_DEBUG_TOKEN" "PROXY_DEBUG_PPROF" "PROXY_DEBUG_ZPAGES" "SSL_CERT_FILE" "PROXY_OIDC_INSECURE" "AUTH_BEARER_OIDC_INSECURE" "PROXY_ENABLE_BASIC_AUTH" "PROXY_TRANSPORT_TLS_CERT" "PROXY_TRANSPORT_TLS_KEY" "OC_FORCE_CONFIG_OVERWRITE") -}}{{ fail (printf "extraEnv cannot override managed setting %s" .name) }}{{- end -}}{{- end -}}
{{- end -}}
{{- define "opencloud.nativeEnvironment" -}}
- {name: OC_URL, value: {{ include "opencloud.publicUrl" . | quote }}}
- {name: OC_INSECURE, value: 'false'}
- {name: PROXY_OIDC_INSECURE, value: 'false'}
- {name: AUTH_BEARER_OIDC_INSECURE, value: 'false'}
- {name: PROXY_ENABLE_BASIC_AUTH, value: 'false'}
- {name: OC_FORCE_CONFIG_OVERWRITE, value: 'false'}
- {name: OC_CONFIG_DIR, value: /etc/opencloud}
- {name: OC_BASE_DATA_PATH, value: /var/lib/opencloud}
- {name: IDM_CREATE_DEMO_USERS, value: 'false'}
- {name: PROXY_TLS, value: {{ .Values.server.tls.enabled | quote }}}
{{- if .Values.server.tls.enabled }}
- {name: PROXY_TRANSPORT_TLS_CERT, value: /tls/tls.crt}
- {name: PROXY_TRANSPORT_TLS_KEY, value: /tls/tls.key}
{{- end }}
- {name: PROXY_HTTP_ADDR, value: {{ printf "0.0.0.0:%v" .Values.server.port | quote }}}
- {name: PROXY_DEBUG_ADDR, value: '127.0.0.1:9205'}
- {name: OC_LOG_LEVEL, value: info}
- {name: OC_LOG_PRETTY, value: 'false'}
- {name: SSL_CERT_FILE, value: /runtime-trust/ca.crt}
{{- with .Values.extraEnv }}{{ toYaml . | nindent 0 }}{{- end }}
{{- end -}}
{{- define "opencloud.mounts" -}}
- {name: workspace, mountPath: /etc/opencloud, subPath: config}
- {name: workspace, mountPath: /var/lib/opencloud, subPath: data}
- {name: tmp, mountPath: /tmp}
- {name: runtime-trust, mountPath: /runtime-trust, readOnly: true}
{{- if .Values.server.tls.enabled }}
- {name: tls, mountPath: /tls, readOnly: true}
{{- end }}
{{- if .Values.server.trustedCaSecret }}
- {name: trusted-ca, mountPath: /trusted-ca, readOnly: true}
{{- end }}
{{- end -}}

{{- define "opencloud.publicUrl" -}}{{- default (printf "https://%s.%s.svc:%v" (include "opencloud.fullname" .) .Release.Namespace .Values.service.port) .Values.server.publicUrl -}}{{- end -}}
{{- define "opencloud.tlsSecretName" -}}{{- default (printf "%s-tls" (include "opencloud.fullname" . | trunc 59 | trimSuffix "-")) .Values.server.tls.existingSecret -}}{{- end -}}

{{- define "opencloud.httpRouteName" -}}
{{- if .route.name -}}{{ .route.name | trunc 63 | trimSuffix "-" }}{{- else if gt (int .index) 0 -}}{{ printf "%s-%v" (include "opencloud.fullname" .root | trunc 55 | trimSuffix "-") .index }}{{- else -}}{{ include "opencloud.fullname" .root }}{{- end -}}
{{- end -}}

{{- define "opencloud.generatedTLSData" -}}
{{- if not (hasKey . "_opencloudTLSData") -}}
{{- $name := include "opencloud.tlsSecretName" . }}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name }}
{{- $data := $existing.data | default dict }}
{{- if not $data }}
{{- $host := (urlParse (include "opencloud.publicUrl" .)).hostname }}
{{- $ca := genCA (printf "%s-private-ca" (include "opencloud.fullname" .)) 365 }}
{{- $cert := genSignedCert $host nil (list $host (include "opencloud.fullname" .) (printf "%s.%s.svc" (include "opencloud.fullname" .) .Release.Namespace)) 365 $ca }}
{{- $_ := set $data "tls.crt" ($cert.Cert | b64enc) }}
{{- $_ := set $data "tls.key" ($cert.Key | b64enc) }}
{{- $_ := set $data "ca.crt" ($ca.Cert | b64enc) }}
{{- end }}

{{- $_ := set . "_opencloudTLSData" $data }}
{{- end }}
{{- toYaml ._opencloudTLSData }}
{{- end -}}
