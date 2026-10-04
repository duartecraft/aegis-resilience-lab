# Glossário

Termos usados no Aegis Resilience Lab, agrupados pelo papel que têm no projeto. "Origem" é o laboratório em IaaS; "AWS" é a arquitetura alvo.

## Disponibilidade

| Termo | O que é | Onde aparece |
| --- | --- | --- |
| Alta disponibilidade (HA) | Capacidade de continuar atendendo quando uma parte falha | Origem: só na aplicação. AWS: aplicação, entrada e banco |
| SPOF | Ponto único de falha: componente cuja queda derruba o serviço | Origem: load balancer e banco |
| Failover | Troca automática para um componente reserva | Origem: aplicação. AWS: aplicação e banco |
| Health check | Verificação periódica que decide se um nó recebe tráfego | HAProxy e ALB, em `/health` |
| Liveness e readiness | O processo está vivo; o processo consegue atender, incluindo dependências | `/health` e `/ready` |
| Zona de disponibilidade | Datacenter isolado dentro de uma região | AWS: duas zonas |
| Multi-AZ | Recurso distribuído em mais de uma zona | ALB, tasks e RDS |
| SLO, RTO e RPO | Meta de disponibilidade; tempo para voltar; perda de dados aceitável | Metas em `02-business-context.md` |
| Rolling deploy | Troca das réplicas aos poucos | ECS |
| Circuit breaker de deploy | Interrompe e reverte um deploy que não fica saudável | ECS |

## Entrada e rede

| Termo | O que é | Onde aparece |
| --- | --- | --- |
| Load balancer | Distribui requisições entre réplicas | HAProxy na origem, ALB na AWS |
| Round-robin | Alterna as requisições entre as réplicas | Origem e AWS |
| Reverse proxy | Recebe a requisição e a repassa a outro servidor | Nginx na origem |
| Listener e target group | Porta em que o load balancer escuta; lista de destinos com health check | AWS |
| TLS, HTTPS e HSTS | Criptografia da conexão; cabeçalho que exige HTTPS | Origem e AWS |
| ACM | Serviço que guarda e renova certificados | AWS |
| Certificado autoassinado | Criptografa, mas não prova a identidade do servidor | Laboratório na AWS |
| VPC e subnet | Rede privada virtual e suas faixas: pública, privada e isolada | AWS |
| Security group | Firewall por recurso, que pode referenciar outro grupo | AWS: três, em cadeia |
| NAT Gateway | Saída para a internet sem aceitar entrada | AWS |
| VPC endpoint | Acesso privado a um serviço do provedor | AWS: S3 |

## Aplicação e containers

| Termo | O que é | Onde aparece |
| --- | --- | --- |
| Container e imagem | Pacote isolado da aplicação e o modelo imutável que o origina | Origem e AWS |
| Digest | Impressão digital do conteúdo de uma imagem | AWS |
| Docker Compose | Sobe containers a partir de um arquivo, em uma máquina | Origem e desenvolvimento local |
| FastAPI e Uvicorn | Framework web em Python e o servidor que o executa | Origem e AWS |
| Monólito | Aplicação entregue como uma unidade | Mantido nos dois ambientes |
| ECS e Fargate | Orquestrador de containers e o modo em que o provedor fornece a máquina | AWS |
| Task, task definition e service | Execução do container, sua receita e o controlador que mantém as réplicas | AWS |
| ECR | Registro privado de imagens | AWS |
| Pool de conexões | Conexões com o banco reaproveitadas entre requisições | Versão 1.1.0 |
| Migração de schema | Alteração controlada da estrutura do banco | Task `migrate` |

## Dados e segredos

| Termo | O que é | Onde aparece |
| --- | --- | --- |
| RDS | Banco gerenciado: backup, patch e failover por conta do provedor | AWS |
| Standby | Cópia sincronizada do banco em outra zona | RDS Multi-AZ |
| Read replica | Cópia para leitura; escala, não failover automático | Roadmap |
| Point-in-time recovery | Restauração do banco para um instante escolhido | Testada na AWS |
| Secrets Manager | Cofre de segredos, com rotação | AWS |
| IAM e papel | Controle de acesso; identidade assumida por um serviço | AWS |
| Menor privilégio | Cada identidade só pode o mínimo necessário | Papéis e usuário do banco |

## Operação

| Termo | O que é | Onde aparece |
| --- | --- | --- |
| Observabilidade | Entender o sistema por logs, métricas e eventos | Ausente na origem |
| CloudWatch | Logs, métricas, alarmes e dashboards | AWS |
| SNS | Serviço de notificação | AWS: e-mail de alertas |
| CloudTrail | Registro das chamadas de API da conta | AWS |
| Runbook | Procedimento escrito para responder a um alarme | A escrever |
| Infraestrutura como código | Infraestrutura descrita em arquivos versionados | Terraform |
| Plan, apply e state | Mostrar o que vai mudar; aplicar; registro do que existe | Terraform |
| CodeBuild | Serviço de build; aqui executa o Terraform e os testes | Executor do laboratório |

## Estratégias de migração

| Termo | O que é | Onde aparece |
| --- | --- | --- |
| IaaS | O provedor entrega máquinas e rede | Origem |
| Serviço gerenciado | O provedor opera o componente | ALB, Fargate, RDS |
| Rehost | Mover como está | Rejeitado |
| Replatform | Manter a aplicação e trocar a plataforma | Adotado |
| Refactor | Reescrever a arquitetura da aplicação | Rejeitado nesta fase |
| ADR | Registro de uma decisão de arquitetura e seus motivos | `docs/adr/` |
