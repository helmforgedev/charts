# Runtime Configuration and config.json

## Why this matters

Vaultwarden does not behave like a pure "env vars only" application.

The official configuration model explicitly notes that settings changed in the admin interface can be stored in `/data/config.json` and override environment-driven defaults.

That matters operationally because this chart is managed by Helm, while part of the effective runtime configuration can live inside the persistent volume.

## What this means in practice

You can have three different layers affecting runtime behavior:

1. Helm values
2. environment variables rendered by the chart
3. persisted admin-interface overrides in `/data/config.json`

If those layers diverge, the application may not behave exactly like the current `values.yaml` suggests.

## Operational guidance

- treat `/data/config.json` as part of the configuration state that must be backed up
- avoid casual changes in the admin interface without recording them
- when possible, standardize important settings in Helm and document any intentional runtime overrides
- during incident analysis, inspect both Helm values and the persisted `/data/config.json`

## Why this is important for backup and restore

If you restore only `db.sqlite3` and ignore `config.json`, the instance may come back with:

- missing configuration overrides
- mismatched admin/runtime behavior
- unexpected differences in email, signup, or security behavior

For this chart, backup and restore should therefore always treat `/data/config.json` as part of the restore boundary.

## Why this is important for rollout and change management

- a Helm upgrade does not automatically remove or reconcile persisted runtime overrides
- a rollback may not return the full effective configuration if `/data/config.json` was changed after deployment
- production runbooks should mention both Helm and persisted runtime configuration

## Reference

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
