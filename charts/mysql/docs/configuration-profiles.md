# Configuration Profiles

## Goal

This chart keeps configuration UX intentionally small. Use presets first, then add targeted raw overrides through `config.myCnf` only when needed.

## `config.preset`

Supported presets:

- `none`: no opinionated database tuning
- `small`, `medium`, `large`: coarse sizing-oriented defaults
- `oltp`: write-heavy transactional workloads
- `read-heavy`: read-dominant application traffic
- `analytics`: larger temporary tables and heavier analytical reads

These presets are starting points, not workload guarantees. Validate them against your own storage, memory limits, and concurrency profile.

## Resource presets

The chart exposes resource presets independently for:

- `standalone.resourcesPreset`
- `replication.source.resourcesPreset`
- `replication.readReplicas.resourcesPreset`
- `metrics.resourcesPreset`

This keeps resource sizing explicit per topology role instead of trying to infer environment size from one global switch.

## Secret scope

`auth.existingSecret` remains intentionally limited to passwords:

- root password
- application user password
- replication user password

Database names and usernames remain plain values on purpose. That keeps bootstrap behavior predictable and avoids turning every non-sensitive bootstrap parameter into secret indirection.
