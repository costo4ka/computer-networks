#!/bin/bash
set -e

NETWORK_NAME="lab5-network"
DB_CONTAINER="lab5-db"
APP_CONTAINER="lab5-app"
APP_IMAGE="lab5-app-image"


if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "создаём сеть $NETWORK_NAME"
    docker network create "$NETWORK_NAME"
else
    echo "сеть $NETWORK_NAME уже сущесвует"
fi


if docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "контейнер $DB_CONTAINER уже существует"
    docker start "$DB_CONTAINER" 2>/dev/null || true
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


echo "обираем образ $APP_IMAGE"
docker build -t "$APP_IMAGE" .


if docker ps -a --format '{{.Names}}' | grep -q "^${APP_CONTAINER}$"; then
    echo "удаляем старый  $APP_CONTAINER"
    docker rm -f "$APP_CONTAINER"
fi

echo "запускаем $APP_CONTAINER (порт 8000)"
docker run -d \
    --name "$APP_CONTAINER" \
    --network "$NETWORK_NAME" \
    -e MYSQL_HOST="$DB_CONTAINER" \
    -e MYSQL_PORT=3306 \
    -e MYSQL_USER=parser \
    -e MYSQL_PASSWORD=parserpass \
    -e MYSQL_DATABASE=vacancies_db \
    -p 8000:8000 \
    "$APP_IMAGE"

echo ""
echo "приложение: http://localhost:8000/docs"
echo "MySQL:      localhost:33060"
echo ""
echo "контейнеры:"
docker ps --filter "name=lab5-"
