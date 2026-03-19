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

## Incident guidance

- if the source fails, the chart will not promote a replica automatically
- operator teams need a runbook for manual promotion, restore, or rebuild
- after manual intervention, document whether the old source will be rebuilt or discarded

## Replica rebuild notes

- confirm which replica is healthiest before any promotion or rebuild attempt
- stop application write traffic before changing source topology manually
- rebuild old replicas against the chosen source instead of assuming they will self-heal correctly
- validate replication status before reintroducing read traffic to the replicas Service
