<!-- SPDX-License-Identifier: Apache-2.0 -->

# ChiefOnboarding Security Guide

## Default controls

The chart pins the official ChiefOnboarding 2.5.0 image by manifest digest,
disables Kubernetes API token mounting, selects `RuntimeDefault` seccomp,
forbids privilege escalation, and drops every Linux capability. HTTP probes use
the real application listener and the NetworkPolicy isolates application
ingress by default.

The official image explicitly starts Supervisor and both child processes as
root. It also writes collected static files and Supervisor state into image
paths. `runAsNonRoot: false` and `readOnlyRootFilesystem: false` are therefore
documented compatibility exceptions. Test a future upstream image before
tightening either field; do not set controls that only make the pod crash.

## Secrets

Production deployments should provide `chiefonboarding.existingSecret` and a
database Secret through either the bundled PostgreSQL contract or
`database.external.existingSecret`. Use `chiefonboarding.extraEnv` with
`secretKeyRef` entries for SMTP, Slack, OIDC, S3, and custom integration
credentials.

The default `chiefonboarding.allowedHosts` accepts local port-forward traffic.
Every Ingress deployment must replace or extend it with the public hostname;
Django rejects unlisted Host headers before request routing.

When the chart generates the Django secret key, it reuses the live Secret on
upgrade and marks that Secret for retention on uninstall. Back it up with the
database. Deleting or changing it invalidates sessions, password reset links,
and CSRF tokens.

Helm can roll the pod when values or Secret references change, but it cannot
hash data owned by an external Secret controller. Restart the Deployment after
external Secret rotation and verify login plus a background workflow.

## Network isolation

`networkPolicy.enabled` defaults to `true` and applies only to ingress. It
allows pods from the same Helm release and any peers in
`networkPolicy.ingressFrom`. Add a namespace and, when possible, pod selector
for the ingress controller. A NetworkPolicy-capable CNI is required.

Egress remains unrestricted because supported deployments use different SMTP,
Slack, identity, S3, and webhook destinations. Apply platform egress policy
only after enumerating those endpoints; portable Kubernetes NetworkPolicy
cannot select DNS names.

## Production checklist

- Terminate public traffic with TLS and set the exact public `baseUrl`.
- Store all credentials outside Git and restrict Secret RBAC.
- Keep the image digest pin and review upstream release notes before upgrades.
- Set measured CPU and memory requests and limits.
- Back up and restore-test PostgreSQL plus the application Secret.
- Audit failed logins, administrator changes, integration activity, and pod
  restarts.
