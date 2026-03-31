# RabbitMQ Single Node

## When to use

Use `single-node` when simplicity is the main goal.

Common cases:

- development
- staging
- small workloads
- internal brokers without node-level failover requirements

## What this architecture delivers

- one RabbitMQ broker
- optional Management UI
- authentication with username, password, and Erlang cookie
- optional persistence
- optional TLS
- optional metrics

## What it does not deliver

- broker redundancy
- continuity after losing the only node
- node-failure tolerance for local queues

## Best practices

- use `existingSecret` in production
- keep persistence enabled when messages cannot be lost
- do not expose the Management UI unnecessarily
- enable metrics in monitored environments

## Base example

```yaml
architecture: single-node

auth:
  existingSecret: rabbitmq-auth

singleNode:
  persistence:
    enabled: true
    size: 10Gi
```

<!-- @AI-METADATA
type: chart-docs
title: RabbitMQ - Single Node
description: Single-node deployment

keywords: rabbitmq, standalone

purpose: Single-node RabbitMQ deployment guide
scope: Chart Architecture

relations:
  - charts/rabbitmq/README.md
path: charts/rabbitmq/docs/single-node.md
version: 1.0
date: 2026-03-20
-->
