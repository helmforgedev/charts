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
