# Supported Providers

The ddns-updater supports 50+ DNS providers. Each provider has its own set of required fields in the `config.settings[]` array.

## Common Providers

### Cloudflare

```yaml
config:
  settings:
    - provider: cloudflare
      zone_identifier: "your-zone-id"
      domain: "example.com"
      host: "@"            # @ for root, or subdomain name
      ttl: 300
      token: "api-token"   # API token with DNS:Edit permission
      proxied: false        # true to proxy through Cloudflare CDN
      ip_version: "ipv4"   # ipv4, ipv6, or ipv4 or ipv6
```

### DuckDNS

```yaml
config:
  settings:
    - provider: duckdns
      domain: "myhost.duckdns.org"
      token: "your-duck-token"
      ip_version: "ipv4"
```

### Namecheap

```yaml
config:
  settings:
    - provider: namecheap
      domain: "example.com"
      host: "home"
      password: "ddns-password"
```

### Google Domains (now Squarespace)

```yaml
config:
  settings:
    - provider: google
      domain: "example.com"
      host: "home"
      username: "generated-username"
      password: "generated-password"
```

### Route53 (AWS)

```yaml
config:
  settings:
    - provider: route53
      domain: "example.com"
      host: "@"
      ttl: 300
      access_key_id: "AKIA..."
      secret_access_key: "..."
      zone_id: "Z..."
```

## Full Provider List

For all providers and their fields, see the [upstream documentation](https://github.com/qdm12/ddns-updater/tree/master/docs).

Supported providers include: Cloudflare, AWS Route53, Google, DuckDNS, Namecheap, GoDaddy, DigitalOcean, Hetzner, OVH, Linode, Porkbun, Gandi, Dynu, NoIP, FreeDNS, Infomaniak, IONOS, Strato, Netcup, and many more.

<!-- @AI-METADATA
@description: Supported DNS providers reference for the ddns-updater Helm chart
@type: chart-docs
@chart: ddns-updater
@path: charts/ddns-updater/docs/providers.md
@date: 2026-03-23
@relations:
  - charts/ddns-updater/README.md
  - charts/ddns-updater/values.yaml
-->
