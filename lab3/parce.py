import csv

from playwright.sync_api import Page, sync_playwright

BASE_URL = "https://novosibirsk.hh.ru/search/vacancy"
SEARCH_QUERY = "text=программист&ored_clusters=true"
OUTPUT_FILE = "vacancies_hh.csv"
PAGES_LIMIT = 2

def get_vacancy_links(page: Page) -> list[str]:
    page.goto(f"{BASE_URL}?{SEARCH_QUERY}&page=0")
    page.wait_for_timeout(2000)

    pager_items = page.query_selector_all("[data-qa='pager-page']")
    total_pages = int(pager_items[-1].inner_text().strip()) if pager_items else 1
    print(f"страниц: {total_pages}")

    links: list[str] = []
    for p in range(min(PAGES_LIMIT, total_pages)):
        page.goto(f"{BASE_URL}?{SEARCH_QUERY}&page={p}")
        page.wait_for_timeout(1500)
        cards = page.query_selector_all("[data-qa='serp-item__title']")
        for card in cards:
            href = card.get_attribute("href")
            if href:
                links.append(href.split("?")[0])
        print(f"стр. {p + 1}/{total_pages}: {len(cards)} вакансий")

    return list(dict.fromkeys(links))


def scrape_vacancy(page: Page, url: str) -> dict:
    page.goto(url)
    page.wait_for_timeout(1200)

    def get_text(selector: str) -> str | None:
        el = page.query_selector(selector)
        return el.inner_text().strip() if el else None

    return {
        "ссылка": url,
        "название": get_text("[data-qa='vacancy-title']"),
        "компания": get_text("[data-qa='vacancy-company-name']"),
        "зарплата": get_text("[data-qa='vacancy-salary']"),
        "опыт": get_text("[data-qa='vacancy-experience']"),
    }


def save_to_csv(rows: list[dict], path: str) -> None:
    if not rows:
        print("нет данных для сохранения.")
        return
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"сохранено {len(rows)} строк ")


def main() -> None:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
            )
        )
        page = context.new_page()

        links = get_vacancy_links(page)
        print(f"\nвсего уникальных вакансий: {len(links)}\n")

        rows: list[dict] = []
        for i, url in enumerate(links, 1):
            print(f"[{i:>4}/{len(links)}] ", end="", flush=True)
            try:
                row = scrape_vacancy(page, url)
                rows.append(row)
                print(row.get("название") or url)
            except Exception as exc:
                print(f"ОШИБКА: {exc}")
                rows.append({"ссылка": url})

        browser.close()

    save_to_csv(rows, OUTPUT_FILE)


if __name__ == "__main__":
    main()
