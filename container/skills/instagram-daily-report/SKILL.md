---
name: instagram-daily-report
description: Daily report on Instagram account @ashotaiexpert — organic metrics from Zernio + paid ads from Meta filtered by Apify owner_username. Use in `telegram_instagram` department, scheduled cron 09:00 Asia/Tashkent. Generates Markdown report; Mila synthesizes recommendations on top.
---

# Instagram Daily Report

Ежедневный отчёт по аккаунту **@ashotaiexpert**:
- Organic — followers / engagement / top posts / best-time через Zernio API
- Paid Ads — кампании на @ashotaiexpert через Meta Ads API + Apify-фильтр (без него получишь смешанные данные с @farangismaster)
- Synthesis — секцию «что делать сегодня» Mila пишет сама на основе данных

## Trigger

«отчёт по инстаграм», «daily report», «дневной отчёт», «как дела в инстаграм», «instagram daily», cron-таск с этим скиллом.

## Run

```bash
bash /home/node/.claude/skills/instagram-daily-report/run.sh
```

Output — Markdown в stdout. Сама команда выходит с exit 0 даже если данных нет (печатает предупреждение в соответствующей секции). Mila заворачивает вывод в чат-сообщение, добавляет секцию C («Что делать сегодня») с конкретными рекомендациями на основе цифр.

## Env / config requirements

- `$ZERNIO_API_KEY` (env, инжектится контейнером)
- `$APIFY_TOKEN` (env, инжектится контейнером)
- `/workspace/group/config.json` с полями `meta_ads.access_token`, `meta_ads.primary_ad_account`
- Опциональный override через env: `TARGET_USERNAME` (default `ashotaiexpert`), `WD`, `PERMALINK_CACHE`

## Кеш permalink-ов

`/workspace/group/instagram-daily-report/permalink-cache.json` — JSON `{<permalink>: <owner_username>}`. Пополняется автоматом при каждом запуске для новых permalink-ов. Старые не перепрашиваются → Apify-вызовы экономятся.

При смене аккаунта или удалении поста — кеш можно почистить: `rm /workspace/group/instagram-daily-report/permalink-cache.json`.

## Структура отчёта

```
# 📊 Instagram daily report — @ashotaiexpert
_YYYY-MM-DD_

## A. Organic (Zernio)
**Подписчики:** N  
  • за сутки: ±X  
  • за неделю: ±Y  

**Топ-3 поста за неделю (по reach):**
  • <reach> reach / <likes> ❤ / <saves> 🔖 / <comments> 💬 — <caption>
  ...

**Best time to post:** <hour>

---

## B. Paid Ads (Meta — only @ashotaiexpert)
**Кампании (наш аккаунт):** X всего, Y активных
**Расход вчера:** $Z

**Активные ads — yesterday:**
  • [ad_id] <name>
     spend=$X  CTR=Y%  CPC=$Z  clicks=N
  ...

(или если 0 кампаний:)
📭 На @ashotaiexpert платная реклама не запускалась через этот ad account.
💡 Если хочешь стартовать — Таргетолог подготовит план.

---

## C. Что делать сегодня
_Mila синтезирует на основе A+B + контекста_
```

## Когда A или B даёт пусто

- **Organic пусто** → проверь подключение @ashotaiexpert в Zernio (zernio.com → Accounts) и токен (он истекает каждые ~60 дней, см. CLAUDE.md → token renewal warning)
- **Paid пусто** → нормально, если на @ashotaiexpert ещё нет ads через act_20259433. Сообщи Шахрузу + предложи Таргетологу подготовить план

## Scheduled task setup

В `telegram_instagram` через MCP `mcp__nanoclaw__schedule_task`:

```json
{
  "prompt": "Запусти bash /home/node/.claude/skills/instagram-daily-report/run.sh, прочти вывод, добавь секцию C («Что делать сегодня») с 3-5 конкретными рекомендациями на основе цифр (рост/спад followers, лучшие/худшие ads, что закрыть/масштабировать). Финальный отчёт отправь в чат одним сообщением. Если есть критическое решение (паузить кампанию, влить бюджет) — отдельным сообщением от роли «Таргетолог» через swarm.",
  "schedule_type": "cron",
  "schedule_value": "0 9 * * *",
  "context_mode": "group"
}
```

Запусти первый раз вручную через триггер «дневной отчёт» — убедись что цифры адекватные, потом скедули.

## Apify ratecheck

`apify~instagram-post-scraper` — ~1 цент за пост. С кешем — после первого прогона новые permalink-и резолвятся редко. Бюджет на отчёт: ~$0.05-0.10 в день максимум.

## После настройки нового Meta App с @ashotaiexpert IG-Page link

Когда @ashotaiexpert будет привязан к собственной FB Page и токен в config обновлён, **Apify-фильтр станет необязателен** — Meta API сам будет возвращать только ads на @ashotaiexpert.

Тогда секцию B можно упростить (убрать Apify-резолвинг). Шаблон без фильтра уже есть в `meta-ads/status.sh` — можно адаптировать.
