# Redis Cluster

## Quando usar

Use `cluster` quando você precisa de sharding nativo e seu cliente suporta Redis Cluster.

Cenários comuns:

- crescimento horizontal de dados
- necessidade de múltiplos masters
- aplicações cluster-aware

## O que essa arquitetura entrega

- múltiplos nós Redis
- bootstrap de cluster por Job
- réplicas por master
- serviço cliente para acesso ao conjunto de nós

## O que ela exige do cliente

- suporte a redirecionamento `MOVED`/`ASK`
- compatibilidade explícita com Redis Cluster

## Requisitos do ambiente

- número de nós coerente com `replicasPerMaster`
- persistência em todos os nós
- DNS estável entre pods
- clientes e bibliotecas validados para Redis Cluster

## Como pensar essa topologia

`cluster` é uma escolha de escala e disponibilidade, não apenas de redundância. O dado é fragmentado entre masters e o cliente precisa entender redirecionamentos e mapa de slots.

## Riscos comuns

- usar clientes não compatíveis com Redis Cluster
- escolher quantidade de nós incompatível com a estratégia de réplicas
- negligenciar rebalanceamento e expansão futura
- tratar cluster como simples substituto de `sentinel`

## Boas práticas de produção

- comece com 6 nós para 3 masters e 3 réplicas quando a carga justificar
- use anti-affinity e distribuição por zona
- mantenha PVC por nó
- habilite `pdb.enabled=true`
- monitore bootstrap, slots, failover e uso de memória por nó
- planeje janelas operacionais para expansão ou manutenção do cluster

## Boas práticas

- use números de nós compatíveis com `replicasPerMaster`
- valide os clients da aplicação antes de adotar esse modo
- use volumes persistentes em todos os nós
- habilite anti-affinity e `pdb.enabled=true`
- monitore bootstrap, rebalanceamento e saúde do cluster

## Valores mais relevantes

| Parameter | Description |
|-----------|-------------|
| `architecture` | Deve ser `cluster` |
| `cluster.nodes` | Quantidade total de nós |
| `cluster.replicasPerMaster` | Réplicas por master |
| `cluster.persistence.enabled` | PVC por nó |
| `cluster.persistence.size` | Tamanho do volume por nó |
| `metrics.enabled` | Exporter para monitoramento |

## Exemplo base

```yaml
architecture: cluster

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

cluster:
  nodes: 6
  replicasPerMaster: 1
  persistence:
    enabled: true
    size: 20Gi
```

## Quando não usar

- quando a aplicação só precisa de um primário e réplicas de leitura
- quando o cliente não entende Redis Cluster
- quando o volume de dados ainda cabe de forma confortável em uma única instância
