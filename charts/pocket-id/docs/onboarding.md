# Pocket ID onboarding and recovery

Set `server.publicUrl` to the final HTTPS origin and deploy its trusted TLS certificate before enrolling a passkey. The
chart closes the native first-user setup endpoint inside a loopback-only initializer. The created account has
administrator privileges but no passkey yet.

## First login

Run the native operator command in a private terminal:

```sh
kubectl -n identity exec deployment/identity-pocket-id -c pocket-id -- \
  /app/pocket-id one-time-access-token administrator
```

Use the returned URL once, within one hour. It is a bearer credential: do not store it in a ticket, screenshot, shared
shell transcript or deployment log. Enroll a passkey through the application's account settings. Add an independent
recovery authenticator and verify that it can sign in before relying on the service for other applications.

The CLI looks up an existing username or email. It does not create an account and does not reset its other credentials.
Use the configured `bootstrap.username`, not the example name above, when they differ.

## Expired or interrupted setup

If the initial link expires, run the native command again when ready. The chart deliberately does not store an expiring
token in a Secret or rotate it on every restart. User creation and token issuance are separate native operations.
Existing account state always wins over changed bootstrap values.

Disabling bootstrap is supported only for an already initialized database. The private initializer rejects an empty
database with account creation disabled rather than exposing first-user setup publicly.

## State protection

Keep the database, uploads and original encryption key as one recovery set. Restrict access to the entire database even
though sensitive fields are encrypted. A restored database with a replacement encryption key cannot be assumed to retain
its signing identity. Keep the original HTTPS origin so enrolled passkeys retain their relying-party identity.
