# 01 — Estado atual

> **Estado: implementado e validado em 03/10/2026.** Este documento descreve somente o que existe no laboratório de origem e foi comprovado por arquivo de configuração ou por teste. O que é proposta está nos documentos 04 em diante.

O laboratório comprova alta disponibilidade **na camada de aplicação**: duas instâncias atrás de um load balancer, com saída automática do nó que falha. Banco de dados e load balancer são pontos únicos de falha.

## Inventário

| Camada | Estado real |
| --- | --- |
| Entrada | Um único `load-balancer` com HAProxy 2.8. TLS terminado na porta 443. Round-robin. |
| Health check | `GET /health` a cada 5 s; o nó sai após 3 falhas e volta após 2 sucessos. |
| Aplicação | Duas instâncias idênticas, `app-01` e `app-02`. Nginx na porta 80 encaminha para a aplicação em `127.0.0.1:8000`. |
| Container | API FastAPI servida por Uvicorn, em container Docker gerido por Docker Compose. |
| Endpoints | `/health`, `/ready`, `/api/status`, `POST /api/events` e uma página inicial de demonstração. |
| Banco | Um `postgresql` (PostgreSQL 16) em VM dedicada, compartilhado pelas duas instâncias. Uma tabela, `service_events`. |

Configuração de referência: [infra/current-lab](../infra/current-lab/README.md). Evidências: [docs/evidence/2026-10-03-origem.md](evidence/2026-10-03-origem.md).

## Implementado e validado

| Item | Como foi validado |
| --- | --- |
| HTTPS na borda | Chamadas externas por HTTPS responderam com sucesso |
| Distribuição entre instâncias | Seis chamadas consecutivas alternaram entre `app-01` e `app-02` |
| Liveness (`/health`) | Resposta `ok` com identificação do nó |
| Readiness (`/ready`) | Resposta `ready` com banco `connected` |
| Status (`/api/status`) | Nó, versão, horário e estado do banco |
| Failover da aplicação | Com `app-01` parada, todas as respostas vieram de `app-02` |

## Não implementado

| Área | Situação |
| --- | --- |
| Replicação do PostgreSQL | Não implementada |
| Failover do banco | Não implementado |
| Backup automatizado | Sem evidência de rotina, retenção ou teste de restauração |
| Alta disponibilidade do load balancer | Não implementada; há um único nó |
| Alertas e notificações | Não implementados |
| Métricas e dashboards | Não implementados |
| Centralização de logs | Não implementada |
| Auto scaling | Não implementado |
| CI/CD | Não havia; os workflows deste repositório são de validação e ainda não rodaram em ambiente remoto |
| IA aplicada à operação | Não implementada; é roadmap |
| Microserviços | Não implementados e fora do objetivo da fase inicial |

## Configurado, mas não confirmado

| Item | Situação |
| --- | --- |
| Redirecionamento de HTTP para HTTPS | A regra existe no HAProxy, mas o teste externo na porta 80 expirou |
| Taxa de erro durante a detecção da falha | O teste de failover cobriu o regime estável, depois de o nó sair do pool |
| Retorno do nó ao pool | O serviço foi religado sem registro da alternância restabelecida |
| Renovação do certificado | Mecanismo não documentado |

## Pontos únicos de falha

1. **Banco de dados.** A queda do `postgresql` deixa as duas instâncias sem dependência; `/ready` passa a falhar em ambas.
2. **Load balancer.** A queda do `load-balancer` torna o serviço inacessível, mesmo com as duas instâncias saudáveis.

O health check usa `/health`, que não consulta o banco. Por isso, numa queda do PostgreSQL, os dois nós permanecem no pool respondendo com erro nas rotas que dependem dele. É um comportamento aceitável, desde que conhecido: retirar todos os nós do pool não melhoraria a disponibilidade.

## Achados do assessment na versão 1.0.0

A versão 1.0.0 é a que rodou na origem e gerou as evidências. Os achados abaixo foram corrigidos na versão 1.1.0 deste repositório, que **ainda não foi implantada na origem**.

| Achado na 1.0.0 | Correção na 1.1.0 |
| --- | --- |
| `POST /api/events` gravava no banco sem autenticação | Exige token no cabeçalho `X-API-Key`; sem token configurado, o endpoint fica desabilitado |
| `/api/status` e `/ready` devolviam o texto da exceção do banco | Resposta genérica (`unavailable`); o detalhe fica só no log |
| A criação da tabela rodava na subida: com o banco fora, o container não iniciava | Migração separada (`python -m app.migrate`); a aplicação sobe sem o banco |
| O usuário da aplicação precisava de permissão de DDL | A migração cria um usuário de aplicação apenas com `SELECT` e `INSERT` |
| Uma conexão nova a cada requisição | Pool de conexões com verificação na retirada |
| Container executado como root, sem `.dockerignore` | Usuário não root, sistema de arquivos somente leitura no Compose, `.dockerignore` |
| Dependências sem auditoria | Versões fixadas com hashes e auditadas |
| Sem testes | Testes de unidade e de integração com PostgreSQL 16 |
| Log em texto livre | Log estruturado em JSON com identificador de requisição |

## Riscos em aberto na origem

| Risco | Gravidade | Tratamento |
| --- | --- | --- |
| Banco único | Alta | Arquitetura alvo: banco gerenciado com Multi-AZ ([ADR-003](adr/ADR-003-rds-multi-az.md)) |
| Load balancer único | Alta | Arquitetura alvo: load balancer gerenciado em duas zonas |
| Ausência de alertas e métricas | Alta | Arquitetura alvo: logs, métricas, alarmes e notificação |
| Sem backup comprovado | Alta | Arquitetura alvo: backup automático e teste de restauração |
| Requisições com erro durante a detecção da falha | Média | Medir com `scripts/test-failover.sh`; avaliar `option redispatch` |
| IP do cliente não chega à aplicação | Baixa | `option forwardfor` no HAProxy e preservação de `X-Forwarded-Proto` no Nginx |
