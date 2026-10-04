# Executor do laboratório (CodeBuild)

> **Estado: implementado e usado em 03 e 04/10/2026.** Descreve como o Terraform, o build da imagem e os testes foram executados dentro da própria conta da AWS.

## Por que um executor

A estação de trabalho usada neste laboratório não tem acesso de rede aos registros do Terraform e de imagens nem aos endpoints da AWS. Em vez de exportar chaves de acesso de longa duração, a execução acontece em um projeto do CodeBuild na conta de destino, com um papel próprio e credenciais temporárias.

## Componentes

| Componente | Função |
| --- | --- |
| Bucket S3 do executor | Código (`src/`), state do Terraform (`state/`) e planos (`plans/`). Privado, criptografado e versionado |
| Papel `aegis-lab-runner` | Assumido apenas pelo CodeBuild. Permissões limitadas aos serviços do laboratório e a papéis com o prefixo do projeto |
| Projeto do CodeBuild | Executa [`buildspec.yml`](buildspec.yml), que chama [`run.sh`](run.sh) com a ação escolhida |

Esses três recursos são criados por chamadas de API, fora do Terraform, e removidos ao fim do laboratório.

## Ações

| `ACTION` | O que faz |
| --- | --- |
| `validate` | `terraform fmt -check`, `init -backend=false` e `validate` |
| `plan` | Gera o plano e o salva no bucket |
| `apply` | Aplica exatamente o plano salvo e revisado |
| `image` | Constrói a imagem, verifica que não roda como root e a envia ao ECR |
| `migrate` | Executa a task de migração e aguarda o código de saída |
| `test` | Roda smoke test, teste de distribuição e, opcionalmente, o teste de failover |
| `plan-destroy` e `destroy` | Gera e aplica o plano de destruição |

O plano é sempre gerado em uma execução e aplicado em outra: o que é aplicado é o que foi revisado.

## Concessão conhecida

O papel do executor precisa criar rede, banco, containers e papéis de IAM; por isso é amplo dentro dos serviços usados. A mitigação é a duração: ele existe apenas durante o laboratório. Em um ambiente permanente, o caminho recomendado é a federação por OIDC a partir do pipeline de CI, com um papel por ambiente.
