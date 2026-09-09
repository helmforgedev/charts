# Moodle deployment examples

| Directory | Purpose | Prerequisites |
| --- | --- | --- |
| simple | Disposable local learning site; never real student data | None beyond the lab |
| staging | HTTPS URL with email disabled and Redis sessions | Configure routing/TLS separately |
| production | Single web replica with ingress | learning-admin and learning-tls Secrets |
| production-ha | Three web replicas with HPA | Real RWX PVC, external DB/Redis, credentials and CA |
| external-secrets | Fake-provider integration test | HelmForge fake ClusterSecretStore; replace for production |
| monitoring | Authenticated application metrics and alert rules | Prometheus Operator; moodle-monitoring Secret with token key; adapt selectors |

Render each file with helm template before installing. Example hostnames are
reserved domains: replace them with your institution's actual DNS names. The
production HA example intentionally does not create external infrastructure.
