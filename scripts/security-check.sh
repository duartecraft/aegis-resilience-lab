#!/usr/bin/env bash
# Verificação local antes de cada commit e antes de qualquer publicação.
#
# Procura por: chaves privadas, chaves de acesso de nuvem, arquivos sensíveis,
# endereços IPv4 fora das faixas reservadas e termos proibidos.
#
# Termos proibidos (nomes reais do ambiente de origem, domínios, hostnames)
# ficam em `.forbidden-terms`, um por linha, na raiz do repositório. Esse
# arquivo é ignorado pelo Git de propósito: os termos não podem aparecer no
# repositório, nem mesmo dentro deste script.
#
# Uso: bash scripts/security-check.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
failures=0
EXCLUDES=(--exclude-dir=.git --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.terraform
          --exclude-dir=__pycache__ --exclude-dir=.pytest_cache --exclude-dir=.ruff_cache
          --exclude=.forbidden-terms)

report() {
  local title="$1" matches="$2"
  if [ -n "$matches" ]; then
    echo "FALHA $title"
    printf '%s\n' "$matches" | sed 's/^/      /'
    failures=$((failures + 1))
  else
    echo "OK    $title"
  fi
}

# 1. Material criptográfico e chaves de acesso. Lista só os arquivos, nunca o conteúdo.
report "sem chaves privadas" \
  "$(grep -RIlE "${EXCLUDES[@]}" -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' . || true)"
report "sem chaves de acesso de nuvem" \
  "$(grep -RIlE "${EXCLUDES[@]}" -e '(AKIA|ASIA)[0-9A-Z]{16}' . || true)"

# 2. Arquivos que nunca devem existir no repositório.
report "sem arquivos sensíveis" \
  "$(find . -path ./.git -prune -o -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' \
      -o -name '*.key' -o -name '*.crt' -o -name '*.p12' -o -name '*.pfx' -o -name '*.tfstate' \
      -o -name '*.tfstate.*' -o -name '*.tfvars' \) ! -name '.env.example' -print \
      | grep -v -e '/.venv/' -e '/venv/' -e '/.terraform/' || true)"

# 3. IPv4 fora das faixas privadas, de loopback e de documentação.
allowed='^(10[.]|127[.]|0[.]0[.]0[.]0|255[.]|169[.]254[.]|192[.]168[.]|172[.](1[6-9]|2[0-9]|3[01])[.]|192[.]0[.]2[.]|198[.]51[.]100[.]|203[.]0[.]113[.])'
ip_matches="$(grep -RIoE "${EXCLUDES[@]}" --exclude='requirements*.txt' \
  -e '\b([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?\b' . \
  | awk -F: -v allowed="$allowed" '{ ip=$NF; if (ip !~ allowed) print $0 }' || true)"
report "sem endereços IPv4 públicos" "$ip_matches"

# 4. Termos proibidos definidos localmente.
if [ -s .forbidden-terms ]; then
  terms_matches="$(grep -RIilF "${EXCLUDES[@]}" -f .forbidden-terms . || true)"
  report "sem termos proibidos (.forbidden-terms)" "$terms_matches"
else
  echo "AVISO .forbidden-terms ausente ou vazio: a busca por nomes do ambiente de origem não foi feita"
fi

echo
if [ "$failures" -eq 0 ]; then echo "Verificação de segurança: sem achados."; else echo "Verificação de segurança: $failures categoria(s) com achados."; fi
exit "$failures"
