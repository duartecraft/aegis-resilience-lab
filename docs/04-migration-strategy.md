# 04 — Estratégia de migração

> **Estado: estratégia decidida e exercitada em um laboratório efêmero em 03 e 04/10/2026.** Os resultados estão em [docs/evidence/2026-10-03-aws.md](evidence/2026-10-03-aws.md). Ficaram pendentes: os runbooks, o disparo real de nove dos onze alarmes e o ensaio de virada de tráfego.

A estratégia é **replatforming incremental**: a aplicação mantém seu comportamento central e passa a rodar sobre serviços gerenciados, que reduzem o esforço operacional e elevam disponibilidade, segurança e observabilidade.

## Estratégias comparadas

| Estratégia | O que muda | A favor | Contra | Decisão |
| --- | --- | --- | --- | --- |
| Rehost | Nada na aplicação; as VMs são recriadas na nuvem | Mais rápido | Leva junto os dois pontos únicos de falha e todo o trabalho manual | Rejeitada |
| **Replatform** | A plataforma de execução, o balanceador, o banco e os segredos | Resolve os pontos únicos de falha com serviços gerenciados, sem reescrever a aplicação | Exige ajustes pequenos na aplicação e aprendizado da plataforma | **Adotada** |
| Refactor para microserviços | A arquitetura da aplicação | Escala e deploy independentes por domínio | A aplicação é pequena; a complexidade operacional não se paga | Rejeitada nesta fase |

Decisões registradas: [ADR-001](adr/ADR-001-replatforming-over-rehost.md) e [ADR-004](adr/ADR-004-no-microservices-in-phase-one.md).

## Mapeamento origem → alvo

| Origem | Alvo na AWS |
| --- | --- |
| HAProxy único | Application Load Balancer em duas zonas |
| Certificado em arquivo no HAProxy | Certificado gerenciado no load balancer |
| Nginx em cada instância | Removido: o load balancer encaminha direto para o container ([ADR-005](adr/ADR-005-remove-nginx-in-target.md)) |
| VMs com Docker Compose | ECS em Fargate ([ADR-002](adr/ADR-002-ecs-fargate-over-ec2.md)) |
| Imagem construída em cada instância | Amazon ECR |
| PostgreSQL em uma VM | Amazon RDS for PostgreSQL com Multi-AZ ([ADR-003](adr/ADR-003-rds-multi-az.md)) |
| Segredos em `.env` | AWS Secrets Manager |
| Logs locais | Amazon CloudWatch Logs |
| Testes manuais | Métricas, alarmes e dashboard no CloudWatch |
| Sem alertas | Amazon SNS |

## Escopo

**Dentro do escopo:** execução dos containers, entrada e TLS, banco, segredos, logs, métricas, alarmes, auditoria, infraestrutura como código e testes de resiliência.

**Fora do escopo:** reescrita da aplicação, microserviços, deploy automático a partir do CI, IA aplicada à operação, WAF e cópia de backup entre regiões. Esses itens estão no roadmap.

## Fases

| Fase | Entrega | Critério de sucesso |
| --- | --- | --- |
| 0. Saneamento | Repositório anonimizado, documentação do estado atual e ADRs | Nenhum identificador do ambiente de origem no repositório |
| 1. Endurecimento da aplicação | Versão 1.1.0, testes e workflows de validação | Mesmo comportamento nos endpoints de saúde, com os achados corrigidos |
| 2. Fundação | Rede, registro de imagens, auditoria e alerta de orçamento | Plano de infraestrutura revisado; nenhum recurso cobrado por hora |
| 3. Dados | Banco gerenciado com credenciais em cofre e schema carregado | `/ready` responde contra o novo banco |
| 4. Computação e entrada | Serviço com duas tasks, load balancer e TLS | Os testes da origem passam no alvo |
| 5. Observabilidade | Logs, dashboard, alarmes, notificação e runbooks | Cada alarme disparado de propósito ao menos uma vez |
| 6. Resiliência | Queda de task, rollback de deploy, failover do banco e restauração de backup | RTO e RPO medidos e documentados |

Cada fase só começa depois de aprovada, e a origem permanece intacta até o fim da fase 6.

## Rollback

| Fase | Rollback |
| --- | --- |
| 0 e 1 | Reverter os commits. A versão 1.0.0 continua em execução na origem |
| 2 a 5 | Destruir os recursos criados pela fase. A origem não é alterada |
| 6 | O endereço de entrada volta a apontar para a origem |

O laboratório não tem usuários reais. A virada de tráfego é um ensaio da técnica, não uma migração com janela de mudança.

## Critérios de sucesso da migração

- Os testes de smoke, de distribuição e de failover passam no alvo.
- A perda de uma task não interrompe o serviço.
- O failover do banco é executado e medido.
- Um backup é restaurado em uma instância nova.
- Um deploy defeituoso é revertido automaticamente.
- Cada alarme foi disparado e gerou notificação.
- O ambiente inteiro é criado e destruído por código.
