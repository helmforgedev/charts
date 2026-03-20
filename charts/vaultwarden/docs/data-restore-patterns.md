# Data Restore Patterns

## Why this guide exists

The chart supports persistence, but restore workflows are not all the same.

There are two common patterns when bringing Vaultwarden back with restored data:

1. bind the release to an already restored PVC
2. create a new PVC that targets a restored PV through selector labels

This document explains when each pattern fits.

## Pattern 1: existingClaim

Use `data.persistence.existingClaim` when:

- the restore process already recreated the PVC
- the claim name is stable and known
- you want the Helm release to attach to that exact claim

Example:

```yaml
data:
  persistence:
    enabled: true
    existingClaim: vaultwarden-restored-data
```

This is usually the clearest restore path because the binding decision happens outside the chart.

## Pattern 2: selectorLabels

Use `data.persistence.selectorLabels` when:

- your platform restore flow creates or exposes a PV with known labels
- you want the chart-created PVC to bind only to that restored volume

Example:

```yaml
data:
  persistence:
    enabled: true
    selectorLabels:
      restore-id: vaultwarden-prod-2026-03-20
```

This is useful in environments where PVs are recreated or pre-provisioned by a restore system and Helm should claim the right one deterministically.

## Safety guidance

- do not use `selectorLabels` casually on day-1 installs
- do not keep stale restore selectors in long-lived values files after recovery
- verify that the selected PV really belongs to the intended Vaultwarden state boundary
- validate `db.sqlite3`, `config.json`, `rsa_key*`, `attachments/`, and `sends/` together after rebinding storage

## Recommended restore workflow

1. restore storage first
2. choose either `existingClaim` or `selectorLabels`
3. deploy or upgrade the release with the intended restore values
4. validate the selected database mode and `/data` contents
5. only then reopen traffic

## References

- [Backup and Restore](backup-and-restore.md)
- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
