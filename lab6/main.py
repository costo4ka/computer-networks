import asyncio
import os
from contextlib import asynccontextmanager

import aiomysql
from fastapi import FastAPI, HTTPException, Query
from playwright.async_api import async_playwright


DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", 3306)),
    "user": os.getenv("MYSQL_USER", "parser"),
    "password": os.getenv("MYSQL_PASSWORD", "parserpass"),
    "db": os.getenv("MYSQL_DATABASE", "vacancies_db"),
}

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS vacancies (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    url         VARCHAR(500)  NOT NULL,
    title       VARCHAR(500),
    company     VARCHAR(300),
    salary      VARCHAR(200),
    experience  VARCHAR(200),
    parsed_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_url (url(191))
)
"""

UPSERT_SQL = """
INSERT INTO vacancies (url, title, company, salary, experience)
VALUES (%s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
    title      = VALUES(title),
    company    = VALUES(company),
    salary     = VALUES(salary),
    experience = VALUES(experience),
    parsed_at  = NOW()
"""


async def init_db(retries: int = 15, delay: float = 3.0) -> None:
    for attempt in range(1, retries + 1):
        try:
            conn = await aiomysql.connect(**DB_CONFIG)
            async with conn.cursor() as cur:
                await cur.execute(CREATE_TABLE_SQL)
            await conn.commit()
            conn.close()
            print(" бд инициализирована")
            return
        except Exception as exc:
            print(f" бд недоступна")
            if attempt < retries:
                await asyncio.sleep(delay)
    raise RuntimeError("не удалось подключиться к MySQL")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="HH.ru Vacancy Parser",
    description="парсит одну вакансию с hh.ru и сохраняет результат в MySQL",
    version="1.0.0",
    lifespan=lifespan,
)


async def scrape_vacancy(url: str) -> dict:
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
            ],
        )
        context = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            )
        )
        page = await context.new_page()
        try:
            await page.goto(url, wait_until="domcontentloaded", timeout=30_000)
            await page.wait_for_timeout(1500)

            async def get_text(selector: str) -> str | None:
                el = await page.query_selector(selector)
                if el is None:
                    return None
                text = (await el.inner_text()).strip()
                return text or None

            return {
                "url": url,
                "title":      await get_text("[data-qa='vacancy-title']"),
                "company":    await get_text("[data-qa='vacancy-company-name']"),
                "salary":     await get_text("[data-qa='vacancy-salary']"),
                "experience": await get_text("[data-qa='vacancy-experience']"),
            }
        finally:
            await browser.close()


@app.get(
    "/parse",
    summary="спарсить вакансию",
    response_description="данные вакансии, сохранённые в бд",
)
async def parse_vacancy(
    url: str = Query(..., description="прямая ссылка на вакансию hh.ru"),
):
    try:
        data = await scrape_vacancy(url)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"ошибка парсинга: {exc}")

    try:
        conn = await aiomysql.connect(**DB_CONFIG)
        async with conn.cursor() as cur:
            await cur.execute(
                UPSERT_SQL,
                (data["url"], data["title"], data["company"], data["salary"], data["experience"]),
            )
        await conn.commit()
        conn.close()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"ошибка записи в бд: {exc}")

    return {"status": "ok", "data": data}
