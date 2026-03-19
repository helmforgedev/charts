# RabbitMQ Cluster

## Quando usar

Use `cluster` quando a solução realmente precisar de múltiplos brokers.

Cenários comuns:

- produção com filas quorum
- ambientes com necessidade de redundância entre nós
- workloads com reconnect correto no cliente

## O que essa arquitetura entrega

- múltiplos nós RabbitMQ em `StatefulSet`
- clusterização via `rabbitmq_peer_discovery_k8s`
- Management UI opcional
- filas quorum como direção recomendada
- TLS opcional
- métricas opcionais

## O que ela exige

- ao menos 3 nós para um baseline produtivo
- persistência por nó
- clientes que lidem corretamente com reconexão
- distribuição dos pods entre nós ou zonas

## Boas práticas

- mantenha `cluster.replicaCount >= 3`
- use `queueDefaults.type=quorum`
- habilite `pdb.enabled=true`
- distribua os pods com affinity ou topology spread
- monitore memória, disco, filas, alarms e conexões

## Exemplo base

```yaml
architecture: cluster

auth:
  existingSecret: rabbitmq-auth

queueDefaults:
  type: quorum

cluster:
  replicaCount: 3
  persistence:
    enabled: true
    size: 20Gi

metrics:
  enabled: true
```
