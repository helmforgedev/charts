# Redis

Implantação de Redis em Kubernetes com suporte às arquiteturas `standalone`, `replication`, `sentinel` e `cluster`.

## Install

```bash
helm install redis oci://ghcr.io/mberlofa/helm/redis -f values.yaml
```

## O que este chart cobre

- escolha explícita de arquitetura por `architecture`
- autenticação com senha gerenciada pelo chart ou por `existingSecret`
- persistência por topologia
- métricas opcionais com `redis_exporter`
- `ServiceMonitor` opcional para Prometheus Operator
- objetos de disponibilidade como `PodDisruptionBudget`
- exemplos e cenários de CI separados por modo operacional

## Arquiteturas suportadas

| Arquitetura | Quando usar | Documento |
|-------------|-------------|-----------|
| `standalone` | desenvolvimento, ambientes simples ou workloads sem necessidade de HA | [docs/standalone.md](docs/standalone.md) |
| `replication` | primário fixo com réplicas de leitura, sem failover por Sentinel | [docs/replication.md](docs/replication.md) |
| `sentinel` | failover automático com descoberta de primário via Sentinel | [docs/sentinel.md](docs/sentinel.md) |
| `cluster` | sharding nativo e alta disponibilidade no protocolo Redis Cluster | [docs/cluster.md](docs/cluster.md) |

## Como escolher a arquitetura

- Use `standalone` quando a simplicidade operacional for mais importante que HA.
- Use `replication` quando você precisa separar escrita e leitura, mas a promoção automática de primário não faz parte do requisito.
- Use `sentinel` quando o cliente consegue falar com Redis Sentinel e você precisa de descoberta de primário e failover.
- Use `cluster` quando o cliente suporta Redis Cluster e você precisa de sharding horizontal real.

Leitura recomendada antes da instalação:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)
- [Sentinel](docs/sentinel.md)
- [Cluster](docs/cluster.md)

## Referências oficiais do produto

- Redis Sentinel: https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/
- Redis Cluster: https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/

## Features

- autenticação por senha com suporte a `existingSecret`
- persistência por arquitetura
- serviços específicos por topologia
- `StatefulSet` próprios para os modos stateful
- bootstrap de cluster por `Job`
- métricas opcionais com `redis_exporter`
- integração opcional com `ServiceMonitor`

## Requisitos operacionais

- storage class válida para ambientes com persistência
- clientes compatíveis com a arquitetura escolhida
- `existingSecret` obrigatório quando credenciais são gerenciadas fora do chart
- cuidado especial com afinidade e distribuição dos pods em modos HA

## Início rápido

Exemplo mínimo com senha em secret existente:

```yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

standalone:
  persistence:
    enabled: true
    size: 8Gi
```

Aplicar:

```bash
helm install redis oci://ghcr.io/mberlofa/helm/redis -f redis-values.yaml
```

## Recomendações de boas práticas

### Segurança

- prefira `auth.enabled=true`
- em produção, use `auth.existingSecret` em vez de senha inline
- habilite TLS apenas quando o material de certificado já estiver definido
- restrinja exposição de portas ao mínimo necessário

### Persistência

- use volumes persistentes em todas as arquiteturas stateful relevantes
- trate `cluster` e `sentinel` como topologias de produção, não como cenários efêmeros
- alinhe o tamanho do volume ao padrão de retenção e carga real

### Agendamento

- habilite anti-affinity para `replication`, `sentinel` e `cluster`
- habilite `pdb.enabled=true` em modos HA
- distribua pods por `topologySpreadConstraints` quando o cluster permitir

### Observabilidade

- habilite `metrics.enabled=true` para ambientes monitorados
- habilite `metrics.serviceMonitor.enabled=true` quando usar Prometheus Operator
- monitore latência, uso de memória, replicas em atraso e estado do cluster

## Padrões de segurança

- prefira `auth.existingSecret` para produção
- evite expor Redis fora da rede interna do cluster sem um motivo forte
- use `networkPolicy` externa ou controles equivalentes do cluster quando aplicável
- combine requests/limits, anti-affinity e PDB para reduzir indisponibilidade durante manutenção

## Operação por arquitetura

- `standalone`: menor custo operacional, sem failover
- `replication`: um primário fixo com réplicas de leitura
- `sentinel`: failover automático para cenários compatíveis com Sentinel
- `cluster`: sharding e alta disponibilidade nativos do Redis Cluster

Cada modo tem contratos diferentes de cliente, failover, descoberta e escalabilidade. Escolha a topologia pelo comportamento exigido pela aplicação, não apenas pelo desejo de ter HA.

## Values principais

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `standalone`, `replication`, `sentinel`, `cluster` | `standalone` |
| `image.repository` | Redis image repository | `redis` |
| `image.tag` | Redis image tag | `8.6.0` |
| `auth.enabled` | Enable password auth | `true` |
| `auth.password` | Redis password | `""` |
| `auth.existingSecret` | Existing auth secret | `""` |
| `auth.existingSecretPasswordKey` | Secret key used for the password | `redis-password` |
| `tls.enabled` | Enable TLS | `false` |
| `standalone.persistence.enabled` | Enable persistence for standalone | `true` |
| `replication.replicaCount` | Number of replica pods | `2` |
| `sentinel.replicaCount` | Number of sentinel pods | `3` |
| `sentinel.quorum` | Sentinel quorum | `2` |
| `cluster.nodes` | Number of Redis Cluster nodes | `6` |
| `cluster.replicasPerMaster` | Replicas per master in cluster bootstrap | `1` |
| `metrics.enabled` | Enable redis exporter sidecar | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |

## CI scenarios

Os cenários em `ci/` foram desenhados para validar comportamentos específicos:

- `standalone.yaml`
- `replication.yaml`
- `sentinel.yaml`
- `cluster.yaml`
- `existing-secret.yaml`
- `metrics.yaml`

## Examples

Veja `examples/`:

- `standalone-simple.yaml`
- `replication-production.yaml`
- `cluster.yaml`

## Notas importantes

- `replication` e `sentinel` são diferentes por contrato operacional.
- `cluster` exige cliente compatível com Redis Cluster.
- se `auth.password` não for informado e `auth.existingSecret` não for usado, o chart gera a senha automaticamente
- para operação em produção, leia o documento da arquitetura escolhida antes de instalar
