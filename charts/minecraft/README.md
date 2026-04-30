# Minecraft Server

A Helm chart for deploying Minecraft Java Edition servers on Kubernetes using the [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/) container image.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install minecraft helmforge/minecraft --set server.eula=true
```

### OCI Registry

```bash
helm install minecraft oci://ghcr.io/helmforgedev/helm/minecraft --set server.eula=true
```

> **Important:** You must set `server.eula=true` to accept the [Minecraft EULA](https://www.minecraft.net/en-us/eula). The server will not start without it.

## Quick Start

```bash
helm install minecraft oci://ghcr.io/helmforgedev/helm/minecraft \
  --set server.eula=true \
  --set server.motd="My Server" \
  --set jvm.memory=2G
```

## Features

- **Multiple Server Types** — Vanilla, Paper, Spigot, Forge, Fabric, Quilt, and more via the `server.type` value
- **GeyserMC Cross-Play** — Allow Bedrock (mobile, console) clients to join Java servers
- **Authentication & Access Control** — Online/offline mode, whitelist, operators
- **RCON Remote Console** — Enabled by default with auto-generated password
- **Persistent Storage** — PVC for world data, configs, plugins, and mods
- **Scheduled Backups** — CronJob-based backup to S3-compatible storage with RCON save coordination
- **Prometheus Monitoring** — mc-monitor sidecar with ServiceMonitor support
- **Mod/Plugin Management** — Modrinth, CurseForge, Spiget, and direct URL downloads
- **Optimized JVM** — Aikar's GC flags for production workloads
- **Server Resource Pack** — URL-based with SHA-1 verification and enforcement
- **Dual-stack** — `ipFamilyPolicy`/`ipFamilies` on the game and RCON Services for IPv4/IPv6 clusters
- **ExternalSecrets** — opt-in `ExternalSecret` to source the RCON password from an external secrets store

## Supported Server Types

| Type | Value | Description |
|------|-------|-------------|
| Vanilla | `VANILLA` | Official Mojang server (default) |
| Paper | `PAPER` | High-performance Spigot fork (recommended for production) |
| Spigot | `SPIGOT` | Bukkit-based plugin server |
| Forge | `FORGE` | Mod platform for Java mods |
| Fabric | `FABRIC` | Lightweight mod loader |
| Quilt | `QUILT` | Community-driven Fabric fork |
| Auto CurseForge | `AUTO_CURSEFORGE` | CurseForge modpack auto-install |

## Configuration

### Minimal (Simple Setup)

```yaml
server:
  eula: true
  motd: "My Minecraft Server"

jvm:
  memory: 1G

persistence:
  enabled: true
  size: 10Gi
```

### Production (Full Setup)

```yaml
server:
  eula: true
  type: PAPER
  version: LATEST
  difficulty: normal
  maxPlayers: 50
  viewDistance: 8

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

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

backup:
  enabled: true
  schedule: "0 4 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: minecraft-backups
    existingSecret: minecraft-s3

persistence:
  enabled: true
  size: 50Gi

resources:
  requests:
    cpu: "1"
    memory: 4Gi
  limits:
    cpu: "4"
    memory: 8Gi
```

### Cross-Play (GeyserMC)

```yaml
server:
  eula: true
  type: PAPER

geyser:
  enabled: true
  port: 19132

mods:
  modrinthProjects: "geyser,floodgate"
