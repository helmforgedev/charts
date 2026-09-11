# Authentication and secret lifecycle

## Private bootstrap

Native login is enabled by default. Obtain the generated password from the Secret
named in helm get notes, using a trusted terminal. The account name defaults to
admin. TLS termination should be configured before sharing access outside the lab.
The default ClusterIP and same-namespace ingress policy limit initial exposure.

## Existing credentials

Set auth.existingSecret to a Secret in the release namespace containing password
and secret-key. The latter must be a base64 string representing exactly 64 random
bytes. It is itself a string inside the Kubernetes Secret; Secret data fields add
the normal Kubernetes base64 layer. Prefer secret management tooling over putting
credentials on shell command lines, in Git or in Helm values files.

Generate a compatible signing value with the pinned upstream image:

~~~sh
docker run --rm docker.io/glanceapp/glance:v0.8.6 secret:make
~~~

The command produces secret material. Store its output directly in your trusted
secret manager and do not paste it into logs, issue bodies or shared documentation.
Configure alternate keys with auth.passwordKey and auth.secretKeyKey.

## External Secrets

The chart implements externalSecrets.enabled, refreshInterval and items[]. Each
item carries its own complete operator spec. The target name must match the auth
or widget Secret reference. Install ESO and provision the SecretStore first.
examples/external-secrets.yaml uses a production store name, not the test provider.
ci/external-secrets-values.yaml is a deterministic lab-only fixture.

Confirm the operator reports Ready=True and SecretSynced before troubleshooting
Glance login. A missing projection prevents startup and is not an application
password failure. Never use the fake store outside a disposable validation lab.

## Rotation

An ordinary Helm upgrade retains generated credentials through lookup. GitOps
renderers that cannot query the cluster should use an externally owned Secret.
To change credentials in a chart-owned Secret, pass explicit auth values through a
secure delivery mechanism. Changing password preserves existing signed sessions;
rotate secret-key as well when all sessions must be invalidated.
For referenced Secrets, update the source and then restart the Deployment after
the operator has synchronized. A reloader may automate that rollout.

The upstream login limiter is per process. Multiple replicas do not provide a
shared failed-login counter. Enforce a suitable limit at the authenticated edge.

<!-- @AI-METADATA
type: guide
title: Glance docs/authentication
description: Product-specific Glance deployment and operation contract
keywords: glance, helm, authentication, widgets, kubernetes
purpose: Operate the Glance chart safely
scope: charts/glance
-->
