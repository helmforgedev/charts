# RabbitMQ Single Node

## Quando usar

Use `single-node` quando a prioridade for simplicidade operacional.

Cenários comuns:

- desenvolvimento
- homologação
- cargas pequenas
- brokers internos sem requisito de failover entre nós

## O que essa arquitetura entrega

- um broker RabbitMQ
- Management UI opcional
- autenticação com usuário, senha e Erlang cookie
- persistência opcional
- TLS opcional
- métricas opcionais

## O que ela não entrega

- redundância entre brokers
- continuidade após perda do único nó
- tolerância a falha de nó para filas locais

## Boas práticas

- use `existingSecret` em produção
- mantenha persistência habilitada quando mensagens não puderem ser perdidas
- não exponha a Management UI sem necessidade
- habilite métricas em ambientes monitorados

## Exemplo base

```yaml
architecture: single-node

auth:
  existingSecret: rabbitmq-auth

singleNode:
  persistence:
    enabled: true
    size: 10Gi
```
