# JupyterHub External Secrets

ExternalSecret support manages the configurable-http-proxy token Secret.

Set `proxy.existingSecret` to the target Secret name, enable `externalSecrets.enabled`, and provide either `externalSecrets.data` or `externalSecrets.dataFrom`.

The target Secret must contain the key configured by `proxy.existingSecretTokenKey`, which defaults to `proxy-token`.
