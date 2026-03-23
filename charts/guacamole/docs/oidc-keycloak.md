# OpenID Connect with Keycloak

This guide covers integrating Apache Guacamole with Keycloak using OpenID Connect (OIDC).

## Keycloak Setup

1. Log in to the Keycloak admin console.
2. Create a new client (or use an existing realm):
   - **Client ID**: `guacamole`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `public`
   - **Valid Redirect URIs**: `https://guacamole.example.com/*`
   - **Web Origins**: `https://guacamole.example.com`
3. Under **Client Scopes**, ensure `email`, `profile`, and `groups` are included.
4. Create a **Groups** mapper if you want group-based access control:
   - **Mapper Type**: Group Membership
   - **Token Claim Name**: `groups`
   - **Full group path**: OFF

## Chart Configuration

```yaml
oidc:
  enabled: true
  authorizationEndpoint: https://keycloak.example.com/realms/master/protocol/openid-connect/auth
  jwksEndpoint: https://keycloak.example.com/realms/master/protocol/openid-connect/certs
  issuer: https://keycloak.example.com/realms/master
  clientId: guacamole
  scope: "openid email profile"
  usernameClaim: "preferred_username"
  groupsClaim: "groups"

ingress:
  enabled: true
  hosts:
    - host: guacamole.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - guacamole.example.com
      secretName: guacamole-tls
```

The `redirectUri` is auto-detected from the ingress configuration when left empty.

## How It Works

1. User accesses Guacamole and is redirected to Keycloak for authentication.
2. After login, Keycloak redirects back to Guacamole with an authorization code.
3. Guacamole exchanges the code for an ID token and validates it using the JWKS endpoint.
4. The `preferred_username` claim is used as the Guacamole username.
5. The `groups` claim maps Keycloak groups to Guacamole user groups.

## SAML Alternative

If you prefer SAML over OIDC, see [Keycloak SAML documentation](https://www.keycloak.org/docs/latest/server_admin/#saml-clients) and configure the `saml` section in values.yaml instead.

<!-- @AI-METADATA
type: chart-docs
title: Guacamole OIDC with Keycloak
description: OpenID Connect integration guide for Apache Guacamole with Keycloak
keywords: guacamole, oidc, openid-connect, keycloak, sso
purpose: Guide OIDC setup with Keycloak identity provider
scope: Chart
relations:
  - charts/guacamole/README.md
  - charts/guacamole/values.yaml
path: charts/guacamole/docs/oidc-keycloak.md
version: 1.0
date: 2026-03-23
-->
