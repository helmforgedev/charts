# Redis Sentinel

## Quando usar

Use `sentinel` quando a aplicação ou o cliente conseguem consultar Sentinel para descobrir o primário atual.

Cenários comuns:

- HA com descoberta de primário
- clientes compatíveis com Sentinel
- necessidade de failover sem Redis Cluster

## O que essa arquitetura entrega

- topologia de dados com primário e réplicas
- pods Sentinel dedicados
- quorum configurável
- descoberta de primário por serviço Sentinel

## O que ela exige do cliente

- o cliente deve suportar Redis Sentinel
- a aplicação deve estar preparada para a troca de primário via Sentinel

## Requisitos do ambiente

- ao menos 3 instâncias de Sentinel para quorum consistente
- réplicas suficientes para failover sem perda do serviço
- distribuição entre nós ou zonas para reduzir falha correlacionada
- clientes e bibliotecas validados para Sentinel antes da entrada em produção

## Como pensar essa topologia

`sentinel` é a opção certa quando você quer failover automático sem migrar para o contrato do Redis Cluster. Ela mantém um primário ativo por vez e usa Sentinels para eleição, observação de saúde e promoção de réplicas.

## Riscos comuns

- escolher `quorum` incompatível com a quantidade de sentinels
- concentrar sentinels e réplicas no mesmo nó
- usar clientes que não fazem redescoberta do primário
- tratar Sentinel como substituto de sharding

## Boas práticas de produção

- mantenha 3 sentinels como baseline mínima
- use `quorum` de maioria simples
- distribua sentinels, primário e réplicas entre domínios de falha
- habilite `pdb.enabled=true`
- valide failover real e tempo de reconexão da aplicação
- monitore troca de primário, atraso de réplica e indisponibilidade de sentinels

## Boas práticas

- use no mínimo 3 sentinels
- mantenha `quorum` coerente com o número de sentinels
- distribua sentinels e réplicas em nós distintos
- habilite `pdb.enabled=true`
- valide o comportamento de failover no ambiente real

## Valores mais relevantes

| Parameter | Description |
|-----------|-------------|
| `architecture` | Deve ser `sentinel` |
| `replication.replicaCount` | Quantidade de réplicas Redis |
| `sentinel.replicaCount` | Quantidade de pods Sentinel |
| `sentinel.quorum` | Quorum para decisões de failover |
| `pdb.enabled` | Proteção contra interrupções planejadas |
| `metrics.enabled` | Exporter para monitoramento |

## Exemplo base

```yaml
architecture: sentinel

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

replication:
  replicaCount: 2

sentinel:
  replicaCount: 3
  quorum: 2
```

## Quando migrar para outro modo

- volte para `replication` se a aplicação não conseguir operar com Sentinel
- migre para `cluster` quando a necessidade principal deixar de ser failover e passar a ser escala horizontal com shards
