# Langflow Operations

## Access

```bash
kubectl port-forward svc/langflow 7860:7860
open http://127.0.0.1:7860
```

For a release with another name:

```bash
kubectl port-forward svc/<release>-langflow 7860:7860 -n <namespace>
```

## State

By default, Langflow stores local state under `/app/langflow`.
Keep persistence enabled unless the release is disposable.
If the PVC is deleted, local SQLite data, flow metadata, and local configuration are lost.

## Upgrades

Before upgrading:

1. Back up the PVC or external database.
2. Keep `LANGFLOW_SECRET_KEY` stable.
3. Confirm provider API keys are stored in Kubernetes Secrets, not embedded in exported flows.
4. Test custom components against the target Langflow version.

## Troubleshooting

- UI not reachable: check Service, Ingress/Gateway, and pod readiness.
- Login issues: confirm `LANGFLOW_SUPERUSER_PASSWORD` and `LANGFLOW_SECRET_KEY`.
- Missing flows after restart: confirm PVC or external database state.
- Provider failures: inspect `app.env` or `app.envFrom` Secret keys.
