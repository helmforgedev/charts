# Gophish Security Research

Research date: 2026-04-28

## Security Posture

Gophish is designed for authorized phishing awareness and security testing. The chart documentation and defaults must reinforce defensive, approved use only.

The chart should be conservative because Gophish has two different security surfaces:

- privileged admin UI
- public campaign listener

## Admin Exposure

Upstream defaults:

- admin server listens on port `3333`
- admin server uses TLS by default in `config.json`
- admin credentials are printed in startup logs on first run
- first login forces a password change

The upstream guide warns that exposing the admin server externally should only be done when needed and recommends changing the default password before exposure.

Chart decisions:

- `adminIngress.enabled` defaults to `false`.
- Admin access documentation should start with `kubectl port-forward`.
- Admin ingress must require explicit host configuration.
- Add validation or warnings when admin ingress is enabled without TLS.
- Document how to retrieve the initial password from pod logs without storing it in values.
- Do not create a default admin password Secret because upstream bootstraps it.

## Initial Password Handling

Upstream log pattern:

```text
Please login with the username admin and the password <generated-password>
```

Chart documentation should show the command pattern, not a real password:

```bash
kubectl logs deploy/<release-name>-gophish | grep "Please login with the username admin"
```

Security implications:

- Startup logs contain a sensitive one-time credential.
- Operators should rotate the password immediately through the UI.
- Log retention systems may capture the initial password.

Chart documentation should include a hardening note for log retention and first-login handling.

## Configuration Secret

Gophish `config.json` can contain database credentials. The upstream guide explicitly treats `config.json` as sensitive.

Chart decisions:

- Render generated `config.json` as a Kubernetes Secret.
- Support `gophish.config.existingSecret`.
- Avoid ConfigMap for generated config.
- Avoid printing rendered config in NOTES or examples when credentials are present.

The official Docker entrypoint prints runtime configuration before starting the app. If the chart renders MySQL credentials into `config.json`, runtime validation must confirm whether the entrypoint logs the DSN. If it does, Phase 3 should either:

- bypass the mutating entrypoint with a safer command, or
- avoid putting sensitive DSNs into files that the entrypoint prints, if technically feasible.

This is a blocker-level implementation concern for MySQL support.

## Pod Security

The official image runs as user `app` and sets `cap_net_bind_service` on the binary so the non-root process can bind port `80`.

Recommended chart defaults:

- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `seccompProfile.type: RuntimeDefault`
- drop all Linux capabilities at the container level where compatible
- keep `readOnlyRootFilesystem` disabled until runtime validation proves required writable paths are isolated

Runtime validation must confirm:

- the `app` user can read mounted config
- the `app` user can write the SQLite database path
- the `app` user can write any required temp config file
- the container can bind port `80` under the chosen security context

## Network Security

Recommended NetworkPolicy model:

- allow ingress to phishing service from ingress controller namespaces or explicit CIDRs
- allow ingress to admin service only from trusted namespaces, CIDRs, or port-forward workflows
- allow egress to DNS
- allow egress to external MySQL when configured
- allow egress to SMTP only when SMTP is configured in later values

Admin and phishing Services should have separate selectors or separate Service ports targeting the same pod, but NetworkPolicy should still distinguish traffic by port.

## TLS and Trusted Origins

Gophish supports native TLS fields:

- `admin_server.use_tls`
- `admin_server.cert_path`
- `admin_server.key_path`
- `phish_server.use_tls`
- `phish_server.cert_path`
- `phish_server.key_path`

Gophish `v0.12.1` adds `admin_server.trusted_origins`, useful when TLS termination happens at an upstream load balancer or ingress.

Chart decisions:

- Prefer Kubernetes ingress TLS termination.
- Keep native Gophish TLS advanced and explicit.
- Expose trusted origins as values for admin CSRF handling behind ingress.
- Document that TLS termination and trusted origins must be aligned.

## Vulnerability Awareness

GitHub Advisory Database lists CVE-2024-55196 against Gophish versions up to and including `0.12.1`, with no patched version listed at research time.

Chart implication:

- The chart may still use `0.12.1` because it is the current upstream release target, but documentation should include an operational security note.
- Admin access should remain private by default.
- Operators should track upstream releases and advisories.
- Do not imply HelmForge patches upstream application vulnerabilities.

Reference:

- https://github.com/advisories/GHSA-rv83-h68q-c4wq

## Existing Chart Gap Analysis

No relevant public Helm chart was found in:

- Artifact Hub package search for `gophish`
- GitHub repository search for `gophish helm chart`
- GitHub code search for `gophish Chart.yaml`

Security gaps HelmForge should address:

- clear admin/public traffic separation
- default-disabled admin ingress
- Secret-based config rendering
- existing Secret support
- explicit NetworkPolicy
- non-root security context validation
- documented bootstrap password handling
- documented advisory awareness
- backup scope clarity

## References

- Gophish release `v0.12.1`: https://github.com/gophish/gophish/releases/tag/v0.12.1
- Gophish default config: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/config.json
- Gophish Dockerfile: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/Dockerfile
- Gophish Docker entrypoint: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/docker/run.sh
- Gophish installation guide: https://github.com/gophish/user-guide/blob/master/installation.md
- GitHub advisory: https://github.com/advisories/GHSA-rv83-h68q-c4wq
- HelmForge security baseline MCP resource

<!-- @AI-METADATA
type: chart-docs
title: Gophish - Security Research
description: Security posture and hardening research for the Gophish HelmForge chart

keywords: gophish, security, admin, networkpolicy, tls, kubernetes

purpose: Define security defaults and risks for the Gophish chart
scope: Chart Research

relations:
  - charts/gophish/docs/architecture.md
  - charts/gophish/docs/database.md
path: charts/gophish/docs/security.md
version: 1.0
date: 2026-04-28
-->