```

## Parameters

### Server

| Key | Default | Description |
|-----|---------|-------------|
| `server.eula` | `true` | Accept the Minecraft EULA (required) |
| `server.type` | `VANILLA` | Server type (VANILLA, PAPER, FORGE, FABRIC, etc.) |
| `server.version` | `LATEST` | Minecraft version |
| `server.motd` | `A Minecraft Server powered by HelmForge` | Message of the day |
| `server.difficulty` | `normal` | Game difficulty |
| `server.gameMode` | `survival` | Default game mode |
| `server.maxPlayers` | `20` | Maximum concurrent players |
| `server.viewDistance` | `10` | View distance in chunks |
| `server.simulationDistance` | `10` | Simulation distance in chunks |
| `server.seed` | `""` | World seed |
| `server.worldSaveName` | `world` | World directory name |
| `server.levelType` | `DEFAULT` | Level type |
| `server.pvp` | `true` | Enable PvP |
| `server.allowNether` | `true` | Enable the Nether |
| `server.allowFlight` | `false` | Allow flight |
| `server.enableCommandBlock` | `false` | Enable command blocks |
| `server.forceGameMode` | `false` | Force game mode on join |
| `server.hardcore` | `false` | Hardcore mode |
| `server.spawnProtection` | `16` | Spawn protection radius |
| `server.port` | `25565` | Server port |
| `server.extraProperties` | `{}` | Extra server.properties entries |
| `server.extraEnv` | `[]` | Extra environment variables |
| `server.extraArgs` | `""` | Extra server JAR arguments |

### JVM

| Key | Default | Description |
|-----|---------|-------------|
| `jvm.memory` | `1G` | JVM heap allocation (-Xms/-Xmx) |
| `jvm.initMemory` | `""` | Override initial heap size |
| `jvm.maxMemory` | `""` | Override max heap size |
| `jvm.useAikarFlags` | `false` | Use Aikar's optimized GC flags |
| `jvm.jvmOpts` | `""` | Additional JVM options |
| `jvm.xxOpts` | `""` | Additional -XX JVM options |

### Authentication

| Key | Default | Description |
|-----|---------|-------------|
| `auth.onlineMode` | `true` | Mojang online authentication |
| `auth.whitelist` | `""` | Whitelisted players (comma-separated) |
| `auth.enforceWhitelist` | `false` | Enforce whitelist immediately |
| `auth.ops` | `""` | Operators (comma-separated) |

### GeyserMC

| Key | Default | Description |
|-----|---------|-------------|
| `geyser.enabled` | `false` | Enable GeyserMC cross-play |
| `geyser.port` | `19132` | Bedrock listener port (UDP) |

### RCON

| Key | Default | Description |
|-----|---------|-------------|
| `rcon.enabled` | `true` | Enable RCON |
| `rcon.port` | `25575` | RCON port |
| `rcon.password` | `""` | RCON password (auto-generated if empty) |
| `rcon.existingSecret` | `""` | Existing secret for RCON password |
| `rcon.existingSecretKey` | `rcon-password` | Key in existing secret |
| `rcon.serviceEnabled` | `false` | Expose RCON as a Service |
| `rcon.serviceType` | `ClusterIP` | RCON Service type |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.storageClass` | `""` | Storage class |
| `persistence.accessMode` | `ReadWriteOnce` | PVC access mode |
| `persistence.size` | `10Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use existing PVC |
| `persistence.annotations` | `{}` | PVC annotations |

### Metrics

| Key | Default | Description |
|-----|---------|-------------|
| `metrics.enabled` | `false` | Enable mc-monitor sidecar |
| `metrics.image.repository` | `itzg/mc-monitor` | mc-monitor image |
| `metrics.image.tag` | `latest` | mc-monitor tag |
| `metrics.port` | `8080` | Metrics port |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |
| `metrics.serviceMonitor.interval` | `30s` | Scrape interval |
| `metrics.serviceMonitor.labels` | `{}` | Extra ServiceMonitor labels |

### Backup

| Key | Default | Description |
|-----|---------|-------------|
| `backup.enabled` | `false` | Enable S3 backups |
| `backup.schedule` | `0 4 * * *` | Cron schedule |
| `backup.archivePrefix` | `minecraft` | Archive filename prefix |
| `backup.excludes` | `*.jar cache logs` | Excluded patterns |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint |
| `backup.s3.bucket` | `""` | Target bucket |
| `backup.s3.prefix` | `minecraft` | Key prefix in bucket |
| `backup.s3.existingSecret` | `""` | Existing secret for S3 credentials |
| `backup.s3.accessKey` | `""` | Inline access key |
| `backup.s3.secretKey` | `""` | Inline secret key |

### Mods & Plugins

| Key | Default | Description |
|-----|---------|-------------|
| `mods.modrinthProjects` | `""` | Modrinth project slugs (comma-separated) |
| `mods.curseforgeApiKey` | `""` | CurseForge API key |
| `mods.autoCurseforgeSlug` | `""` | Auto CurseForge modpack slug |
| `mods.spigetResources` | `""` | Spiget resource IDs |
| `mods.downloadUrls` | `""` | Direct download URLs |

### Resource Pack

| Key | Default | Description |
|-----|---------|-------------|
| `resourcePack.url` | `""` | Resource pack URL |
| `resourcePack.sha1` | `""` | SHA-1 hash for verification |
| `resourcePack.enforce` | `false` | Force clients to accept |

### Services (Dual-Stack)

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `LoadBalancer` | Game service type |
| `service.port` | `25565` | Game port |
| `service.ipFamilyPolicy` | `~` | Dual-stack policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families (`IPv4`, `IPv6`) |

### External Secrets Operator

| Key | Default | Description |
|-----|---------|-------------|
| `externalSecrets.enabled` | `false` | Render an `ExternalSecret` for the RCON password |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ESO API version |
| `externalSecrets.refreshInterval` | `"0"` | Refresh interval (`"0"` = create-once bootstrap) |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore / ClusterSecretStore name — **required** |
| `externalSecrets.secretStoreRef.kind` | `ClusterSecretStore` | Store kind |
| `externalSecrets.data` | `[]` | Data mappings — **must** include entry with `secretKey` matching `rcon.existingSecretKey` |

> `externalSecrets.enabled=true` with `rcon.enabled=true` requires `rcon.existingSecret` to prevent credential drift.

### Scheduling

| Key | Default | Description |
|-----|---------|-------------|
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
| `topologySpreadConstraints` | `[]` | Topology spread |
| `priorityClassName` | `""` | Priority class |
| `terminationGracePeriodSeconds` | `120` | Shutdown grace period |

## Resources Generated

| Resource | Condition | Description |
|----------|-----------|-------------|
| Deployment | Always | Minecraft server (single replica, Recreate strategy) |
| Service | Always | Game port (LoadBalancer by default) |
| Service (RCON) | `rcon.serviceEnabled` | RCON port (ClusterIP) |
| PersistentVolumeClaim | `persistence.enabled` | Server data volume |
| Secret | `rcon.enabled` and no `existingSecret` | RCON password |
| Secret (backup) | `backup.enabled` and no `existingSecret` | S3 credentials |
| ServiceAccount | `serviceAccount.create` | Dedicated SA |
| ServiceMonitor | `metrics.serviceMonitor.enabled` | Prometheus scrape config |
| CronJob | `backup.enabled` | Scheduled S3 backup |
| ConfigMap (backup) | `backup.enabled` | Backup shell scripts |
| ExternalSecret | `externalSecrets.enabled` | Fetches RCON password from external secrets store |

### Dual-Stack Game Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

### External Secrets Operator (RCON password)

```yaml
rcon:
  enabled: true
  existingSecret: my-minecraft-rcon-secret
  existingSecretKey: rcon-password

