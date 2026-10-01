# External Secrets

External Secrets Operator is installed out of band. Enable
`externalSecrets.enabled` and define one or more canonical `items`. Each item
projects a Kubernetes Secret; configure `webodm.existingSecret`, external
database or Redis Secrets, or `oidc.existingSecret` to consume that target.

The application Secret needs `secret-key` and `processor-token`. The OIDC
Secret needs `client-secret`. Database and Redis key names are configurable.
The chart validates that every item has a store or generator reference.
