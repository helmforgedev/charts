# Vanilla & Paper Server Guide

## When to Use

- **Vanilla** — Official Mojang experience with no modifications
- **Paper** — Recommended for production: better performance, plugin support, Aikar GC flags

## What This Delivers

- Single Minecraft server instance running as a Kubernetes Deployment
- Persistent world data on a PVC
- RCON for remote administration
- Optional whitelist and operator management
- Optional Prometheus metrics via mc-monitor

## What It Does Not Deliver

- Horizontal scaling (Minecraft is single-threaded)
- Multi-server proxy (use Velocity/BungeeCord separately)
- Mod support (use Forge/Fabric instead)

## Paper Production Recommendations

1. **Use Aikar's GC flags** — set `jvm.useAikarFlags: true` for optimized garbage collection
2. **Allocate adequate memory** — 4G+ for 20+ players, 8G+ for 50+ players
3. **Reduce view distance** — set `server.viewDistance: 8` to reduce server load
4. **Enable whitelist** — protect your server from unauthorized access
5. **Pre-generate world** — prevents CPU spikes from chunk generation during gameplay

## Example Configuration

```yaml
server:
  eula: true
  type: PAPER
  version: LATEST
  difficulty: normal
  maxPlayers: 30
  viewDistance: 8
  simulationDistance: 8

jvm:
  memory: 4G
  useAikarFlags: true

auth:
  onlineMode: true
  whitelist: "player1,player2"
  enforceWhitelist: true
  ops: "player1"

rcon:
  enabled: true
  existingSecret: minecraft-rcon

persistence:
  enabled: true
  size: 30Gi

resources:
  requests:
    cpu: "1"
    memory: 4Gi
  limits:
    cpu: "4"
    memory: 8Gi

terminationGracePeriodSeconds: 180
```

## Resource Sizing

| Players | Memory | CPU Request | Storage |
|---------|--------|-------------|---------|
| 1-5 | 1G | 500m | 10Gi |
| 5-10 | 2G | 1000m | 10Gi |
| 10-20 | 3G | 1000m | 20Gi |
| 20-50 | 4-8G | 2000m | 30Gi |
| 50+ | 8G+ | 2000m+ | 50Gi+ |

Set `jvm.memory` to approximately 75% of the container memory limit to leave room for the JVM overhead and operating system.

## Common Risks

- **Insufficient memory** — the server will lag or crash under load
- **Large view distance** — increases CPU and memory usage significantly
- **No whitelist** — public servers attract griefers and bots
- **Missing backups** — world corruption or accidental deletion is unrecoverable without backups

## When to Move to Another Setup

- Need mods → switch to `server.type: FORGE` or `FABRIC` (see [Modded Servers](modded.md))
- Need Bedrock cross-play → enable GeyserMC (see [Cross-Play](crossplay.md))
- Need multiple connected servers → deploy a Velocity/BungeeCord proxy separately

<!-- @AI-METADATA
type: chart-docs
title: Vanilla & Paper Server Guide
description: Operational guide for deploying Vanilla and Paper Minecraft servers with the minecraft Helm chart
keywords: minecraft, vanilla, paper, production, jvm, aikar, whitelist
purpose: Architecture-specific guidance for Vanilla and Paper server deployments
scope: Chart
relations:
  - charts/minecraft/README.md
  - charts/minecraft/docs/modded.md
  - charts/minecraft/docs/crossplay.md
path: charts/minecraft/docs/vanilla-and-paper.md
version: 1.0
date: 2026-03-23
-->
