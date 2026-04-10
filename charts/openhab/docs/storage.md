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

## Using Existing PVCs

If you have pre-existing data on PVCs, use `existingClaim`:

```yaml
persistence:
  userdata:
    existingClaim: my-openhab-userdata
  conf:
    existingClaim: my-openhab-conf
  addons:
    existingClaim: my-openhab-addons
```

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
