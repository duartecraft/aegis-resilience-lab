# 02 — Contexto de negócio

> **Estado: proposto.** O contexto de negócio é fictício e serve para derivar requisitos. Não descreve um cliente, um produto ou dados reais, e as funcionalidades de negócio citadas não estão implementadas no código.

## Cenário

A Aegis é uma API B2B que processa e consulta solicitações críticas de parceiros. Indisponibilidade impacta integrações, operações de clientes e compromissos de SLA. A API tem picos previsíveis em janelas operacionais e picos imprevisíveis em campanhas, eventos e processamentos em lote.

O laboratório não implementa esse domínio. A aplicação expõe endpoints de saúde e um registro de eventos de teste, suficientes para exercitar balanceamento, health checks, failover e dependência de banco.

## Partes interessadas

| Parte | Interesse |
| --- | --- |
| Parceiros integrados | API disponível e previsível nas janelas operacionais |
| Operação | Saber de uma falha antes do cliente; ter um procedimento para cada alarme |
| Engenharia | Publicar versões sem indisponibilidade e reverter com segurança |
| Segurança | Segredos fora do código, menor privilégio e trilha de auditoria |
| Gestão | Custo previsível e risco de indisponibilidade reduzido |

## Requisitos funcionais, em alto nível

- Expor verificação de saúde e de prontidão para o balanceador e para a operação.
- Informar nó, versão e estado da dependência de banco.
- Registrar eventos de forma autenticada.

## Requisitos não funcionais

| Requisito | Objetivo proposto |
| --- | --- |
| Disponibilidade | 99,9% em 30 dias, o que permite 43,2 minutos de indisponibilidade no mês |
| Tolerância a falhas | Suportar a perda de uma instância de aplicação e de uma zona de disponibilidade |
| Latência | p95 abaixo de 500 ms |
| Detecção | Falha detectada e notificada em menos de 5 minutos |
| Escala | Absorver picos sem intervenção manual, na versão resiliente |
| Segurança | TLS na borda, segredos gerenciados, menor privilégio, auditoria de mudanças |
| Custo | Compatível com um laboratório de portfólio, com ambiente destruível |

## Objetivos de recuperação propostos

| Objetivo | Valor inicial | Como é atendido na arquitetura alvo |
| --- | --- | --- |
| RTO da aplicação | 1 minuto | Segunda instância em outra zona; substituição automática da que falha |
| RTO do banco | 5 minutos | Standby em outra zona com failover gerenciado |
| RPO do banco, falha de zona | Zero | Replicação síncrona para o standby |
| RPO do banco, corrupção ou erro operacional | 5 minutos | Recuperação point-in-time a partir dos backups automáticos |

São valores de projeto. Só passam a ser afirmados como atendidos depois de medidos nos testes de resiliência.

## Premissas

- O volume de dados e de tráfego do laboratório é pequeno.
- Os registros da tabela de eventos são de teste e não precisam ser migrados.
- Não há dados pessoais, dados de saúde nem transações financeiras.
- O case não alega nenhuma certificação de conformidade.
