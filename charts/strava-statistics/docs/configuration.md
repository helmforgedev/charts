# Statistics for Strava Configuration

Statistics for Strava needs Strava OAuth credentials and an application URL that matches how users access the dashboard.

## Credentials

For local tests, credentials can be provided directly:

```yaml
strava:
  clientId: "12345"
  clientSecret: "change-me"
  refreshToken: "change-me"
```

For production, prefer an existing Secret:

```yaml
strava:
  existingSecret: strava-credentials
  existingSecretClientIdKey: client-id
  existingSecretClientSecretKey: client-secret
  existingSecretRefreshTokenKey: refresh-token
```

## External Secrets

```yaml
externalSecrets:
  enabled: true
  items:
    - name: strava
      storeRef:
        name: platform-secrets
        kind: ClusterSecretStore
      targetName: strava-credentials
      data:
        - secretKey: client-id
          remoteRef:
            key: strava/oauth
            property: client-id
        - secretKey: client-secret
          remoteRef:
            key: strava/oauth
            property: client-secret
        - secretKey: refresh-token
          remoteRef:
            key: strava/oauth
            property: refresh-token

strava:
  existingSecret: strava-credentials
```

## Public URL

Set `strava.config.general.appUrl` to the URL users will use in the browser:

```yaml
strava:
  config: |
    general:
      appUrl: "https://strava.example.com/"
```

This value must match the OAuth callback URL configured in the Strava application.

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - strava.example.com
```

## Dual Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

