# Security Policy

## Supported Versions

We provide security fixes for the **latest released version** of each chart.
Older versions are not actively maintained.

## Reporting a Vulnerability

If you discover a security vulnerability in any HelmForge chart, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, use one of the following methods:

1. **GitHub Security Advisories** (preferred): [Report a vulnerability](https://github.com/helmforgedev/charts/security/advisories/new)
2. **Email**: <berlofa@helmforge.dev> or <maicon.berloffa@gmail.com>

### What to include

- Chart name and version affected
- Description of the vulnerability
- Steps to reproduce (if applicable)
- Potential impact

### Response timeline

- **Acknowledgment**: within 72 hours
- **Initial assessment**: within 7 days
- **Fix or mitigation**: best effort, typically within 30 days depending on severity

## Scope

This policy covers vulnerabilities in:

- Helm chart templates and default configurations
- CI/CD workflows in this repository
- Default `values.yaml` settings that introduce security risks

This policy does **not** cover:

- Vulnerabilities in upstream application images (report those to the upstream project)
- Misconfiguration by end users in their own `values.yaml` overrides
- Infrastructure or cluster-level security issues

## Security Best Practices

When deploying HelmForge charts in production:

- Always pin chart versions (`--version`)
- Review `values.yaml` defaults before deploying
- Use `securityContext` and `podSecurityContext` settings provided by each chart
- Enable network policies where your cluster supports them
- Use TLS for ingress endpoints
- Rotate credentials and secrets regularly
