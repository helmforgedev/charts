# Custom WordPress PHP extension images

This example builds two user-owned images from the official images selected by
the chart:

- `runtime` derives from the digest-pinned `wordpress:7.1.3-apache` image for the WordPress Deployment.
- `cli` derives from the digest-pinned official `wordpress:cli-php8.3` companion for WP-CLI bootstrap and plugin Jobs.

Both targets compile `pdo_mysql` at image build time. Copy `Dockerfile` and
`workflow.yaml` into your own image repository, then place the workflow at
`.github/workflows/build-wordpress.yaml`. HelmForge does not build, publish, or
operate these user images.

The workflow builds a local image, blocks publication when Trivy finds an
unfixed high or critical vulnerability, then publishes a commit-SHA tag with
SBOM and provenance attestations. Use the digest printed in the workflow
summary for immutable deployments.

```yaml
image:
  repository: ghcr.io/example/wordpress-pdo-mysql
  tag: 0123456789abcdef0123456789abcdef01234567

bootstrap:
  image:
    repository: ghcr.io/example/wordpress-cli-pdo-mysql
    tag: 0123456789abcdef0123456789abcdef01234567

plugins:
  installer:
    image:
      repository: ghcr.io/example/wordpress-cli-pdo-mysql
      tag: 0123456789abcdef0123456789abcdef01234567

imagePullSecrets:
  - name: ghcr-auth
```

If a custom image retains the official `/usr/src/wordpress` layout and shell
utilities, set `coreSync.allowCustomImage=true` so chart-managed core
synchronization remains enabled for existing PVCs. Validate this compatibility
before production rollout.
