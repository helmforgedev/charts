# Declarative operations

Stalwart's official CLI accepts an idempotent NDJSON plan. Store the plan in an
existing ConfigMap when it contains no secrets, or in a Secret otherwise.
Credentials referenced by plan objects should use environment-variable or file
variants and arrive through `applyJob.env`, `applyJob.envFrom`, or Secret mounts.

The optional Job first runs `apply --dry-run`, then applies the plan. Helm hook
mode runs after install and upgrade; disable hooks when a GitOps reconciler must
own the Job as a normal resource. Both modes have bounded retries and runtime.

The CLI reads `STALWART_URL` plus one supported authentication mechanism from
the environment. Never commit tokens or passwords to values.

After an apply, issue the upstream `Action/ReloadSettings` action when changed
objects require a live snapshot reload. Current Stalwart broadcasts that reload
to cluster nodes, so restarting pods is normally unnecessary. `rolloutTrigger`
and arbitrary pod annotations remain available for exceptional cases.

`stalwart-cli snapshot` exports configuration plans but strips secrets by
default. It complements, rather than replaces, native backups of the DataStore,
BlobStore, SearchStore, and InMemoryStore.
