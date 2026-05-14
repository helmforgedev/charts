# Unbound Recursive DNS

When Unbound is enabled, Pi-hole uses a local Unbound sidecar for recursive DNS
resolution instead of forwarding queries to third-party DNS providers like Google
or Cloudflare. This eliminates the need to trust external resolvers with your DNS
queries.

## How It Works

```text
Client -> Pi-hole (ad filtering) -> Unbound (recursive) -> Root Nameservers
```

1. Pi-hole receives DNS queries and filters ads/trackers
2. Non-blocked queries are forwarded to Unbound at `127.0.0.1#5335`
3. Unbound resolves queries by walking the DNS hierarchy from root nameservers
4. Results are cached locally by both Unbound and Pi-hole

## Enabling Unbound

```yaml
unbound:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

When `unbound.enabled` is `true`, the chart automatically:

- Adds an Unbound sidecar container to the pod
- Overrides Pi-hole's upstream DNS to `127.0.0.1#5335`
- Ignores `pihole.upstreamDns` value

## DNSSEC

Unbound validates DNSSEC by default. You can also enable DNSSEC in Pi-hole for double validation:

```yaml
pihole:
  dnssec: true

unbound:
  enabled: true
```

## Performance Considerations

- First-time queries are slower (recursive resolution walks the DNS hierarchy)
- Subsequent queries are fast (served from Unbound and Pi-hole caches)
- Allocate at least 64Mi memory for Unbound

## Image

The chart uses [mvance/unbound](https://hub.docker.com/r/mvance/unbound) with a pinned version tag. The default port is `5335` to avoid conflicts with Pi-hole's DNS on port `53`.

The image ships with `interface: 0.0.0.0@53` hardcoded in
`/opt/unbound/etc/unbound/unbound.conf`, which would collide with `pihole-FTL`
in the shared pod network namespace. The chart mounts a generated `unbound.conf`
over that file at runtime; the rendered config binds Unbound to `127.0.0.1` at
`unbound.port`, validates DNSSEC against the trust anchor the image entrypoint
generates at `/opt/unbound/etc/unbound/var/root.key`, and blocks DNS rebinding
of RFC1918 ranges. The default config omits `root-hints:` so Unbound falls back
to its built-in root server list (the image does not ship a `root.hints` file).

## Customizing the Unbound Config

Append extra directives inside the default `server:` section:

```yaml
unbound:
  enabled: true
  extraConfig: |
    cache-min-ttl: 300
    cache-max-ttl: 86400
    forward-zone:
        name: "."
        forward-tls-upstream: yes
        forward-addr: 1.1.1.1@853
```

Replace the rendered file entirely:

```yaml
unbound:
  enabled: true
  config: |
    server:
        interface: 127.0.0.1
        port: 5335
        do-ip4: yes
        do-udp: yes
        do-tcp: yes
        auto-trust-anchor-file: "/opt/unbound/etc/unbound/var/root.key"
        access-control: 127.0.0.1/32 allow
```

When `unbound.config` is set, `unbound.extraConfig` is ignored.

Paths in a fully overridden `unbound.config` must match what the
`mvance/unbound` image actually provides. The image entrypoint creates the
DNSSEC trust anchor at `/opt/unbound/etc/unbound/var/root.key` and does not
ship a `root.hints` file, so pointing `auto-trust-anchor-file` at
`/opt/unbound/etc/unbound/root.key` or referencing `root.hints` will fail
`unbound-checkconf` and crash the sidecar.

<!-- @AI-METADATA
type: chart-docs
title: Unbound Recursive DNS
description: Privacy-focused recursive DNS resolution with Pi-hole and Unbound sidecar
keywords: unbound, recursive-dns, privacy, pihole, dnssec
purpose: Architecture guide for deploying Pi-hole with Unbound recursive DNS sidecar
scope: Chart
relations:
  - charts/pihole/README.md
  - charts/pihole/values.yaml
path: charts/pihole/docs/unbound.md
version: 1.0
date: 2026-03-23
-->
