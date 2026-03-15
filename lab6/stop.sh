#!/bin/bash
set -e

echo "останавливаем контейнеры"
docker stop lab6-proxy lab6-app lab6-db 2>/dev/null || true

echo "удаляем контейнеры"
docker rm lab6-proxy lab6-app lab6-db 2>/dev/null || true

echo "удаляем сеть"
docker network rm lab6-network 2>/dev/null || true

echo "готово"
