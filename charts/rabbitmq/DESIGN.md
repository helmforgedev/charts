# RabbitMQ Design Brief

v1 scope:

- explicit `single-node` and `cluster`
- official `rabbitmq` image with management flavor
- management UI and ingress optional
- optional TLS
- optional metrics with native RabbitMQ Prometheus plugin
- clear `rabbitmq.conf` and plugins model
- `existingSecret` for username, password and Erlang cookie

non-goals:

- federation
- shovel
- embedded policy orchestration
- operator-like day-2 lifecycle automation

design notes:

- default queue type is `quorum`
- cluster formation uses `rabbitmq_peer_discovery_k8s`
- no branch from generic abstractions

<!-- @AI-METADATA
type: design
title: RabbitMQ Chart Design
description: Design document for RabbitMQ Helm chart with single-node and cluster modes

keywords: rabbitmq, design, architecture, single-node, cluster, amqp

purpose: Document design decisions and non-goals for the RabbitMQ chart
scope: Chart Design

relations:
  - charts/rabbitmq/README.md
path: charts/rabbitmq/DESIGN.md
version: 1.0
date: 2026-03-20
-->
