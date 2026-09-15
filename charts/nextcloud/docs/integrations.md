# Optional integrations

Both integrations are disabled by default. They run alongside Nextcloud in its
single application Pod and inherit its non-root security context. No additional
public Service, Ingress or HTTPRoute is created. Enabling either adds its resource
requests to the Pod; reserve capacity before upgrading.

## Imaginary previews

Set `imaginary.enabled: true` to use the official Nextcloud AIO Imaginary image,
pinned by an immutable multi-platform digest. Imaginary listens on loopback port
9000, receives preview uploads from Nextcloud and has no access to the data PVC.
Remote URL fetching is disabled. Its temporary files use a bounded emptyDir.

The chart manages `preview_imaginary_url` and `enabledPreviewProviders` in its
configuration snippet. The default providers preserve text, Markdown,
OpenDocument and Krita previews and offload supported images to Imaginary.
`imaginary.previewProviders` replaces the whole list; PDF preview is deliberately
opt-in through `OC\Preview\ImaginaryPDF`. Set `imaginary.maxAllowedResolution`
(megapixels) and resource limits to suit your workloads. Unsupported formats
remain without previews unless an appropriate provider is configured.

Disabling the integration removes the managed settings on the next rollout.
Existing cached previews remain on the Nextcloud volume. Do not maintain competing
preview settings in another config snippet.

## Client Push

Set `notifyPush.enabled: true` to start the official `nextcloud/notify_push` daemon.
The chart generates its configuration in a memory-backed volume from the same
database and Redis Secrets as Nextcloud. Existing database table prefixes are
preserved. Restart the Deployment after credential rotation, as the daemon reads
configuration at startup. The daemon does not mount the application/data PVC.

Apache proxies `/push/` and `/push/ws` to the daemon. Your existing Ingress or
Gateway must route these paths, support WebSocket upgrades and allow long-lived
connections. Configure TLS and `nextcloud.overwriteCliUrl` with the public URL.
The chart trusts loopback for the daemon's callback requests; retain the actual
ingress/Gateway addresses in `nextcloud.trustedProxies` as well.

The Nextcloud **Client Push** app remains operator-managed. Once Nextcloud is
installed, install a compatible app release and run the upstream setup test:

```bash
kubectl -n nextcloud exec deployment/nextcloud -c nextcloud -- php occ app:install notify_push
kubectl -n nextcloud exec deployment/nextcloud -c nextcloud -- php occ notify_push:setup https://cloud.example.com/push
```

For an already installed app use `occ app:enable notify_push`. The pinned daemon
version is 1.4.1; keep the app and daemon compatible when upgrading. Helm does not
download or update apps automatically. Air-gapped installations must stage the
compatible official app using Nextcloud's supported app installation workflow.
Run `occ notify_push:setup` again after changing the public hostname or routing.
Its successful result verifies Redis messages, database mappings, callback
connectivity, trusted proxies and version compatibility. Verify client sync
through your actual external endpoint too.

Daemon readiness checks its listener, not whether the Nextcloud app has been
installed or the public route configured. Installation is complete only after
the setup test passes. Clients still periodically poll because push delivery is
best-effort.

Enable `networkPolicy.enabled` to prevent other Pods from directly accessing
daemon port 7867. Keep ingress peers allowed for Apache port 8080. App Store
downloads need HTTPS egress; external database and Redis endpoints need their
normal explicit egress rules. Imaginary uses only loopback and needs no egress.

Before disabling Client Push, run `occ app:disable notify_push`, then disable
`notifyPush.enabled`. This prevents advertising an unavailable push endpoint.
The daemon stops with the application during coordinated backup and restore;
the app itself is retained in the application PVC and database backup.

See the [integration values example](../examples/integrations.yaml),
[official Client Push instructions](https://github.com/nextcloud/notify_push), and
[Nextcloud preview tuning](https://docs.nextcloud.com/server/stable/admin_manual/installation/server_tuning.html#previews).
