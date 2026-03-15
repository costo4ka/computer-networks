#!/bin/bash
set -e

echo "останавливаем контейнеры"
docker stop lab5-app lab5-db 2>/dev/null || true

echo "удаляем контейнеры"
docker rm lab5-app lab5-db 2>/dev/null || true

echo "удаляем сеть"
docker network rm lab5-network 2>/dev/null || true

echo "готово"
