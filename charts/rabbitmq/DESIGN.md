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
