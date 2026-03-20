---
title: MySQL - Secret Rotation
description: Password rotation
keywords: [mysql, secret, rotation, password]
scope: chart-docs
audience: users
---

# Secret Rotation

## Scope

This chart supports password and TLS material through existing Kubernetes secrets. Rotation remains an operational workflow outside the chart.

## Password rotation

- update the secret referenced by `auth.existingSecret`
- restart MySQL workloads in a controlled maintenance window
- verify application connectivity after the rollout
- if replication is enabled, rotate replication credentials with care and confirm replicas can reconnect to the source

## TLS rotation

- update the secret referenced by `tls.existingSecret`
- roll the MySQL pods so the new certificates are mounted and loaded
- validate client connectivity and replication health after the rollout
- if `tls.requireSecureTransport=true`, confirm internal clients and application clients are ready before restarting traffic

## Operational guidance

- avoid rotating passwords and TLS material in the same change unless necessary
- validate one environment at a time
- document rollback steps before rotation
- for production, use an external secret manager or an automated secret delivery workflow
