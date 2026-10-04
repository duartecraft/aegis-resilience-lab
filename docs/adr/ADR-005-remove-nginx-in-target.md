# ADR-005 — Remover o Nginx na arquitetura alvo

- **Status:** Aceito
- **Data:** 03/10/2026

## Contexto

Na origem, cada instância tem um Nginx que recebe o tráfego do load balancer na porta 80 e o repassa para a aplicação em `127.0.0.1:8000`. Ele não serve conteúdo estático, não faz cache e não termina TLS.

## Decisão

Na arquitetura alvo, o load balancer gerenciado encaminha o tráfego **diretamente para a porta 8000 do container**. O Nginx não é migrado.

## Alternativas consideradas

| Alternativa | Por que não |
| --- | --- |
| Nginx como segundo container na mesma task | Mais um componente para configurar, atualizar e monitorar, sem função que o load balancer não cubra |

## Consequências

- Um componente a menos por task.
- O tráfego entre load balancer e container segue em HTTP dentro da rede privada. É uma concessão do laboratório; criptografia nesse trecho fica como evolução.
- Limites de tempo e de tamanho de requisição passam a ser os do load balancer e do Uvicorn.
- O IP do cliente chega pelo cabeçalho `X-Forwarded-For` do load balancer.
