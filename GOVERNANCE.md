# Governance

HelmForge is an open-source project for production-oriented Helm charts and related packaging workflows for Kubernetes.

This document describes how the project is governed, how decisions are made, and how contributors can grow into project leadership.

## Values

HelmForge is guided by these values:

- **Open source first**: charts, docs, tests, and release automation should remain open and usable without a paid tier.
- **Vendor neutrality**: the project should avoid unnecessary lock-in to a commercial runtime, registry, image ecosystem, or hosting provider.
- **Upstream alignment**: charts should prefer official upstream images and documented upstream behavior.
- **Operational honesty**: charts should be explicit about what they do and do not manage. A Helm chart should not pretend to be an operator.
- **Verifiable releases**: published artifacts should be reproducible, signed, and easy to verify.
- **Practical defaults**: defaults should be useful for real Kubernetes operations while avoiding unsafe claims about production readiness.
- **Respectful community**: participation should follow the project Code of Conduct.

## Scope

In scope:

- Helm charts under `charts/`
- chart values contracts, JSON schemas, tests, examples, and documentation
- release automation for packaged charts
- Helm repository and OCI distribution workflows
- project website and documentation content related to HelmForge
- supporting images or tools that are directly required by HelmForge charts
- governance, contribution, security, and community processes

Out of scope:

- becoming a hosted platform or commercial control plane
- replacing Helm, Kubernetes, GitOps controllers, or domain-specific operators
- providing support guarantees or SLAs
- maintaining forks of upstream applications except when a narrowly-scoped support image is explicitly documented
- hiding commercial or proprietary functionality behind the open-source project

## Roles

### Users

Users deploy HelmForge charts and may report issues, request charts, suggest improvements, or provide adoption feedback.

### Contributors

Contributors submit issues, documentation, examples, tests, chart changes, or review feedback.

### Maintainers

Maintainers have write access to project repositories and are responsible for review, merge decisions, releases, quality gates, and project direction.

Current maintainers are listed in [MAINTAINERS.md](MAINTAINERS.md).

## Decision Making

HelmForge uses lazy consensus for most decisions.

A proposal is considered accepted when:

- it is made in a public issue, pull request, or discussion
- maintainers and contributors have had reasonable time to respond
- no maintainer has raised a blocking objection
- required checks and review expectations are satisfied

Maintainers should seek explicit agreement for changes that affect:

- project scope
- governance
- licensing
- security policy
- release signing
- chart standards
- public compatibility promises
- CNCF application or foundation-related commitments

If consensus cannot be reached, maintainers should document the disagreement and make a decision based on project values, user impact, maintainability, and security.

## Pull Request Review

Chart changes should follow [CONTRIBUTING.md](CONTRIBUTING.md) and pass the required validation workflow.

Maintainers may merge changes when:

- CI passes or failures are understood and documented
- the change follows chart standards
- user-visible behavior is documented
- tests and schemas are updated when behavior or values change
- release and site sync implications are understood

Substantial changes should receive maintainer review before merge. Urgent security fixes, release automation repairs, and mechanical documentation updates may be merged faster when needed.

## Releases

Chart releases are automated through GitHub Actions.

Maintainers do not manually create chart release tags or edit chart versions for normal releases. Conventional Commits drive chart semantic versioning and release notes.

Published charts are distributed through:

- HTTPS Helm repository: <https://repo.helmforge.dev>
- OCI registry: `ghcr.io/helmforgedev/helm`
- Artifact Hub: <https://artifacthub.io/packages/search?repo=helmforge>

Release integrity is part of project governance. Signing, provenance, and publishing workflows should be treated as protected project infrastructure.

## Security

Security reporting and response expectations are defined in [SECURITY.md](SECURITY.md).

Security-sensitive issues should not be discussed publicly until maintainers have assessed the report and coordinated an appropriate disclosure path.

## Code of Conduct

All project participants are expected to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

Maintainers may take moderation or enforcement action when needed to protect contributors, users, and project spaces.

## Changes To Governance

Governance changes should be proposed through a pull request and should receive explicit maintainer approval before merge.

When HelmForge is accepted into a foundation or changes its legal or governance obligations, this document should be updated to reflect the new requirements.

<!-- @AI-METADATA
type: guide
title: Governance
description: Governance model, project scope, values, roles, and decision process

keywords: governance, maintainers, decision-making, scope, cncf

purpose: Document how HelmForge is governed and how project decisions are made
scope: Repository

relations:
  - MAINTAINERS.md
  - CODE_OF_CONDUCT.md
  - CONTRIBUTING.md
  - SECURITY.md
  - ADOPTERS.md
path: GOVERNANCE.md
version: 1.0
date: 2026-04-27
-->
