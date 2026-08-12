#!/bin/sh
# Автогенерация TLS-сертификатов при старте nginx, если их ещё нет.
# Это позволяет не думать о сертификатах: docker compose up сгенерирует их сам.
# Сертификаты кладутся в смонтированный каталог /etc/nginx/certs и переживают
# перезапуски контейнера.
set -eu

if [ -f /usr/local/bin/generate-certs.sh ]; then
  CERT_DIR=/etc/nginx/certs /usr/local/bin/generate-certs.sh || echo "Ошибка генерации сертификатов" >&2
else
  echo "generate-certs.sh не найден — сертификаты не сгенерированы" >&2
fi
