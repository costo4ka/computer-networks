# HH.ru Vacancy Parser


## Структура проекта

```
lab4/
├── main.py             # FastAPI-приложение + парсер
├── Dockerfile          # Образ с Playwright (Chromium уже внутри)
├── docker-compose.yml  # Запуск app + MySQL одной командой
├── requirements.txt    # Ззависимости
└── README.md
```

## Быстрый старт

```bash
docker compose up --build
```

При первом запуске Docker:
1. Скачает образ MySQL 8.0 и образ Playwright/Python.
2. Соберёт образ приложения.
3. Дождётся готовности MySQL.
4. Запустит FastAPI — сервис сам создаст таблицу `vacancies`.

Сервис будет доступен по адресу **http://localhost:8000**.

---

## Использование

### Через браузер

Подставьте реальный ID вакансии:

```
http://localhost:8000/parse?url=https://novosibirsk.hh.ru/vacancy/12345678
```

### Через curl

```bash
curl "http://localhost:8000/parse?url=https://novosibirsk.hh.ru/vacancy/12345678"
```

### Пример ответа

```json
{
  "status": "ok",
  "data": {
    "url": "https://novosibirsk.hh.ru/vacancy/12345678",
    "title": "Python-разработчик",
    "company": "ООО Рога и Копыта",
    "salary": "от 120 000 руб.",
    "experience": "От 1 года до 3 лет"
  }
}
```

При повторном запросе той же ссылки запись в БД **обновляется** (upsert).

---

## Swagger UI

Интерактивная документация (автогенерируется FastAPI):

```
http://localhost:8000/docs
```

---

## База данных

### Подключиться к БД вручную

```bash
docker compose exec db mysql -uparser -pparserpass vacancies_db
```

```sql
SELECT * FROM vacancies ORDER BY parsed_at DESC;
```

---



## Остановка

```bash
# Остановить контейнеры (данные в БД сохраняются)
docker compose down

# Остановить и удалить том с БД
docker compose down -v
```
