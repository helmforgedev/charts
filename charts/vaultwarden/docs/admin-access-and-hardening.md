# Admin Access and Hardening

## Admin panel basics

Vaultwarden can expose an admin panel controlled by `ADMIN_TOKEN`.

In this chart:

- `admin.token` accepts the value directly
- `admin.existingSecret` is the preferred production path

## Recommended pattern

- prefer `admin.existingSecret`
- prefer an Argon2 PHC string instead of plain text
- expose the admin panel only behind trusted access controls
- do not rely on obscurity alone

## Generate a secure admin token

Using the Vaultwarden image:

```bash
docker run --rm -it vaultwarden/server:1.35.4 /vaultwarden hash
```

Using the `argon2` CLI:

```bash
echo -n 'change-me' | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
```

## Ingress recommendations

- terminate TLS at ingress or reverse proxy
- keep `domain` aligned with the external HTTPS URL
- keep the admin page behind network or identity controls when possible
- keep `vaultwarden.proxy.ipHeader` aligned with the actual reverse proxy behavior

## Operational notes

- rotating `ADMIN_TOKEN` requires an explicit rollout
- admin-interface changes can persist runtime configuration to `/data/config.json`
- document who is allowed to use the admin panel before enabling it

## References

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
- Admin token guidance: https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#secure-the-admin_token
