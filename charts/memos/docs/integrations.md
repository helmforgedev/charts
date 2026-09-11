# Memos identity, MCP and object storage

## Native OAuth2

Memos 0.30 uses generic OAuth2 authorization-code exchange and a configured HTTPS UserInfo endpoint. It does not perform
OIDC issuer/JWKS/ID-token validation merely because `openid` is included in scopes. Configure only a trusted provider,
exact callback URLs and stable subject mapping; keep client credentials in `provisioning.existingSecret`.

Native file-backed providers use `memos-idp-<label>.json` with a stable `uid`, display `name`, type `OAUTH2` and
`config.oauth2Config`. Include all required fields: clientId, clientSecret, authUrl, tokenUrl, userInfoUrl, scopes and
fieldMapping. The provider's authorization endpoint must enforce PKCE for clients that require it.

Closed registration also blocks unlinked SSO users. An existing authenticated user must deliberately link their identity
through the native account flow before SSO login can reuse that account. Matching email or display name does not replace
the stable provider subject. The runtime fixture verifies trusted HTTPS, explicit admin linkage, S256 exchange, one-use
codes, rejected new enrollment and rejected subject replacement, including after pod restart. It exercises native APIs;
it does not claim browser-level state handling or full OIDC validation.

When using a private CA, mount its public certificate bundle and configure the Go client's `SSL_CERT_FILE`. Keep the
bundle read-only and allow the issuer's HTTPS destination through NetworkPolicy. Do not disable certificate
verification.

## Native MCP

The stateless Streamable HTTP endpoint is `/mcp`. Create a native Personal Access Token in the user account and send it
as `Authorization: Bearer <token>` on each request. Tool discovery does not itself prove authorization: protected tool
operations validate the user token and can return `result.isError` inside an HTTP 200 JSON-RPC response.

The runtime gate creates and revokes an actual PAT, initializes MCP, discovers tools, performs private memo CRUD through
`memo_create_memo`, `memo_get_memo` and `memo_delete_memo`, verifies data through the REST API, and checks anonymous and
revoked-token denial. Keep PATs out of URLs, logs and plain Helm values. Use least-privilege accounts and expiration.

## Native S3 storage

Set a complete `STORAGE` provisioning group with `storageType: S3`, `filepathTemplate`, `uploadSizeLimitMb` and
`s3Config`. The credential field is `accessKeySecret`; use `usePathStyle` for compatible endpoints and keep
`insecureSkipTlsVerify: false`. The upstream client requires explicit static credentials; ambient workload identity and
temporary session-token authentication are not part of this configuration contract.

The bucket must exist. Allow the endpoint in NetworkPolicy and provide its trusted CA when needed. Storage policy
changes affect new uploads and do not move historical objects. Native S3 attachment state contains the object reference
and its storage configuration; protect database backups as credential-bearing data. Presigned original URLs are bearer
access URLs and must remain private. Back up matching database references and objects together.
