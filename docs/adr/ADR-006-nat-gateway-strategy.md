# ADR-006 — Estratégia de saída para a internet (NAT Gateway)

- **Status:** Aceito
- **Data:** 03/10/2026

## Contexto

As tasks ficam em subnets privadas, sem IP público. Elas precisam alcançar o registro de imagens, o serviço de logs e o cofre de segredos. O NAT Gateway é cobrado por hora e é o item de maior peso no custo do laboratório.

## Decisão

A quantidade de NAT Gateways é uma variável da infraestrutura como código:

- **Laboratório:** um NAT Gateway, em uma zona.
- **Versão resiliente:** um NAT Gateway por zona.

## Alternativas consideradas

| Alternativa | A favor | Por que não é o padrão |
| --- | --- | --- |
| Tasks em subnets públicas, sem NAT | Menor custo | As tasks ganham IP público; a proteção passa a depender só do security group |
| VPC endpoints no lugar do NAT | O tráfego para os serviços do provedor não sai para a internet | Com quatro endpoints em duas zonas, custa mais que um NAT no laboratório |

## Consequências

- No laboratório, a saída para a internet depende de uma zona. Se ela falhar, tasks da outra zona continuam atendendo, mas novas tasks podem não conseguir baixar a imagem. A concessão é explícita e não existe na versão resiliente.
- O tráfego de entrada não passa pelo NAT: a disponibilidade percebida pelo cliente depende do load balancer, que está em duas zonas.
- VPC endpoints permanecem como evolução para ambientes que proíbem saída para a internet.
