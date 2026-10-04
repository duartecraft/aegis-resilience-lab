#!/usr/bin/env bash
# Smoke test dos endpoints públicos.
#
# Uso:
#   ./scripts/smoke-test.sh https://api.aegis.example.com
#   INSECURE=1 ./scripts/smoke-test.sh https://<endereco-do-load-balancer>   # certificado autoassinado
#
# Sai com código diferente de zero se alguma verificação falhar.
set -euo pipefail

BASE_URL="${1:?informe a URL base, por exemplo https://api.aegis.example.com}"
BASE_URL="${BASE_URL%/}"
CURL_OPTS=(--silent --show-error --max-time 10)
[ "${INSECURE:-0}" = "1" ] && CURL_OPTS+=(--insecure)

failures=0
check() {
  local description="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "OK    $description ($actual)"
  else
    echo "FALHA $description: esperado '$expected', obtido '$actual'"
    failures=$((failures + 1))
  fi
}
http_code() { curl "${CURL_OPTS[@]}" --output /dev/null --write-out '%{http_code}' "$@" || echo 000; }
json_field() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)" 2>/dev/null || echo "?"; }

echo "Alvo: $BASE_URL"
check "GET /health retorna 200" 200 "$(http_code "$BASE_URL/health")"
check "GET /health status ok" ok "$(curl "${CURL_OPTS[@]}" "$BASE_URL/health" | json_field "d['status']")"
check "GET /ready retorna 200" 200 "$(http_code "$BASE_URL/ready")"
check "GET /ready banco conectado" connected "$(curl "${CURL_OPTS[@]}" "$BASE_URL/ready" | json_field "d['database']")"
check "GET /api/status retorna 200" 200 "$(http_code "$BASE_URL/api/status")"
check "GET /api/status banco conectado" True "$(curl "${CURL_OPTS[@]}" "$BASE_URL/api/status" | json_field "d['database']['connected']")"
check "GET / retorna 200" 200 "$(http_code "$BASE_URL/")"
check "POST /api/events sem token é recusado" 401 "$(http_code --request POST "$BASE_URL/api/events")"

if [[ "$BASE_URL" == https://* ]]; then
  http_url="http://${BASE_URL#https://}"
  redirect_code="$(http_code "$http_url/health")"
  redirect_target="$(curl "${CURL_OPTS[@]}" --output /dev/null --write-out '%{redirect_url}' "$http_url/health" || true)"
  check "HTTP redireciona para HTTPS (301)" 301 "$redirect_code"
  case "$redirect_target" in
    https://*) echo "OK    destino do redirecionamento usa https" ;;
    *) echo "FALHA destino do redirecionamento: '$redirect_target'"; failures=$((failures + 1)) ;;
  esac
fi

echo
if [ "$failures" -eq 0 ]; then echo "Smoke test: todas as verificações passaram."; else echo "Smoke test: $failures falha(s)."; fi
exit "$failures"
