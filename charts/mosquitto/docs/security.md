# Security

## Runtime baseline

Broker containers run as UID/GID `1883`; MQTTX Web runs as UID/GID `1000`.
Both workloads use RuntimeDefault seccomp, prevent privilege escalation, drop
all capabilities, use a read-only root filesystem, and do not mount Kubernetes
API credentials. If an override relaxes those controls, treat it as a conscious
change to the pod trust boundary.

## Authentication and authorization

Anonymous access is enabled when `auth.enabled=false`. Production and
internet-facing deployments should enable password authentication, configure
least-privilege ACL rules, and source credentials from `auth.existingSecret`.
Mosquitto 2.1 password and ACL plugins read generated files at runtime. Rotate
the source Secret and perform a Helm upgrade so the checksum triggers a rollout.

## Transport security

Set `broker.tls.enabled=true` and provide `broker.tls.certSecretName` for TLS.
For mutual TLS, also configure the CA key, `requireCertificate`, and
`useIdentityAsUsername`. The chart neither issues nor renews certificates.

## Network isolation

`networkPolicy.enabled=true` allows ingress only to enabled named listener
ports. Extra ingress entries are additive. A compatible CNI must enforce the
policy; otherwise the manifests alone do not isolate traffic.

## Production checklist

- Enable authentication, ACLs, and TLS or mTLS.
- Keep image tags pinned and review upstream security releases.
- Set CPU/memory requests and broker connection, queue, and packet limits.
- Restrict ingress sources through NetworkPolicy additions or platform policy.
- Encrypt Kubernetes Secrets at rest and restrict RBAC access.
- Monitor authentication failures, bridge disconnects, and persistence errors.
