# ADR-004 — Sem microserviços na fase 1

- **Status:** Aceito
- **Data:** 03/10/2026

## Contexto

A aplicação tem cinco rotas e uma tabela. O problema a resolver é de disponibilidade e operação da plataforma, não de acoplamento entre domínios ou de escala desigual entre partes do sistema.

## Decisão

Manter a aplicação como **monólito containerizado**. A evolução começa por modularização interna; a extração de um serviço só acontece diante de um motivo concreto.

## Critérios para rever a decisão

- Times diferentes precisam publicar partes do sistema de forma independente.
- Uma parte do sistema precisa escalar em proporção muito diferente das demais.
- O ciclo de deploy do monólito limita a entrega.
- Partes do sistema têm requisitos distintos de disponibilidade, segurança ou dados.

## Alternativas consideradas

| Alternativa | Por que não |
| --- | --- |
| Dividir em serviços desde já | Acrescenta rede entre serviços, observabilidade distribuída e mais pipelines, sem um problema que isso resolva |
| Funções serverless por rota | Muda o modelo de execução e de conexão com o banco, o que é uma reescrita |

## Consequências

- Um único artefato para construir, testar, publicar e reverter.
- A versão 1.1.0 já separa rotas, configuração e acesso a banco em módulos, o que mantém aberto o caminho de uma extração futura.
- Escala é sempre do serviço inteiro.
