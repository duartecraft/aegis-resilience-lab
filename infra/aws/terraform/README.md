# Infraestrutura alvo na AWS (Terraform)

> **Estado: aplicado e validado em 03 e 04/10/2026.** Este código criou 84 recursos em um laboratório efêmero; o registro está em [docs/evidence/2026-10-03-aws.md](../../../docs/evidence/2026-10-03-aws.md). O perfil `prod` nunca foi aplicado.

## Estrutura

| Módulo | Recursos |
| --- | --- |
| `network` | VPC, subnets públicas, privadas e isoladas em duas zonas, rotas, NAT Gateway opcional, endpoint de gateway do S3, security groups |
| `ecr` | Repositório de imagens com tags imutáveis, scan no push e política de retenção |
| `iam` | Papel de execução da aplicação, papel de execução da migração e papel da task, sem políticas |
| `rds` | RDS for PostgreSQL 16, criptografado, com senha mestre gerida pelo RDS e Multi-AZ opcional |
| `alb` | Application Load Balancer, redirecionamento de 80 para 443, target group com health check em `/health` |
| `ecs` | Cluster, log group, task definitions da aplicação e da migração, serviço Fargate com circuit breaker |
| `notifications` | Tópico SNS, assinatura por e-mail e orçamento mensal |
| `observability` | Alarmes, dashboard, eventos do banco e de deploy, trilha do CloudTrail |

## Interruptores de custo

Tudo o que é cobrado por hora nasce **desligado**. Um `terraform apply` sem variáveis cria apenas rede, repositório de imagens, papéis, cluster vazio, log group, segredo e tópico SNS.

| Variável | Padrão | O que liga | Custo |
| --- | --- | --- | --- |
| `nat_gateway_mode` | `none` | `single`: um NAT Gateway; `per_az`: um por zona | Por hora e por GB |
| `enable_database` | `false` | Instância RDS | Por hora, mais armazenamento |
| `enable_load_balancer` | `false` | Application Load Balancer e dois IPv4 públicos | Por hora |
| `enable_service` | `false` | Tasks Fargate | Por hora |
| `db_multi_az` | `false` | Standby do banco em outra zona | Dobra o custo do banco |
| `enable_alarms` | `false` | Alarmes e dashboard | Centavos acima da faixa gratuita |
| `enable_cloudtrail` | `false` | Trilha e bucket | Armazenamento |
| `enable_budget` | `false` | Orçamento com alertas por e-mail | Sem custo |

Com `nat_gateway_mode = "none"`, as tasks ficam em subnets públicas com IP público; o security group continua aceitando tráfego apenas do load balancer. Ver [ADR-006](../../../docs/adr/ADR-006-nat-gateway-strategy.md).

Outros recursos com custo fixo pequeno: um segredo no Secrets Manager, armazenamento de imagens no ECR e de logs no CloudWatch.

## Segredos

- A senha mestre do banco é gerada e rotacionada pelo RDS no Secrets Manager.
- O usuário de banco da aplicação e o token de `POST /api/events` são gerados como recursos efêmeros e gravados com atributo write-only.
- Nenhum desses valores aparece em variável, plano ou state.
- Exceção: sem `certificate_arn`, o módulo `alb` gera um certificado autoassinado cuja chave privada fica no state. É uma concessão de laboratório; com domínio próprio, use um certificado público do ACM.

Os arquivos `terraform.tfvars` são ignorados pelo Git e não devem conter segredos.

## Ordem de aplicação

1. **Fundação:** `apply` com os interruptores desligados. Cria rede e repositório de imagens.
2. **Imagem:** build e envio da imagem ao ECR, com a tag de `image_tag`.
3. **Banco:** `enable_database = true`.
4. **Migração:** execução única da task `*-migrate`, que cria a tabela e o usuário de aplicação sem DDL.
5. **Entrada e serviço:** `nat_gateway_mode`, `enable_load_balancer` e `enable_service`.
6. **Observabilidade:** `enable_alarms`, `enable_cloudtrail` e `enable_budget`.

## Validação local

```bash
cd infra/aws/terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
tflint --recursive   # se instalado
```

## Aplicação

O backend é S3 com lock nativo; bucket, chave e região são informados no `init`:

```bash
terraform init \
  -backend-config="bucket=<bucket-de-state>" \
  -backend-config="key=state/dev/terraform.tfstate" \
  -backend-config="region=us-east-1"

cp environments/dev/terraform.tfvars.example terraform.tfvars   # ajuste os valores
terraform plan -out=lab.tfplan
terraform apply lab.tfplan   # somente depois de revisar o plano
```

No laboratório, esses comandos são executados pelo [executor no CodeBuild](../runner/README.md).

## Destruição e checklist de limpeza

```bash
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Depois do `destroy`, confirme no console ou pela API que não restou:

- [ ] NAT Gateway e Elastic IP
- [ ] Load balancer e target group
- [ ] Instância RDS, snapshots manuais e backups automáticos retidos
- [ ] Serviço, tasks e cluster ECS
- [ ] Imagens no ECR
- [ ] Segredos no Secrets Manager (inclusive o segredo mestre criado pelo RDS)
- [ ] Log groups do CloudWatch (`/ecs/...` e `/aws/rds/...`)
- [ ] Buckets do S3 (trilha, state e código do executor)
- [ ] Certificado importado no ACM
- [ ] Projeto do CodeBuild e papel do executor
- [ ] Alarmes, dashboard, tópico SNS e orçamento

O log group `/aws/rds/instance/<nome>/postgresql` é criado pelo RDS, fora do Terraform, e precisa ser removido à parte.

## Requisitos

- Terraform 1.11 ou superior (recursos efêmeros e atributos write-only).
- Provedor AWS 6.x; as versões exatas ficam registradas em `.terraform.lock.hcl` depois do primeiro `init`.
