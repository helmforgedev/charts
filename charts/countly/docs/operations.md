<!-- SPDX-License-Identifier: Apache-2.0 -->
# Operations

## Preflight

Confirm MongoDB capacity, storage, credentials, DNS, and TLS before installation.
For production, render [the production example](../examples/production.yaml)
and replace every placeholder.

## Health Verification

```bash
kubectl -n countly rollout status deployment/countly-countly
kubectl -n countly get pods,service,endpoints
kubectl -n countly logs deployment/countly-countly --all-containers
```

Port-forward the dashboard and ingestion API independently:

```bash
kubectl -n countly port-forward service/countly-countly 8080:80
kubectl -n countly port-forward service/countly-countly 3001:3001
```

A dashboard HTTP response and an API response below HTTP 500 prove the two
processes are listening. The API rejects incomplete event requests by design.

## Upgrades

1. Back up MongoDB and verify the resulting object.
2. Review Countly release notes and enabled plugin compatibility.
3. Update the chart repository and inspect the rendered diff.
4. Run `helm upgrade` and watch the Deployment plus MongoDB.
5. Re-test dashboard login and SDK event ingestion.

Never change `Chart.yaml` versions locally; HelmForge release automation owns
chart versions.

## Troubleshooting

- **Countly waits for MongoDB:** check the MongoDB Service, endpoints, Secret
  key, and URI `authSource`.
- **Dashboard ready but SDK events fail:** verify the API Service port and any
  separate public route. The standard Ingress targets only the dashboard.
- **Custom ports do not respond:** ensure both Countly listener values and the
  intended Service ports were changed; do not make the two listeners equal.
- **Plugin calls time out:** inspect the enabled plugin's destinations and the
  configured NetworkPolicy egress.
- **Backup Job fails:** inspect both init-container and uploader logs, the URI
  Secret key, temporary disk capacity, S3 endpoint, and credentials.
