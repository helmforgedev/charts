# Replication Operations

## Operational contract

This chart provides:

- one fixed writable source
- asynchronous read replicas
- a dedicated replicas Service for read-only traffic

This chart does not provide:

- automatic failover
- automatic source promotion
- operator-style topology reconciliation

## Traffic model

- send write traffic to the source Service
- send read traffic to the replicas Service
- do not assume the base client Service is a smart read/write router

## Maintenance guidance

- use `pdb.enabled=true` before planned maintenance in replication mode
- prefer anti-affinity or topology spread in multi-node environments
- monitor replica lag before and after maintenance windows
- consider `replication.readReplicas.probes.requireRunningReplication=true` when readiness should reflect both read-only role and replication thread health

## Incident guidance

- if the source fails, the chart will not promote a replica automatically
- operator teams need a runbook for manual promotion, restore, or rebuild
- after manual intervention, document whether the old source will be rebuilt or discarded

## Replica rebuild notes

- confirm which replica is healthiest before any promotion or rebuild attempt
- stop application write traffic before changing source topology manually
- rebuild old replicas against the chosen source instead of assuming they will self-heal correctly
- validate replication status before reintroducing read traffic to the replicas Service

## Rebuild a replica manually

If a replica drifts or becomes unrecoverable, treat it as disposable state and rebuild it from the source.

Suggested approach:

1. stop sending read traffic that depends on the affected replica
2. scale the replicas StatefulSet down if needed to isolate the affected ordinal
3. remove the PVC that belongs to the replica you want to rebuild
4. scale the replicas StatefulSet back to the desired count
5. wait for the init container bootstrap to clone from the source again
6. verify `SHOW REPLICA STATUS\G` on the rebuilt pod before sending read traffic back to the replicas Service

Practical commands:

```bash
kubectl scale statefulset <release>-mysql-replicas -n <namespace> --replicas=1
kubectl delete pvc data-<release>-mysql-replicas-1 -n <namespace>
kubectl scale statefulset <release>-mysql-replicas -n <namespace> --replicas=2
kubectl exec -it <release>-mysql-replicas-1 -n <namespace> -- mysql -uroot -p -e "SHOW REPLICA STATUS\\G"
```

Adjust names and ordinals to match your release.

<!-- @AI-METADATA
type: chart-docs
title: MySQL - Replication Ops
description: Replication maintenance

keywords: mysql, replication, operations

purpose: MySQL replication maintenance and operational procedures
scope: Chart Architecture

relations:
  - charts/mysql/docs/replication.md
path: charts/mysql/docs/replication-operations.md
version: 1.0
date: 2026-03-20
-->
