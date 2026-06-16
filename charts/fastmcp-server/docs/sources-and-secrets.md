<!-- SPDX-License-Identifier: Apache-2.0 -->

# Sources and Secrets

## Inline Sources

Inline sources are useful for small tools, prompts, resources, and knowledge
documents that should travel with the Helm release. Each map key becomes a file
name and each value becomes file content.

```yaml
sources:
  inline:
    tools:
      greet.py: |
        def greet(name: str) -> str:
            """Greet a user."""
            return f"Hello, {name}!"
    knowledge:
      overview.md: |
        # Service Overview
        Internal context for MCP clients.
```

Inline content is stored in ConfigMaps, so avoid putting credentials or private
customer data there. Use external storage plus Kubernetes secrets for sensitive
source material.

## S3-Compatible Source

S3 mode supports AWS S3 and compatible APIs such as MinIO, Ceph, and R2. The
chart passes bucket, region, endpoint, prefix, and credentials to the
application.

```yaml
sources:
  s3:
    enabled: true
    endpoint: "https://minio.example.com"
    bucket: mcp-tools
    region: us-east-1
    prefix: production
    existingSecret: mcp-s3-credentials
```

The referenced secret must contain the configured access and secret key names:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mcp-s3-credentials
stringData:
  access-key: example-access-key
  secret-key: example-secret-key
```

If `existingSecret` is empty, the chart creates `<fullname>-s3` from
`sources.s3.accessKey` and `sources.s3.secretKey`. Prefer `existingSecret` for
production.

## Git Source

Git mode clones a repository and optionally scopes loading to a subdirectory.

```yaml
sources:
  git:
    enabled: true
    repository: "https://github.com/example/mcp-tools.git"
    branch: main
    path: tools
    existingSecret: mcp-git-token
```

Private repositories need a token. If `sources.git.existingSecret` is set, the
chart references that secret. If `sources.git.token` is set and no existing
secret is configured, the chart creates `<fullname>-git`.

## Bearer Authentication Secret

Bearer authentication uses `auth.type=bearer`.

```yaml
auth:
  type: bearer
  bearer:
    existingSecret: mcp-auth-token
```

The secret defaults to key `token`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mcp-auth-token
stringData:
  token: replace-me
```

For local evaluation, `auth.bearer.token` can create a release-scoped secret.
Do not commit production bearer tokens into values files.

## JWT Authentication

JWT mode does not create a secret. Configure issuer, audience, and JWKS URI so
the application can validate tokens:

```yaml
auth:
  type: jwt
  jwt:
    issuer: "https://auth.example.com"
    audience: "mcp-server"
    jwksUri: "https://auth.example.com/.well-known/jwks.json"
```

Expose JWKS endpoints through egress policy when NetworkPolicy or cluster-level
egress controls are enforced.
