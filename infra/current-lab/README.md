# Infraestrutura do laboratório de origem

> **Estado: implementado e validado em 03/10/2026.** Os arquivos desta pasta reproduzem a configuração que rodou no ambiente de origem, com endereços e domínio substituídos por valores fictícios.

| Arquivo | Onde roda | Função |
| --- | --- | --- |
| `haproxy.cfg.example` | `load-balancer` (10.0.10.10) | Termina TLS na porta 443, distribui em round-robin e remove do pool o nó que falha em `GET /health` |
| `nginx-app.conf.example` | `app-01` (10.0.10.11) e `app-02` (10.0.10.12) | Encaminha a porta 80 para a aplicação em `127.0.0.1:8000` |

## Comportamento do health check

- Checagem a cada 5 s (`inter 5s`).
- O nó sai do pool após 3 falhas consecutivas (`fall 3`): a detecção leva até cerca de 15 s.
- O nó volta após 2 sucessos consecutivos (`rise 2`): cerca de 10 s.

## Limitações conhecidas desta configuração

Estas limitações fazem parte do diagnóstico e não foram corrigidas na origem.

- Há um único load balancer; a queda dele derruba o serviço.
- Não há `option redispatch`: durante a janela de detecção, requisições enviadas ao nó parado podem falhar.
- Não há `option forwardfor`, e o Nginx sobrescreve `X-Forwarded-Proto` com `http`: o IP real do cliente e o protocolo original não chegam à aplicação.
- O redirecionamento de HTTP para HTTPS está configurado, mas não foi confirmado em teste externo (a porta 80 não respondeu).
- A exceção para `/.well-known/acme-challenge/` não tem backend; o mecanismo de renovação do certificado não está documentado.

As recomendações correspondentes estão em [docs/01-current-state.md](../../docs/01-current-state.md).
