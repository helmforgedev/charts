# Redis Standalone

## Quando usar

Use `standalone` quando você precisa de Redis simples, previsível e com baixo custo operacional.

Cenários comuns:

- desenvolvimento
- homologação
- cache local de aplicação
- cargas pequenas sem necessidade de failover

## O que essa arquitetura entrega

- um único nó Redis
- persistência opcional
- autenticação por senha
- métricas opcionais

## O que ela não entrega

- failover automático
- alta disponibilidade
- escalabilidade horizontal por shards

## Requisitos do ambiente

- PVC quando o dado não puder ser descartado
- storage class com desempenho coerente com a carga de escrita
- requests e limits compatíveis com crescimento de memória do dataset

## Fluxo operacional recomendado

1. usar `auth.enabled=true`
2. referenciar `auth.existingSecret` em produção
3. habilitar persistência quando Redis guardar mais do que cache descartável
4. habilitar métricas se o ambiente já possui Prometheus

## Riscos comuns

- tratar `standalone` como solução HA
- usar volume efêmero para dados que precisam sobreviver a reinício
- subdimensionar memória e gerar eviction pelo próprio Redis ou pelo nó
- expor o serviço para fora do cluster sem controles adicionais

## Boas práticas

- mantenha `auth.enabled=true`
- use volume persistente quando o dado não puder ser perdido
- não exponha o serviço externamente sem necessidade
- habilite métricas se o ambiente for monitorado

## Valores mais relevantes

| Parameter | Description |
|-----------|-------------|
| `architecture` | Deve permanecer `standalone` |
| `auth.enabled` | Habilita senha |
| `auth.existingSecret` | Usa secret existente para a senha |
| `standalone.persistence.enabled` | Ativa PVC |
| `standalone.persistence.size` | Tamanho do volume |
| `metrics.enabled` | Habilita exporter |

## Exemplo mínimo

```yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

standalone:
  persistence:
    enabled: true
    size: 10Gi
```

## Quando migrar para outro modo

- migre para `replication` quando leitura separada de escrita passar a ser necessária
- migre para `sentinel` quando failover automático de primário virar requisito
- migre para `cluster` quando um único nó não atender mais em capacidade ou throughput
