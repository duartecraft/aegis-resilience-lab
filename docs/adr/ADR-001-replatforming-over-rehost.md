# ADR-001 — Replatforming incremental em vez de rehost

- **Status:** Aceito
- **Data:** 03/10/2026

## Contexto

O laboratório de origem roda uma API containerizada em duas VMs, atrás de um load balancer único e com um PostgreSQL único. A camada de aplicação tolera a perda de uma instância; banco e load balancer são pontos únicos de falha. Não há alertas, métricas nem backup comprovado.

O objetivo da migração é elevar disponibilidade e reduzir operação manual, não apenas trocar de provedor.

## Decisão

Adotar **replatforming incremental**: manter o comportamento central da aplicação e mudar a plataforma de execução para serviços gerenciados (load balancer, containers e banco), em fases com aprovação e rollback individuais.

## Alternativas consideradas

| Alternativa | Por que não |
| --- | --- |
| Rehost (recriar as VMs na nuvem) | Preserva os dois pontos únicos de falha e todo o trabalho de manter sistema operacional, balanceador e banco |
| Refactor para microserviços | A aplicação é pequena; ver [ADR-004](ADR-004-no-microservices-in-phase-one.md) |
| Permanecer na origem e adicionar redundância manual | Exigiria construir e operar replicação de banco e par de load balancers, sem ganho sobre o serviço gerenciado |

## Consequências

- A aplicação precisa de ajustes pequenos: configuração por variáveis separadas, TLS até o banco e migração de schema fora do startup. Foram feitos na versão 1.1.0.
- Os pontos únicos de falha são resolvidos por serviços gerenciados, e não por operação própria.
- O ambiente passa a depender de serviços específicos do provedor de destino; o container e o PostgreSQL permanecem portáveis.
- Cada fase pode ser desfeita sem afetar a origem.
