#!/usr/bin/env bash
# Mede o comportamento do serviço durante a falha de um nó.
#
# Inicie o script e, enquanto ele roda, pare um nó de aplicação (por exemplo,
# `docker compose stop` em app-01, ou a interrupção de uma task). O script
# envia requisições em intervalo fixo e registra, para cada uma, horário,
# código HTTP e nó que respondeu. Ao final, informa a taxa de erro e a maior
# janela contínua de falhas, que é a medida do tempo de detecção.
#
# Uso:
#   ./scripts/test-failover.sh https://api.aegis.example.com [duracao_s] [intervalo_s]
#   INSECURE=1 ./scripts/test-failover.sh https://<endereco-do-load-balancer> 90 0.5
#   ENDPOINT=/ready ./scripts/test-failover.sh https://api.aegis.example.com 300 1   # falha do banco
set -euo pipefail

BASE_URL="${1:?informe a URL base}"
BASE_URL="${BASE_URL%/}"
DURATION="${2:-60}"
INTERVAL="${3:-0.5}"
# /api/status mede a aplicação; /ready responde 503 enquanto o banco está fora.
ENDPOINT="${ENDPOINT:-/api/status}"
CURL_OPTS=(--silent --max-time 5)
[ "${INSECURE:-0}" = "1" ] && CURL_OPTS+=(--insecure)

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

echo "Alvo: $BASE_URL$ENDPOINT | duração: ${DURATION}s | intervalo: ${INTERVAL}s"
echo "Início (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Pare um nó de aplicação agora e religue-o antes do fim para observar o retorno."
echo

end=$(( $(date +%s) + DURATION ))
while [ "$(date +%s)" -lt "$end" ]; do
  ts="$(date -u +%H:%M:%S.%3N)"
  epoch="$(date +%s.%3N)"
  response="$(curl "${CURL_OPTS[@]}" --write-out '\n%{http_code}' "$BASE_URL$ENDPOINT" || printf '\n000')"
  code="${response##*$'\n'}"
  body="${response%$'\n'*}"
  node="$(printf '%s' "$body" | python3 -c "import json,sys; print(json.load(sys.stdin)['node'])" 2>/dev/null || echo '-')"
  printf '%s  %s  %s\n' "$ts" "$code" "$node"
  printf '%s %s %s\n' "$epoch" "$code" "$node" >> "$log_file"
  sleep "$INTERVAL"
done

echo
echo "Fim (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$log_file" <<'PY'
import sys
from collections import Counter

rows = [line.split() for line in open(sys.argv[1]) if line.strip()]
total = len(rows)
failed = [r for r in rows if r[1] != "200"]
nodes = Counter(r[2] for r in rows if r[1] == "200")

longest = 0.0
start = None
last = None
for epoch, code, _ in rows:
    t = float(epoch)
    if code != "200":
        start = t if start is None else start
    elif start is not None:
        # janela = da primeira falha até a primeira resposta bem-sucedida seguinte
        longest = max(longest, t - start)
        start = None
    last = t
if start is not None and last is not None:
    longest = max(longest, last - start)

print("Resumo")
print(f"  requisições:            {total}")
print(f"  falhas:                 {len(failed)} ({(len(failed) / total * 100 if total else 0):.1f}%)")
print(f"  maior janela de falhas: {longest:.1f}s")
print("  respostas por nó:       " + ", ".join(f"{n}={c}" for n, c in sorted(nodes.items())))
PY
