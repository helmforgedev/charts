# Credentials and network isolation

## API credential ownership

Default installation generates a 48-character random API key. Live Helm upgrades reuse the existing Secret value.
Render-only GitOps controllers should use an existing Secret to avoid unstable random rendering. The chart never
accepts inline API or Hub credentials in values. Secret encryption at rest and access controls are cluster concerns.

For rotation, update the source Secret and restart the Deployment. API clients and server must coordinate because
the native API accepts one key at a time. Keep secrets out of shell history, debug traces and issue attachments.
Changing the Secret key name or deleting a generated Secret can change credentials on the next reconciliation.

## External Secrets Operator

Install ESO and an authorized SecretStore first. Each `externalSecrets.items[]` object supports name/metadata
overrides and the upstream `spec` contract, including data/dataFrom and source references. The chart supplies
default refresh interval and target name only when omitted. Reference that target through `auth.existingSecret`.
A separate item can provide the Hub token; the two credentials have unrelated trust and rotation lifecycles.

After installation, inspect ExternalSecret readiness and verify that the target Secret contains the configured
key. Do not print its value. ESO updates do not modify existing process environment; trigger a Pod rollout after
rotation. The CI fake-store profile verifies a real reconciled Secret and authenticated inference.

## Native logging

The pinned TEI release logs parsed arguments, including API_KEY, at INFO. The chart enforces LOG_LEVEL=warn,
preserves warning/error output and disallows chart-owned environment overrides. This is a version-specific
mitigation and should be revisited against upstream code during upgrades. Do not enable verbose native logging
with live credentials while investigating startup failures.

## Listeners and peers

Native TEI binds to loopback port 8081. NGINX exposes the API on 8080 and blocks `/metrics`, `/docs` and `/api-doc`.
The optional 9464 listener permits only `/metrics` and has a separate Service. No bearer key is required for those
native metrics; `metrics.ingressFrom` must explicitly identify trusted monitoring peers.

NetworkPolicy enforcement requires a CNI that implements it. Disabling the policy removes the monitoring network
boundary even though the public proxy still blocks metric paths. Namespace selectors and Pod selectors in the
same peer are conjunctive; separate peer entries are alternatives. Use both to select a specific Prometheus
workload in a specific namespace. Ingress-controller permissions are independent of monitoring permissions.

TLS terminates at an existing ingress or Gateway. The chart's internal Service is HTTP; use suitable cluster
transport controls when internal encryption is required. Health paths remain public for readiness. API-key
authentication supplies shared access control, not tenancy, per-user audit identity or client rate quotas.
