# Jenkins Production Guide

Use explicit values for persistence, credentials, plugin pinning, resources,
and network boundaries.

```yaml
persistence:
  enabled: true
  size: 100Gi

admin:
  create: true
  existingSecret: jenkins-admin

resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 4
    memory: 6Gi

networkPolicy:
  enabled: true
  egress:
    enabled: true
    allowDns: true
    allowInternet: true
```

## Credentials

Prefer `admin.existingSecret` or `externalSecrets.enabled=true` for production.
This avoids chart-generated credentials changing during GitOps reconciliation.

## Plugins

Pin plugin versions in `plugins.install.list`. Avoid `latest=true` in
production unless upgrades are intentionally tested in a staging environment.

## Upgrading to Jenkins 2.580.1

Back up `JENKINS_HOME` and validate the upgrade against the backup before
changing a production controller. Upgrade installed plugins before the core
upgrade and confirm that jobs and plugins load afterward.

The 2.580.x line removes several detached plugins from the Jenkins WAR. Most
connected installations resolve them from the update center automatically.
Controllers without update-center access must make any required detached
plugins available in `JENKINS_HOME/plugins` before startup. See the official
[Jenkins 2.580.x upgrade guide](https://www.jenkins.io/doc/upgrade-guide/2.580/)
for the affected plugins and compatibility details.

## Operations

After deployment:

```bash
helm test jenkins -n jenkins
kubectl get pods -n jenkins -l app.kubernetes.io/name=jenkins
kubectl logs -n jenkins statefulset/jenkins
```