externalSecrets:
  enabled: true
  secretStoreRef:
    name: my-store
    kind: ClusterSecretStore
  data:
    - secretKey: rcon-password
      remoteRef:
        key: minecraft/rcon
        property: password
```

## Examples

- [Simple standalone](examples/simple.yaml) — minimal vanilla server
- [Production](examples/production.yaml) — Paper with whitelist, metrics, backup, and affinity
- [Modded](examples/modded.yaml) — Forge server for mods
- [Cross-play](examples/crossplay.yaml) — Paper with GeyserMC for Bedrock clients

## Architecture Guides

- [Vanilla & Paper](docs/vanilla-and-paper.md) — standard server deployment
- [Modded Servers](docs/modded.md) — Forge, Fabric, and modpack deployment
- [Cross-Play](docs/crossplay.md) — GeyserMC and Bedrock client support
- [Backup & Restore](docs/backup.md) — S3 backup strategy and restore procedures

## Connection

After installation, retrieve the server address:

```bash
# LoadBalancer
kubectl get svc <release>-minecraft -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# RCON password
kubectl get secret <release>-minecraft -o jsonpath='{.data.rcon-password}' | base64 -d
```

## Non-Goals

This chart intentionally does not support:

- **Multi-server proxy** — Velocity/BungeeCord requires a separate chart
- **Bedrock Dedicated Server** — Use itzg/minecraft-bedrock-server separately
- **Horizontal auto-scaling** — Minecraft servers are single-threaded and cannot scale horizontally
- **Built-in world download/upload** — Use backup/restore workflows instead

<!-- @AI-METADATA
type: chart-readme
title: Minecraft Server Helm Chart
description: Deploy Minecraft Java Edition servers on Kubernetes with Vanilla, Paper, Forge, Fabric, GeyserMC, S3 backup, and Prometheus monitoring
keywords: minecraft, helm, kubernetes, paper, forge, fabric, geyser, bedrock, game-server, backup, monitoring
purpose: Installation guide, configuration reference, and operational documentation for the minecraft Helm chart
scope: Chart
relations:
  - charts/minecraft/docs/vanilla-and-paper.md
  - charts/minecraft/docs/modded.md
  - charts/minecraft/docs/crossplay.md
  - charts/minecraft/docs/backup.md
  - charts/minecraft/values.yaml
path: charts/minecraft/README.md
version: 1.0
date: 2026-03-23
-->
