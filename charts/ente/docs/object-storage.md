# Object Storage

## Production contract

Ente requires an S3-compatible endpoint, region, bucket, access key, and secret
key. The logical upstream bucket key remains `b2-eu-cen` regardless of provider.

Use an endpoint with valid TLS that is reachable by Museum and every client.
Avoid cluster-local DNS names in production because presigned URLs are returned
to browsers and mobile devices.

## CORS

Allow the exact Photos, Accounts, Albums, and optional application origins.
Allow GET, HEAD, POST, PUT, and DELETE. Include `Content-Type`, `Content-MD5`,
and `UPLOAD-URL` in allowed headers. Expose provider response headers required
by clients.

## Provider addressing

Use virtual-host addressing by default. Enable `usePathStyle` only when required
by a compatible provider. `localBuckets` also disables upstream production S3
behavior and must remain false in production.

## Bucket features

Do not enable object lock or versioning on Ente file-data buckets. Upstream does
not handle those semantics. Use separate provider-native backup destinations or
replication mechanisms instead.

## Validation

Test credentials with the provider CLI, then create an Ente account and perform
an upload and download. A successful Museum `/ping` is not an S3 test.

## Private endpoints

When NetworkPolicy is enabled, add provider CIDRs to
`networkPolicy.extraEgress` for shared access or
`networkPolicy.egress.museumExtraRules` for Museum only. DNS names cannot be
selected directly by Kubernetes NetworkPolicy.

## Troubleshooting

- Signature mismatch: verify endpoint, region, clock, and path-style mode.
- Browser CORS error: verify exact origins, methods, and headers.
- Museum access works but client access fails: publish the same endpoint outside
  the cluster.
- Delete failures: remove object lock and versioning from file-data buckets.
