# ADR-003 — RDS for PostgreSQL com Multi-AZ para eliminar o SPOF do banco

- **Status:** Aceito
- **Data:** 03/10/2026

## Contexto

O PostgreSQL da origem é uma instância única, sem réplica, sem failover e sem backup comprovado. É o ponto único de falha de maior impacto: a queda dele afeta as duas instâncias de aplicação ao mesmo tempo.

## Decisão

Usar **Amazon RDS for PostgreSQL 16**, na mesma versão principal da origem, com **Multi-AZ** (uma instância standby em outra zona), backup automático com recuperação point-in-time, criptografia em repouso e credenciais no Secrets Manager.

Multi-AZ é controlado por uma variável da infraestrutura como código:

- **Laboratório:** Single-AZ no dia a dia; Multi-AZ é ligado na janela de teste para executar e medir o failover.
- **Versão resiliente:** Multi-AZ permanente.

## Alternativas consideradas

| Alternativa | Por que não |
| --- | --- |
| PostgreSQL em VM com replicação própria | Exige construir e operar replicação, failover e backup |
| Aurora PostgreSQL Serverless v2 | Muda o motor do banco e enfraquece a comparação direta com a origem; fica como evolução se a carga for muito intermitente |
| Read replica | Resolve escala de leitura, não disponibilidade. O failover não é automático |

## Consequências

- O standby de Multi-AZ **não atende leitura**: é um mecanismo de disponibilidade, não de escala. Read replica é uma evolução separada, se a carga de leitura justificar.
- O failover é gerenciado e leva, tipicamente, de 60 a 120 segundos. Nesse intervalo, as rotas com dados falham; o pool de conexões da aplicação se reconecta sozinho.
- Multi-AZ dobra, aproximadamente, o custo da instância e do armazenamento.
- No laboratório em Single-AZ o banco continua sendo ponto único de falha fora da janela de teste. Essa concessão de custo é explícita.
