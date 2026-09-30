# Security

The chart runs the official image as UID/GID 1000 with a read-only root filesystem, RuntimeDefault seccomp, no added
Linux capabilities and no service account token. Only `/config` and `/tmp` are writable.

Keep registration closed except during controlled onboarding. Store database URIs and webhook URLs in Secrets or
External Secrets. Use TLS for every public endpoint and restrict metrics to monitoring workloads. NetworkPolicy is
opt-in because external database destinations require cluster-specific peers or CIDRs.

Atuin encrypts history end to end, but server database backups still contain user, session and encrypted record
metadata. Protect them and separately preserve client encryption keys.
