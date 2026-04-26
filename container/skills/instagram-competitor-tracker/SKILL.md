---
name: instagram-competitor-tracker
description: Daily monitor of watched Instagram competitors via Apify. Reads watchlist of usernames, fetches latest 12 posts each, computes engagement rate, detects viral content (>= 5x median ER for that account). Use to set up competitor monitoring, get daily report, or check viral alerts. Cron-friendly with --alert-only mode.
---

# Instagram Competitor Tracker

Ежедневный мониторинг конкурентов в IG. Скачивает свежие данные через Apify, считает engagement rate, флажит viral-контент.

## Trigger

«проверь конкурентов», «competitor tracker», «есть ли viral у конкурентов», «daily competitor report», cron-таск с этим скиллом, добавление нового конкурента в watchlist.

## Setup (один раз)

### 1. Создай watchlist

```bash
mkdir -p /workspace/group/competitor-tracker
cat > /workspace/group/competitor-tracker/watchlist.txt <<'EOF'
# Instagram competitor watchlist для @ashotaiexpert
# One username per line. # for comments. Max 25 (Apify ratelimit).

# AI/business блогеры RU
# username1
# username2

# AI/business блогеры UZ
# username3

# Эксперты-смежники (workshop founders, course creators)
# username4
EOF
```

Затем в чате попроси Маркетолога / Mila заполнить — обычно 10-20 топ-аккаунтов в нише.

### 2. Прогон вручную (smoke test)

```bash
bash /home/node/.claude/skills/instagram-competitor-tracker/tracker.sh
```

Первый запуск — около 60-180 секунд (Apify собирает данные по всем).

### 3. Schedule daily

В чате через MCP:
```
mcp__nanoclaw__schedule_task({
  prompt: "Запусти bash /home/node/.claude/skills/instagram-competitor-tracker/tracker.sh, прочти отчёт. Если есть viral alerts (секция 🚨) — отправь их в чат отдельным сообщением от sender:'Маркетолог' с рекомендацией изучить и адаптировать. Если viral нет — сохрани отчёт в wiki/projects/instagram/competitors/daily-YYYY-MM-DD.md, в чат не пиши.",
  schedule_type: "cron",
  schedule_value: "0 8 * * *",   # 08:00 daily, перед instagram-daily-report 09:00
  context_mode: "group"
})
```

## Run modes

```bash
# Полный отчёт
bash tracker.sh

# Только viral alerts (для cron-summary режима)
bash tracker.sh --alert-only
```

## Output structure

### Per-competitor snapshots
`/workspace/group/competitor-tracker/data/<username>/<YYYY-MM-DD>.json`
— сырой ответ Apify-скрейпера. Хранится бессрочно для исторического анализа followers growth, post performance trends.

### Daily reports
`/workspace/group/competitor-tracker/reports/<YYYY-MM-DD>.md`
— человекочитаемый отчёт со структурой:
1. **🚨 Viral alerts** — посты с ER >= 5x median (самое ценное; action — изучить hook/формат и адаптировать)
2. **Competitor snapshot** — таблица: followers, Δ за вчера, median ER, лучший пост

## Env / config

| Var | Default | Что |
|---|---|---|
| `APIFY_TOKEN` | from container env | required |
| `WATCHLIST` | `/workspace/group/competitor-tracker/watchlist.txt` | путь к watchlist |
| `DATA_DIR` | `/workspace/group/competitor-tracker/data` | snapshots |
| `REPORT_DIR` | `/workspace/group/competitor-tracker/reports` | reports |
| `VIRAL_THRESHOLD` | `5` | multiplier vs median ER чтобы пост считался viral |

## Cost (Apify)

`apify~instagram-profile-scraper`: ~$0.01 за профиль за вызов. **20 конкурентов × 30 дней = ~$6/мес.** Бюджет на месяц с запасом.

## Viral detection — методология

Engagement rate (ER) = `(likes + comments) / followers * 100`

Для каждого аккаунта берём последние 12 постов, считаем median ER. Пост считается **viral** если его ER >= `VIRAL_THRESHOLD` × median (default 5x).

Почему median а не avg: median устойчив к выбросам (один viral пост в истории не тянет среднее вверх и не даёт false negative на следующий viral). Почему 12 постов: достаточно для устойчивого median, не слишком много старых данных.

Threshold 5x — конкретная виральность (по бенчмарку IG-индустрии): обычные посты дают ER 1-3% в нашей нише, viral 8-15%. Аккаунту с типичным 2% — viral на 10%, что = 5x median. Если хочешь больше алертов (низкоплавающая планка) — поставь `VIRAL_THRESHOLD=3`. Если меньше шума — `7`.

## Watchlist management

### Добавить конкурента
```bash
echo "newusername" >> /workspace/group/competitor-tracker/watchlist.txt
```

Или через Mila/Маркетолога: «добавь @newuser в competitor watchlist».

### Удалить конкурента
```bash
sed -i '' '/^newusername$/d' /workspace/group/competitor-tracker/watchlist.txt
```

### Категоризация (опционально)

Можно добавить категории как комментарии:
```
# === AI/business RU тех-блогеры ===
ai_blogger_one
ai_blogger_two

# === Маркетологи AI ===
marketing_ai_pro
```

Это нужно только для самого Mila чтобы помнить кто кто. Скрипт всё равно мониторит всех.

## Workflow для Mila/Маркетолога

```
1. Раз в неделю — review watchlist:
   - Добавить новых интересных (через анализ нашего bio-engaged audience)
   - Убрать тех кто перестал постить / сменил нишу
2. Каждый день — daily report (auto через cron):
   - Если viral alert — написать в чат через swarm от Маркетолога
   - Раз в неделю — пятничный summary: кто из competitors растёт, кто падает
3. На основе viral alerts:
   - Какие hook/формат сработали (учиться у конкурентов)
   - Адаптировать в свой план без копирования
   - Внести в `wiki/projects/instagram/ideas-pool.md` как seed для контента
```

## Limits

- Apify имеет rate limit — не выставляй >25 в watchlist
- Профили с >100K followers иногда дают неточные posts data (Apify не всегда видит свежие). Не критично — мы трекаем тренд, не точные цифры
- Reels-views (количество просмотров видео) не всегда доступны через profile-scraper. Если нужны — можно добавить вторую passe через `apify~instagram-reel-scraper` для конкретного username

## Когда apify-данные кажутся несвежими

Apify cache до 6 часов. Если делать прогон утром — данные за вчера. Это норм для daily monitoring. Для real-time проверки конкретного аккаунта — `instagram-analyzer` skill (более глубокий + свежий).
