#!/bin/sh
# Генерирует самоподписанный TLS-сертификат (openssl, без внешних зависимостей)
# для nginx. SAN покрывает домен (по умолчанию resource-planning.mvs), localhost,
# loopback и все локальные IP хоста — чтобы сайт открывался по HTTPS в локальной
# сети без домена в DNS.
#
# Идемпотентен: если сертификаты уже есть — ничего не делает.
# Регенерация: ./scripts/generate-certs.sh --force
# Окружение: CERT_DIR (по умолчанию nginx/certs), DOMAIN (по умолчанию
# resource-planning.mvs), CERTS_DAYS (по умолчанию 3650)
set -eu

FORCE=0
case "${1:-}" in
  --force|-f) FORCE=1 ;;
esac

CERT_DIR="${CERT_DIR:-$(cd "$(dirname "$0")/.." && pwd)/nginx/certs}"
DOMAIN="${DOMAIN:-resource-planning.mvs}"
CRT="${CERT_DIR}/server.crt"
KEY="${CERT_DIR}/server.key"
DAYS="${CERTS_DAYS:-3650}"

if [ -f "$CRT" ] && [ -f "$KEY" ] && [ "$FORCE" -ne 1 ]; then
  echo "Сертификаты уже есть: $CRT (для перегенерации: --force)" >&2
  exit 0
fi

command -v openssl >/dev/null 2>&1 || {
  echo "openssl не найден — установите его" >&2
  exit 1
}

mkdir -p "$CERT_DIR"

# SAN: домен + localhost + loopback + все адреса интерфейсов хоста
SANS="DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1,IP:::1"
for ip in $(hostname -I 2>/dev/null || true); do
  case "$ip" in
    *:*) SANS="${SANS},IP:${ip}" ;;
    *) SANS="${SANS},IP:${ip}" ;;
  esac
done

openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -keyout "$KEY" -out "$CRT" \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=${SANS}" \
  -addext "extendedKeyUsage=serverAuth" \
  >/dev/null 2>&1

chmod 600 "$KEY"

echo "Сгенерирован самоподписанный сертификат:"
echo "  $CRT"
echo "  $KEY"
echo "CN:  ${DOMAIN}"
echo "SAN: ${SANS}"
echo
echo "Браузер предупредит о самоподписанном сертификате — нажмите «Продолжить»"
echo "при первом открытии. Либо добавьте $CRT в доверенные корневые."
