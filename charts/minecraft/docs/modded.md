# Modded Servers Guide

## When to Use

Deploy a modded Minecraft server using Forge, Fabric, Quilt, or modpack platforms like CurseForge and Modrinth.

## What This Delivers

- Minecraft server with mod loader support
- Automatic mod/modpack download and installation
- Higher resource allocation for modded workloads
- Persistent storage for mods, configs, and world data

## Supported Mod Loaders

| Type | Value | Best For |
|------|-------|----------|
| Forge | `FORGE` | Large mod ecosystem, established modpacks |
| Fabric | `FABRIC` | Lightweight, performance-focused mods |
| Quilt | `QUILT` | Community-driven Fabric alternative |
| Auto CurseForge | `AUTO_CURSEFORGE` | One-click CurseForge modpack install |

## Mod Installation Methods

### Modrinth Projects

```yaml
server:
  type: FABRIC
mods:
  modrinthProjects: "lithium,sodium,starlight"
```

### CurseForge Modpacks

```yaml
server:
  type: AUTO_CURSEFORGE
mods:
  curseforgeApiKey: "$2a$10$..."
  autoCurseforgeSlug: "all-the-mods-9"
```

### Direct Download URLs

```yaml
mods:
  downloadUrls: |
    https://example.com/mod1.jar
    https://example.com/mod2.jar
```

## Example Configuration

```yaml
server:
  eula: true
  type: FORGE
  version: "1.20.4"
  motd: "Modded Server"
  maxPlayers: 20
  allowFlight: true

jvm:
  memory: 6G
  useAikarFlags: true

rcon:
  enabled: true

persistence:
  enabled: true
  size: 30Gi

resources:
  requests:
    cpu: "1"
    memory: 6Gi
  limits:
    cpu: "4"
    memory: 10Gi

startupProbe:
  failureThreshold: 60

terminationGracePeriodSeconds: 180
```

## Important Notes

- **Startup time** — modded servers take significantly longer to start. Increase `startupProbe.failureThreshold` to 60 or higher.
- **Memory requirements** — modded servers typically need 4-10G depending on the modpack. Set `jvm.memory` accordingly.
- **Allow flight** — many mods add flight mechanics. Set `server.allowFlight: true` to avoid false kicks.
- **Version pinning** — always pin `server.version` for modded servers to avoid incompatible updates.
- **Persistence** — mods and configs are stored in `/data`. Always enable persistence.

## Common Risks

- **Version mismatch** — mods must match the exact server version
- **Memory exhaustion** — large modpacks can exceed allocated memory
- **Slow startup** — first launch downloads and installs all mods
- **Mod conflicts** — incompatible mods can crash the server silently

<!-- @AI-METADATA
type: chart-docs
title: Modded Servers Guide
description: Guide for deploying Forge, Fabric, and modpack Minecraft servers
keywords: minecraft, forge, fabric, quilt, mods, modpack, curseforge, modrinth
purpose: Architecture-specific guidance for modded Minecraft server deployments
scope: Chart
relations:
  - charts/minecraft/README.md
  - charts/minecraft/docs/vanilla-and-paper.md
path: charts/minecraft/docs/modded.md
version: 1.0
date: 2026-03-23
-->
