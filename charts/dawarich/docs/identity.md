# Private initialization and identity

The chart creates its initial administrator through Dawarich's native Rails model
before running upstream seeds. Password hashing, API-key generation and user
callbacks remain native. No HTTP listener runs in that init container. An existing
user database is admitted only with its retained identity fingerprint and an active
administrator; initialization never silently resets an existing account.

Supply `bootstrap.existingSecret` with the key named by `bootstrap.passwordKey`, or
let Helm generate a retained password. Use at least 16 characters and no more than
72 UTF-8 bytes, matching the native password hashing boundary. Store the Secret
through your normal secret-management workflow and change the initial email before
the first installation. Later changes to bootstrap values do not rename users or
rotate their passwords.

## Registration policy

Rails binds only to loopback on port 3010. The public NGINX listener denies native
API registration and Apple/Google enrollment, the signup page and web OAuth routes.
A documented Rails middleware initializer rejects Devise account creation after
`Rack::MethodOverride`, so authenticated profile update and deletion retain their
native HTTP methods. Native registration is also disabled in the cached setting.

This is a local-account deployment. The upstream environment flag alone does not
close every registration route, and a readiness probe is not an enrollment barrier.
Create additional accounts through trusted native administrator operations. Do not
add a Service or ingress rule for the private Rails listener.

## Two-factor authentication

Native TOTP setup is available because the chart supplies all three OTP encryption
keys alongside `SECRET_KEY_BASE`. Users enroll through Dawarich and retain their
recovery codes securely. Password authentication for an enrolled user returns a
challenge rather than an API key; the challenge is completed with TOTP or a recovery
code. These are native Dawarich mechanisms, not a chart-managed authenticator.

The retained identity Secret contains:

- `SECRET_KEY_BASE`
- `OTP_ENCRYPTION_PRIMARY_KEY`
- `OTP_ENCRYPTION_DETERMINISTIC_KEY`
- `OTP_ENCRYPTION_KEY_DERIVATION_SALT`

An existing user database must match the fingerprint on the application PVC before
migrations start. Back up the matching Secret, database and PVC together. Key
rotation requires a reviewed native migration; replacing the Secret with unrelated
random values is not a password reset and will fail admission.

## Trusted administration

Kubernetes exec, Secret access and namespace policy administration are trusted
operator capabilities. The chart creates no Role or RoleBinding for the application
and disables its projected API token. Use least-privilege RBAC for human operators.

For a reviewed native Rails maintenance script already placed in the Pod, the
runtime wrapper initializes the same connection environment as the application:

```bash
kubectl exec -n locations deployment/dawarich-dawarich -c dawarich -- \
  sh -ec 'unset BUNDLE_PATH BUNDLE_BIN; exec bundle exec ruby /helmforge/entrypoint.rb runner /tmp/reviewed-maintenance.rb'
```

Use the actual Deployment name from `helm status`. Do not print API keys, passwords,
OTP seeds or backup codes into operational logs.
