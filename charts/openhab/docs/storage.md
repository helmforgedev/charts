# Storage

openHAB requires persistent storage for three directories. Data loss in any of
these directories can result in loss of configuration, automation rules, or
historical persistence data.

## Directories Overview

| Directory | PVC Key | Default Size | Content |
|-----------|---------|-------------|---------|
| `/openhab/userdata` | `persistence.userdata` | 5Gi | Runtime state, JSONDB, logs, persistence data |
| `/openhab/conf` | `persistence.conf` | 1Gi | Items, things, rules, sitemaps, services config |
| `/openhab/addons` | `persistence.addons` | 2Gi | Drop-in JAR bindings/addons |

## userdata

This is the most critical volume. It contains:

- `jsondb/` — Persisted items state, thing configurations, rules
- `logs/` — openHAB application log
- `persistence/` — Historical data (RRD4J, MapDB, etc.)
- `tmp/` — Temporary files (safe to delete on restart)
- `cache/` — OSGi bundle cache (rebuilt on restart if missing)

**Minimum recommended size**: 5Gi for a basic home automation setup.
**For production with RRD4J/InfluxDB persistence**: 10-20Gi.

## conf

Contains all user-defined configuration files:

- `items/` — Item definitions (`*.items`)
- `things/` — Thing definitions (`*.things`)
- `sitemaps/` — UI sitemaps (`*.sitemap`)
- `rules/` — Automation rules (`*.rules`)
- `scripts/` — Scripts
- `services/` — Service configuration (`addons.cfg`, `runtime.cfg`, etc.)
- `transformations/` — Transformation files (MAP, JS, etc.)

This directory is monitored by openHAB's file watcher — changes are applied live.

**Minimum recommended size**: 1Gi (text files, very small).

## addons

Drop-in directory for JAR-format addons not available through the openHAB marketplace.
Most users will keep this empty (addons installed via the UI go to `userdata`).

**Minimum recommended size**: 2Gi.

## Using Existing PVCs and Subdirectories

Use `existingClaim` to mount an existing PVC. To use one PVC for all three
openHAB directories, configure a separate relative `subPath` for each
directory:

```yaml
persistence:
  userdata:
    existingClaim: openhab-data
    subPath: userdata
  conf:
    existingClaim: openhab-data
    subPath: conf
  addons:
    existingClaim: openhab-data
    subPath: addons
```

`subPath` mounts a subdirectory rather than the root of the PVC. It must be a
relative path without `..` segments. Because Kubernetes requires the target
subdirectory to exist, the chart creates it in a preparatory init container
when a `subPath` is configured and it is not already present.

> **Why this is recommended:** ext4 creates a `lost+found` directory at the
> root of a new filesystem. This is the default for Longhorn volumes. openHAB
> therefore does not consider a PVC root containing `lost+found` empty, skips
> its initialization, and subsequently fails to start. A dedicated `subPath`
> avoids this issue.

### Multiple openHAB Instances on One PVC

`existingClaim` can also be used to run multiple openHAB instances on the same
PVC. Each instance must use its own directory tree so that their data does not
overlap, for example:

```text
/openhab-test/userdata
/openhab-test/conf
/openhab-test/addons

/openhab-live/userdata
/openhab-live/conf
/openhab-live/addons
```

Configure the test instance like this; use the same configuration in the other
release with `openhab-live` (or another unique path) instead:

```yaml
persistence:
  userdata:
    existingClaim: openhab-data
    subPath: openhab-test/userdata
  conf:
    existingClaim: openhab-data
    subPath: openhab-test/conf
  addons:
    existingClaim: openhab-data
    subPath: openhab-test/addons
```

> **Access mode:** When releases sharing a PVC can run on different nodes, the
> PVC's storage class must support `ReadWriteMany` (RWX). `ReadWriteOnce` (RWO)
> permits concurrent mounts only when all consumers are scheduled on the same
> node; otherwise the second release can remain pending because the volume
> cannot be attached. Separate `subPath` values prevent data overlap but do not
> change this access-mode requirement. If RWX is unavailable, use separate PVCs
> for each release.

## Storage Class Recommendations

For home automation, low-latency local storage is preferred:

```yaml
persistence:
  userdata:
    storageClass: "local-path"    # k3s default
    size: 10Gi
  conf:
    storageClass: "local-path"
    size: 2Gi
  addons:
    storageClass: "local-path"
    size: 5Gi
```

## Backup

openHAB does not include automated backup. To back up your data:

```bash
# Create a backup of userdata
kubectl exec -n <namespace> <pod> -- tar czf - /openhab/userdata > openhab-userdata-$(date +%Y%m%d).tar.gz

# Create a backup of conf
kubectl exec -n <namespace> <pod> -- tar czf - /openhab/conf > openhab-conf-$(date +%Y%m%d).tar.gz
```

For automated backups, consider using Velero with volume snapshots.

## Filesystem Permissions

The openHAB image runs as UID/GID `9001`. The `fsGroup: 9001` in `podSecurityContext`
ensures that mounted PVCs are owned by group `9001`, allowing openHAB to read and write
without permission errors.

If you use an existing PVC with incorrect ownership, fix it with:

```bash
kubectl exec -n <namespace> <pod> -- chown -R 9001:9001 /openhab/userdata
```
