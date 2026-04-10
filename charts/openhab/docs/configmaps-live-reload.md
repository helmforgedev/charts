# ConfigMaps & Live Reload

openHAB monitors its configuration directories using a native file watcher.
Any file change under `/openhab/conf/` is applied automatically within 2-5 seconds — no pod restart required.

This chart exposes three ConfigMap-backed mount points, allowing you to manage
openHAB configuration declaratively via Helm values or GitOps pipelines.

## How It Works

```
Helm values.yaml
    └─> ConfigMap (K8s)
            └─> Volume mount (subPath) → /openhab/conf/<dir>/<file>
                    └─> openHAB file watcher detects change (~2-5s)
                            └─> Configuration applied automatically
```

Files are mounted using `subPath`, which means they are added alongside any
existing files in the PVC — existing configurations are preserved.

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

After updating values, run `helm upgrade`. Kubernetes will sync the ConfigMap,
and openHAB will pick up the change automatically:

```bash
helm upgrade my-openhab helmforge/openhab -f values.yaml
# No restart required — openHAB reloads automatically
```

## Important Limitations

- **ConfigMap size limit**: Kubernetes ConfigMaps are limited to 1 MiB total.
  For large configuration files, use the PVC directly instead.
- **File naming**: File keys must match openHAB's expected extensions
  (`.sitemap`, `.things`, `.items`).
- **Sync delay**: Kubernetes syncs ConfigMaps to pods every ~60 seconds by default
  (controlled by `--sync-frequency` on kubelet). The 2-5s reload refers to
  openHAB's file watcher after the file appears on disk.

## Troubleshooting

### File not being reloaded

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

Files mounted via ConfigMap `subPath` appear alongside files already in the PVC.
If the same filename exists in both the ConfigMap and the PVC, the ConfigMap version
takes precedence (it shadows the PVC file at that specific path).
