# OpenCloud onboarding

Choose the canonical HTTPS hostname before storing production data. Browser callbacks, issuer discovery and bearer
validation share this origin. Set server.publicUrl, a trusted server.tls.existingSecret, bootstrap.existingSecret and
an xattr-capable PVC. The initial Secret key is admin-password and requires at least 16 bytes.

The chart runs the official native initializer before any public server. Log in as admin with that initial password,
then manage accounts and credentials through OpenCloud. Changing the bootstrap Secret does not reset an existing
account. Never rerun forced initialization against existing data: restore the matching configuration instead.

With no public URL, a private Service origin and one-year retained private certificate support evaluation. This
certificate is not automatically renewed. Production should use externally managed certificates and deliberate
certificate/trust-bundle rollout. Both browser and Pod must resolve the public origin and trust its CA.

External Secrets supports the canonical items[] contract. Map the remote password to admin-password and set
bootstrap.existingSecret to the target Secret. Wait for ExternalSecret Ready before diagnosing a blocked bootstrap.
Do not put live credentials in committed Helm values. Generated bootstrap Secrets and Helm release history also
contain credentials: protect Kubernetes Secret access and retain identity/configuration backups separately.
