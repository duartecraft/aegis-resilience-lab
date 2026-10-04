#!/usr/bin/env bash
# Verifica a distribuição de requisições entre os nós da aplicação.
#
# Uso:
#   ./scripts/test-ha.sh https://api.aegis.example.com [requisicoes] [minimo_de_nos]
#   INSECURE=1 ./scripts/test-ha.sh https://<endereco-do-load-balancer> 20 2
set -euo pipefail

BASE_URL="${1:?informe a URL base}"
BASE_URL="${BASE_URL%/}"
REQUESTS="${2:-12}"
MIN_NODES="${3:-2}"
CURL_OPTS=(--silent --max-time 10)
[ "${INSECURE:-0}" = "1" ] && CURL_OPTS+=(--insecure)

echo "Alvo: $BASE_URL/api/status | requisições: $REQUESTS | mínimo de nós: $MIN_NODES"
echo "Início (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"

nodes_file="$(mktemp)"
trap 'rm -f "$nodes_file"' EXIT
errors=0
for i in $(seq 1 "$REQUESTS"); do
  body="$(curl "${CURL_OPTS[@]}" "$BASE_URL/api/status" || true)"
  node="$(printf '%s' "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['node'], d['version'], d['database']['connected'])" 2>/dev/null || true)"
  if [ -z "$node" ]; then
    errors=$((errors + 1))
    printf '%3d  ERRO\n' "$i"
  else
    printf '%3d  %s\n' "$i" "$node"
    printf '%s\n' "${node%% *}" >> "$nodes_file"
  fi
done

echo
echo "Respostas por nó:"
sort "$nodes_file" | uniq -c
distinct="$(sort -u "$nodes_file" | wc -l | tr -d ' ')"
echo "Nós distintos: $distinct | erros: $errors"

if [ "$distinct" -lt "$MIN_NODES" ] || [ "$errors" -gt 0 ]; then
  echo "RESULTADO: FALHA"
  exit 1
fi
echo "RESULTADO: OK"
