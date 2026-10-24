<!-- SPDX-License-Identifier: Apache-2.0 -->
# Wallabag Configuration

This guide explains the Wallabag-specific settings of the chart. The complete
list of keys is in `values.yaml` and the parameter tables in
[../README.md](../README.md).

## Public URL and instance name

`wallabag.domainName` must be the URL users reach, including the scheme and
without a trailing slash, for example `https://read.example.com`. Wallabag uses
it for absolute links in the API, exports, and emails. `wallabag.serverName`
sets the instance name shown in the UI.

## Initial super-admin

The `setup` init container installs the schema on the first start and then
replaces the upstream `wallabag/wallabag` account with:

```yaml
wallabag:
  admin:
    username: reader
    email: reader@example.com
    existingSecret: wallabag-admin        # optional
    existingSecretPasswordKey: password   # key inside the Secret
```

Without `existingSecret`, the chart generates a password once and stores it in
`<release>-wallabag-admin` under `admin-password`:

```bash
kubectl get secret <release>-wallabag-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

The admin settings apply only to the first install. Change the password later
in the UI or with:

```bash
kubectl exec -it deploy/<release>-wallabag -c wallabag -- \
  su -s /bin/sh nobody -c "php bin/console --env=prod fos:user:change-password <username>"
```

## Database setup and upgrades

`setup.enabled=true` (default) runs the setup container on every pod start:

- schema missing: `wallabag:install`, then the initial super-admin;
- schema present: `doctrine:migrations:migrate --allow-no-migration`.

Upgrading `image.tag` therefore applies the upstream migrations before the new
version serves traffic. Set `setup.enabled=false` only when the schema and
users are managed outside the chart.

## Listener and Service ports

`wallabag.port` is the nginx listener inside the container. The container
rewrites the nginx `listen` directive before the entrypoint starts and exits
with an error when the rewrite does not apply. `service.port` is independent:

```yaml
wallabag:
  port: 8080
service:
  port: 8088
```

Probes, the Ingress backend, and HTTPRoutes follow the named `http` port
automatically.

## Redis

Wallabag uses Redis only as the queue for asynchronous imports (Pocket,
Instapaper, browser exports, and similar). Enable the subchart or point to an
external instance:

```yaml
redis:
  enabled: true
# or
externalRedis:
  host: redis.example.internal
  existingSecret: wallabag-redis
  existingSecretPasswordKey: redis-password
```

The queue is consumed by `wallabag:import:redis-worker <type>` processes, which
this chart does not run. Leave the internal setting "Enable Redis to fetch data
asynchronously" disabled unless you deploy those workers; otherwise imports wait
in the queue indefinitely. See [../DESIGN.md](../DESIGN.md).

## Exposure

Use either an Ingress or Gateway API:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: public
      parentRefs:
        - name: shared-gateway
          namespace: gateway-system
          sectionName: https
      hostnames:
        - read.example.com
```

Each HTTPRoute requires `parentRefs`. Without `rules`, the route sends all
traffic to the Wallabag Service.

## Persistence

The PVC at `/var/www/wallabag/data` stores downloaded article images. It is
`ReadWriteOnce`, so the Deployment runs one replica with the `Recreate`
strategy. The pod sets `fsGroup: 65534` so the `nobody` PHP user can write to a
fresh volume.
