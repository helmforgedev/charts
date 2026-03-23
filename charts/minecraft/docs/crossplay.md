# Cross-Play Guide (GeyserMC)

## When to Use

Allow Bedrock Edition clients (mobile, console, Windows 10/11) to connect to a Java Edition server using GeyserMC as a protocol translation layer.

## What This Delivers

- Java Edition server accessible from both Java and Bedrock clients
- GeyserMC plugin installed via Modrinth
- Floodgate plugin for Xbox Live authentication (Bedrock players do not need a Java account)
- UDP port 19132 exposed for Bedrock clients alongside TCP port 25565 for Java clients

## How It Works

```
Java Client (TCP 25565) ──────────────────┐
                                          ├──> Paper Server
Bedrock Client (UDP 19132) ──> GeyserMC ──┘
                               (plugin)
```

GeyserMC runs as a Paper/Spigot plugin and translates Bedrock protocol packets into Java protocol packets. Floodgate allows Bedrock players to authenticate with their Xbox Live account without needing a separate Java account.

## Requirements

- `server.type` must be `PAPER`, `SPIGOT`, or another plugin-compatible server
- GeyserMC and Floodgate plugins must be installed (via `mods.modrinthProjects`)
- The Kubernetes Service must expose both TCP (Java) and UDP (Bedrock) ports

## Example Configuration

```yaml
server:
  eula: true
  type: PAPER
  version: LATEST
  motd: "Cross-Play Server"
  maxPlayers: 30

jvm:
  memory: 3G
  useAikarFlags: true

geyser:
  enabled: true
  port: 19132

mods:
  modrinthProjects: "geyser,floodgate"

auth:
  onlineMode: true
  whitelist: "java_player,bedrock_player"
  enforceWhitelist: true

rcon:
  enabled: true

persistence:
  enabled: true
  size: 20Gi

resources:
  requests:
    cpu: "1"
    memory: 3Gi
  limits:
    cpu: "2"
    memory: 6Gi
```

## Important Notes

- **UDP load balancers** — some cloud providers have limited UDP LoadBalancer support. Consider `externalTrafficPolicy: Local` or NodePort for Bedrock traffic.
- **Bedrock player names** — Floodgate prefixes Bedrock player names with `.` by default to avoid conflicts with Java names.
- **Whitelist** — Bedrock players may need to be whitelisted with their prefixed name (e.g., `.bedrock_player`).
- **Performance overhead** — GeyserMC adds modest CPU and memory overhead for protocol translation.
- **Feature parity** — not all Java features translate perfectly to Bedrock. Some visual differences are expected.

## Common Risks

- **Firewall rules** — ensure UDP 19132 is allowed through network policies and cloud firewalls
- **Service type** — `LoadBalancer` services may not support mixed TCP/UDP on the same IP in all environments
- **Plugin updates** — GeyserMC and Floodgate should be kept updated together

<!-- @AI-METADATA
type: chart-docs
title: Cross-Play Guide (GeyserMC)
description: Guide for enabling Bedrock cross-play on Java Edition servers using GeyserMC
keywords: minecraft, geyser, geysermc, floodgate, bedrock, crossplay, cross-play
purpose: Architecture-specific guidance for GeyserMC cross-play deployments
scope: Chart
relations:
  - charts/minecraft/README.md
  - charts/minecraft/docs/vanilla-and-paper.md
path: charts/minecraft/docs/crossplay.md
version: 1.0
date: 2026-03-23
-->
