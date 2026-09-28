<!-- markdownlint-disable MD013 -->

# Security model

## Container boundary

The container runs as UID/GID 1001 with a read-only root filesystem, no privilege escalation, no Linux capabilities, and RuntimeDefault seccomp. Only `/app/data` and `/tmp` are writable. The ServiceAccount token is not mounted.

## Sensitive values

Use `secrets.existingSecret` or External Secrets in production. Inline values are intended for local validation and become part of Helm release state.

The JWT master integration can impersonate mailboxes. Keep it disabled unless required, restrict network access to the calling platform, and rotate both signing and master credentials on suspected exposure.

## Network policy

Enable NetworkPolicy only when the cluster enforces it. The base egress policy allows DNS and configured JMAP ports. Add rules for every enabled external integration, such as OAuth discovery, update checks, extension marketplace, translation provider, or push relay.

## Telemetry

Telemetry defaults explicitly to `off`. Setting it in values locks the upstream choice. Persisting `/app/data/telemetry` retains consent state and instance identity across upgrades.

## Supply chain

The chart pins the official multi-architecture image tag and validates its registry manifest. HelmForge releases are signed through the repository release process. Review upstream release notes before overriding the image tag.

<!-- @AI-METADATA
type: chart-docs
title: Bulwark Mail security
description: Runtime, credentials, networking, and supply-chain posture
keywords: bulwark, security, secrets, networkpolicy
purpose: Operate Bulwark Mail securely
scope: Chart
relations:
  - charts/bulwark-mail/README.md
path: charts/bulwark-mail/docs/security.md
version: 1.0
date: 2026-09-28
-->
