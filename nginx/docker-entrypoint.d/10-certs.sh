#!/bin/sh
# Auto-generates TLS certificates at nginx startup if they do not exist yet.
# This removes certificate worries: `docker compose up` generates them itself.
# Certificates go to the mounted /etc/nginx/certs directory and survive
# container restarts.
set -eu

if [ -f /usr/local/bin/generate-certs.sh ]; then
  CERT_DIR=/etc/nginx/certs /usr/local/bin/generate-certs.sh || echo "Ошибка генерации сертификатов" >&2
else
  echo "generate-certs.sh не найден — сертификаты не сгенерированы" >&2
fi
