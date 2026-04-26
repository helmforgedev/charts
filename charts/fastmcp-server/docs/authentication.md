# Authentication

FastMCP Server separates client authentication from source credentials and tool credentials.

## Bearer

```yaml
auth:
  type: bearer
  scopes:
    - mcp:read
    - mcp:admin
  bearer:
    existingSecret: fastmcp-auth
    existingSecretKey: token
```

## JWT

```yaml
auth:
  type: jwt
  jwt:
    issuer: https://auth.example.com
    audience: fastmcp-server
    jwksUri: https://auth.example.com/.well-known/jwks.json
```

For local HS256 testing, use an existing secret containing the shared key:

```yaml
auth:
  type: jwt
  jwt:
    algorithm: HS256
    publicKeyExistingSecret: fastmcp-jwt
    publicKeyExistingSecretKey: public-key
```

## Multi-Provider

```yaml
auth:
  type: multi
  providers:
    - bearer
    - jwt
  scopes:
    - mcp:read
  reloadRequiredScopes:
    - mcp:admin
```

## Production Guardrail

When `server.environment` is `staging`, `prod`, or `production`, authentication must be enabled unless `auth.allowNoAuth=true` is set explicitly.

<!-- @AI-METADATA
type: chart-docs
title: FastMCP Server Authentication
description: Authentication guide for the FastMCP Server chart
keywords: fastmcp, authentication, bearer, jwt, multi-auth
purpose: Feature-specific chart documentation
scope: Chart
relations:
  - charts/fastmcp-server/values.yaml
  - charts/fastmcp-server/templates/deployment.yaml
path: charts/fastmcp-server/docs/authentication.md
version: 1.0
date: 2026-04-26
-->
