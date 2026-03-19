# RabbitMQ

RabbitMQ para Kubernetes com modos explícitos `single-node` e `cluster`, suporte a Management UI, TLS opcional, métricas opcionais e documentação operacional por arquitetura.

## Install

```bash
helm install rabbitmq oci://ghcr.io/mberlofa/helm/rabbitmq -f values.yaml
```

## Arquiteturas suportadas

| Arquitetura | Quando usar | Documento |
|-------------|-------------|-----------|
| `single-node` | ambientes simples, dev, homologação e workloads sem requisito de failover entre nós | [docs/single-node.md](docs/single-node.md) |
| `cluster` | produção com múltiplos nós, filas quorum e redundância entre brokers | [docs/cluster.md](docs/cluster.md) |

## O que este chart cobre

- escolha explícita de arquitetura por `architecture`
- autenticação com usuário, senha e Erlang cookie
- `existingSecret` para credenciais gerenciadas fora do chart
- modelagem transparente de `rabbitmq.conf` e `enabled_plugins`
- Management UI opcional
- TLS opcional para AMQP e Management UI
- métricas opcionais com plugin nativo do RabbitMQ
- `ServiceMonitor` opcional
- `PodDisruptionBudget` opcional

## Como escolher a arquitetura

- use `single-node` quando o objetivo principal for simplicidade operacional
- use `cluster` quando a fila precisar sobreviver à perda de um nó e a aplicação já operar corretamente com múltiplos brokers

Leitura recomendada antes da instalação:

- [Single Node](/C:/devops/berlofa/github/helm/charts/rabbitmq/docs/single-node.md)
- [Cluster](/C:/devops/berlofa/github/helm/charts/rabbitmq/docs/cluster.md)

## Direção operacional

- para produção, a recomendação é `cluster` com `queueDefaults.type=quorum`
- use `single-node` apenas quando HA entre brokers não for requisito
- não trate um cluster RabbitMQ como substituto para desenho ruim de filas, roteamento e consumidores

## Início rápido

Exemplo mínimo:

```yaml
architecture: single-node

auth:
  existingSecret: rabbitmq-auth

singleNode:
  persistence:
    enabled: true
    size: 8Gi
```

Exemplo de cluster:

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
  serviceMonitor:
    enabled: true
```

## Boas práticas

### Segurança

- use `auth.existingSecret` em produção
- mantenha o Erlang cookie estável entre reinícios e upgrades
- habilite TLS quando houver tráfego entre clientes fora da malha interna confiável
- restrinja a exposição da Management UI

### Filas e topologia

- em produção, prefira filas quorum em vez de mirrored classic queues
- use `cluster` apenas quando a aplicação realmente precisar da topologia multi-node
- valide comportamento de reconnect nos clientes antes de promover para produção

### Scheduling

- em `cluster`, distribua os pods entre nós ou zonas
- habilite `pdb.enabled=true` em clusters produtivos
- mantenha `replicaCount >= 3` para o baseline operacional do cluster

### Observabilidade

- habilite `metrics.enabled=true` em ambientes monitorados
- use `metrics.serviceMonitor.enabled=true` quando houver Prometheus Operator
- monitore memória, disco, conexões, filas, consumers e alarme local de nós

## Values principais

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `single-node` ou `cluster` | `single-node` |
| `image.repository` | RabbitMQ image repository | `rabbitmq` |
| `image.tag` | RabbitMQ image tag | `4.2.4-management` |
| `auth.username` | Application username | `user` |
| `auth.password` | Application password | `""` |
| `auth.erlangCookie` | Erlang cookie | `""` |
| `auth.existingSecret` | Existing secret for credentials | `""` |
| `queueDefaults.type` | `quorum` ou `classic` | `quorum` |
| `management.enabled` | Enable management plugin/UI | `true` |
| `management.ingress.enabled` | Enable management ingress | `false` |
| `tls.enabled` | Enable TLS listeners | `false` |
| `singleNode.persistence.enabled` | Enable PVC for single node | `true` |
| `cluster.replicaCount` | Number of cluster nodes | `3` |
| `cluster.partitionHandling` | Cluster partition handling | `pause_minority` |
| `metrics.enabled` | Enable RabbitMQ Prometheus plugin | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |

## CI scenarios

Os cenários em `ci/` validam o comportamento principal do chart:

- `single-node.yaml`
- `cluster.yaml`
- `secure.yaml`
- `existing-secret.yaml`
- `metrics.yaml`

## Examples

Veja `examples/`:

- `single-node.yaml`
- `cluster-ha.yaml`
- `management-tls.yaml`

## Notas importantes

- `cluster` não é uma abstração mágica de HA; filas, consumers e reconnect continuam sendo responsabilidade operacional da solução
- filas quorum são a orientação padrão para produção neste chart
- o chart não tenta orquestrar federação, shovel ou políticas avançadas na v1
