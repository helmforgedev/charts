# ConfigMaps & Startup Sync

openHAB monitors its configuration directories using a native file watcher.
Any file change under `/openhab/conf/` is applied automatically within 2-5
seconds after the file exists on the writable filesystem.

This chart exposes three ConfigMap-backed input groups and copies their files
into the writable `conf` PVC before openHAB starts. Directly mounting ConfigMaps
under `/openhab/conf` is not used because the official openHAB entrypoint runs
`chown -R /openhab`, and Kubernetes ConfigMap volumes are read-only.

## How It Works

```text
Helm values.yaml
    └─> ConfigMap (K8s)
            └─> initContainer sync-configmaps
                    └─> copy to /openhab/conf/<dir>/<file> on the conf PVC
                            └─> openHAB starts and reads writable files
```

The StatefulSet pod template includes a checksum of the rendered ConfigMaps.
When ConfigMap values change, a Helm upgrade rolls the pod so the initContainer
copies the new files before openHAB starts again.

## Supported Directories

| ConfigMap Key | Mount Path | File Type | Purpose |
|---------------|-----------|-----------|---------|
| `configMaps.sitemaps` | `/openhab/conf/sitemaps/` | `*.sitemap` | UI layouts for BasicUI |
| `configMaps.things` | `/openhab/conf/things/` | `*.things` | Physical device definitions |
| `configMaps.items` | `/openhab/conf/items/` | `*.items` | Logical item definitions |

## Enabling ConfigMaps

```yaml
configMaps:
  sitemaps:
    enabled: true
    files:
      myhome.sitemap: |
        sitemap myhome label="My Home" {
          Frame label="Lights" {
            Switch item=Light_Living label="Living Room"
          }
        }
  things:
    enabled: true
    files:
      network.things: |
        Thing network:pingdevice:router [ hostname="192.168.1.1" ]
  items:
    enabled: true
    files:
      lights.items: |
        Switch Light_Living "Living Room" <light>
```

## Applying Changes

After updating values, run `helm upgrade`. The checksum annotation changes,
Kubernetes rolls the pod, and the initContainer copies the new files into the
conf PVC:

```bash
helm upgrade my-openhab helmforge/openhab -f values.yaml
# The StatefulSet rolls so ConfigMap files are copied before startup
```

## Important Limitations

- **ConfigMap size limit**: Kubernetes ConfigMaps are limited to 1 MiB total.
  For large configuration files, use the PVC directly instead.
- **File naming**: File keys must match openHAB's expected extensions
  (`.sitemap`, `.things`, `.items`).
- **Rollout required**: ConfigMap changes are applied on the next pod start.
  The chart adds a checksum annotation so Helm upgrades trigger that rollout.
- **PVC overwrite behavior**: If a managed ConfigMap file has the same filename
  as an existing PVC file in the target directory, the managed file is copied
  over it during startup.

## Troubleshooting

### File not being synced

Check if the file exists on the pod:

```bash
kubectl exec -n <namespace> <pod> -- ls /openhab/conf/sitemaps/
```

Check openHAB logs for errors:

```bash
kubectl exec -n <namespace> <pod> -- tail -f /openhab/userdata/logs/openhab.log
```

### ConfigMap too large

Split your configuration into multiple values files and use `helm upgrade -f`.

### Conflict with PVC content

ConfigMap files are copied into the same directories used by openHAB. If the
same filename already exists in the PVC, the ConfigMap-managed version replaces
it during startup.
