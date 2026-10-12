# Configuration

<!-- markdownlint-disable MD013 -->

The chart sets the Core host and port, workspace, safe browser policy, analytics opt-out and orchestrator-managed update behavior. Configure the TinyHumans backend with `openhuman.backendUrl`; inject model, search, OAuth or headless-login credentials only through Secret references in `openhuman.extraEnv` or `openhuman.envFrom`.

`auth.existingSecret` replaces the generated RPC-token Secret. `keyring.existingSecret` enables encrypted credential storage through the upstream file variable. The workspace and projects claims may each bind an existing PVC.
