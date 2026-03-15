#!/bin/bash
set -e

NETWORK_NAME="lab6-network"
DB_CONTAINER="lab6-db"
APP_CONTAINER="lab6-app"
APP_IMAGE="lab6-app-image"
PROXY_CONTAINER="lab6-proxy"


if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "создаём сеть $NETWORK_NAME"
    docker network create "$NETWORK_NAME"
else
    echo "сеть $NETWORK_NAME уже существует"
fi


if docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "контейнер $DB_CONTAINER уже существует"
    docker start "$DB_CONTAINER" 2>/dev/null || true
    docker network connect "$NETWORK_NAME" "$DB_CONTAINER" 2>/dev/null || true
else
    echo "запускаем контейнер $DB_CONTAINER"
    docker run -d \
        --name "$DB_CONTAINER" \
        --network "$NETWORK_NAME" \
        -e MYSQL_ROOT_PASSWORD=rootpassword \
        -e MYSQL_DATABASE=vacancies_db \
        -e MYSQL_USER=parser \
        -e MYSQL_PASSWORD=parserpass \
        -p 33060:3306 \
        mysql:8.0 \
        --default-authentication-plugin=mysql_native_password
fi


echo "ждем MySQL"
for i in $(seq 1 30); do
    if docker exec "$DB_CONTAINER" mysqladmin ping -h localhost -uparser -pparserpass >/dev/null 2>&1; then
        echo "MySQL готов"
        break
    fi
    echo "попытка $i/30..."
    sleep 3
done


echo "собираем образ $APP_IMAGE"
docker build -t "$APP_IMAGE" .


if docker ps -a --format '{{.Names}}' | grep -q "^${APP_CONTAINER}$"; then
    echo "удаляем старый $APP_CONTAINER"
    docker rm -f "$APP_CONTAINER"
fi

echo "запускаем $APP_CONTAINER"
docker run -d \
    --name "$APP_CONTAINER" \
    --network "$NETWORK_NAME" \
    -e MYSQL_HOST="$DB_CONTAINER" \
    -e MYSQL_PORT=3306 \
    -e MYSQL_USER=parser \
    -e MYSQL_PASSWORD=parserpass \
    -e MYSQL_DATABASE=vacancies_db \
    "$APP_IMAGE"

echo "ждем приложение"
for i in $(seq 1 20); do
    if docker exec "$APP_CONTAINER" python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/docs')" >/dev/null 2>&1; then
        echo "приложение готово"
        break
    fi
    echo "попытка $i/20..."
    sleep 3
done

if docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}$"; then
    echo "удаляем старый $PROXY_CONTAINER"
    docker rm -f "$PROXY_CONTAINER"
fi

echo "запускаем $PROXY_CONTAINER (порт 80 -> приложение:8000)"
docker run -d \
    --name "$PROXY_CONTAINER" \
    --network "$NETWORK_NAME" \
    -p 80:80 \
    -v "$(pwd)/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
    nginx:alpine

echo ""
echo "приложение: http://localhost/docs"
echo "MySQL:      localhost:33060"
echo ""
echo "контейнеры:"
docker ps --filter "name=lab6-"
