# Jenkins

Jenkins is an open source automation server for continuous integration and delivery.

This HelmForge chart deploys the official `jenkins/jenkins` controller image
with production-oriented Kubernetes defaults. It includes a StatefulSet
controller, persistent Jenkins home, secure initial admin bootstrap, optional
Jenkins Configuration as Code, optional plugin installation with
`jenkins-plugin-cli`, optional RBAC for Kubernetes agents, dual-stack Service
support, Gateway API, Ingress, NetworkPolicy, ExternalSecret, ServiceMonitor,
PodDisruptionBudget, and Helm tests.

NetworkPolicy supports `networkPolicy.extraEgress` for appending custom egress
rules without replacing the chart-generated DNS, cluster, internet, and
`networkPolicy.egress.extraRules` controls.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install jenkins helmforge/jenkins
```

## Admin Credentials

By default the chart creates an initial admin user and stores the generated password in a Kubernetes Secret:

```bash
kubectl get secret jenkins-admin -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

Use `admin.existingSecret` with `admin.existingSecretUserKey` and
`admin.existingSecretPasswordKey` to manage credentials externally.

## Plugins and JCasC

The chart can install pinned plugins before Jenkins starts:

```yaml
plugins:
  install:
    enabled: true
    initializeOnce: true
    list:
      - kubernetes:4423.vb_59f230b_ce53
      - workflow-aggregator:608.v67378e9d3db_1
      - git:5.10.1
      - configuration-as-code:2074.va_57f83f7a_10b_
```

JCasC files can be mounted and activated with `jcasC.enabled=true`. The
`configuration-as-code` plugin must be included in the image or installed
through the plugin bootstrap.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: jenkins.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
  hostnames:
    - jenkins.example.com
```

## Validation

This chart is tested with Helm lint, strict lint, Helm unittest, kubeconform,
Artifact Hub lint, markdown lint, security scans, and k3d runtime validation.

### Security Scan: `jenkins`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **86.111115%** |

> Security posture acceptable with controller security contexts, non-root execution, optional NetworkPolicy, and operator-controlled plugin/JCasC inputs.

## Documentation

- [Design](./DESIGN.md)
- [Production guide](./docs/production.md)
- [Networking](./docs/networking.md)
- [External Secrets](./docs/external-secrets.md)
- [JCasC and plugins](./docs/jcasc-and-plugins.md)
