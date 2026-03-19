# Redis Replication

## Quando usar

Use `replication` quando você precisa de um primário fixo para escrita e réplicas para leitura.

Cenários comuns:

- aplicações com leitura intensiva
- workloads que já tratam indisponibilidade do primário fora do chart
- ambientes que querem separar escrita e leitura sem Redis Cluster

## O que essa arquitetura entrega

- um primário
- N réplicas
- serviços separados para primário e réplicas
- persistência por role

## O que ela não entrega

- failover automático por Sentinel
- reconfiguração automática de clientes

## Requisitos do ambiente

- PVC separado para primário e réplicas
- rede estável entre os pods para replicação contínua
- estratégia de cliente que saiba qual endpoint usar para escrita e para leitura

## Como pensar essa topologia

`replication` é útil quando a aplicação quer escalar leitura, mas ainda aceita um primário estável e conhecido. Esse modo é mais simples que `sentinel`, porém desloca para a operação da aplicação e do time a responsabilidade por lidar com queda do primário.

## Riscos comuns

- assumir que réplicas resolvem HA sozinhas
- rotear escrita acidentalmente para réplicas
- não separar capacidade de CPU, memória e IOPS entre primário e réplicas
- executar todos os pods no mesmo nó ou zona

## Boas práticas de produção

- mantenha ao menos 2 réplicas em ambientes críticos
- use anti-affinity e `topologySpreadConstraints`
- habilite `pdb.enabled=true`
- trate o serviço do primário como endpoint exclusivo de escrita
- monitore atraso de replicação e reinicializações de pods

## Boas práticas

- use `auth.existingSecret`
- mantenha anti-affinity habilitada no cluster via values
- habilite `pdb.enabled=true` em produção
- dimensione storage e recursos separadamente para primário e réplicas

## Valores mais relevantes

| Parameter | Description |
|-----------|-------------|
| `architecture` | Deve ser `replication` |
| `replication.replicaCount` | Número de réplicas |
| `replication.primary.persistence.*` | Persistência do primário |
| `replication.replica.persistence.*` | Persistência das réplicas |
| `pdb.enabled` | Proteção contra indisponibilidade planejada |
| `metrics.enabled` | Exporter para monitoramento |

## Exemplo base

```yaml
architecture: replication

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

replication:
  replicaCount: 2
  primary:
    persistence:
      enabled: true
      size: 50Gi
  replica:
    persistence:
      enabled: true
      size: 50Gi
```

## Quando migrar para outro modo

- migre para `sentinel` quando a promoção automática de primário se tornar requisito
- migre para `cluster` quando a necessidade deixar de ser apenas leitura escalável e passar a exigir sharding real
