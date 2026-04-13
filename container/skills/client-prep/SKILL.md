---
name: client-prep
description: Pre-meeting preparation — assembles all client intelligence into a sales briefing with talking points, objection handlers, and optionally creates a demo funnel via OctoFunnel. Use before a client meeting to have full context, strategy, and a ready demo.
---

# Client Prep — Pre-Meeting Sales Briefing

Prepare for a client meeting by assembling all collected intelligence into an actionable briefing. Gives you "козыри" — context, analysis, strategy, and optionally a ready demo funnel.

## Trigger

When user asks to:
- "подготовь меня к встрече с @username"
- "клиент-преп", "client prep"
- "козыри на @username"
- "briefing for meeting with..."

## Workflow

### Phase 1: Check Available Data

```bash
NAME="<client-name-or-username>"
echo "=== Client Profile ===" && ls /workspace/group/wiki/entities/client-$NAME.md 2>/dev/null && echo "FOUND" || echo "MISSING"
echo "=== Instagram ===" && ls /workspace/group/wiki/entities/$NAME.md 2>/dev/null && echo "FOUND" || echo "MISSING"
echo "=== Audit ===" && ls /workspace/group/wiki/entities/$NAME-audit.md 2>/dev/null && echo "FOUND" || echo "MISSING"
echo "=== Funnel Strategy ===" && ls /workspace/group/wiki/entities/$NAME-funnel-strategy.md 2>/dev/null && echo "FOUND" || echo "MISSING"
echo "=== Profile JSON ===" && ls /workspace/group/client-profiles/$NAME/profile.json 2>/dev/null && echo "FOUND" || echo "MISSING"
```

**If client profile is missing:** "Профиль клиента не найден. Сначала создать? (нужны данные Instagram/Website/YouTube)"

**If some analyses exist but not all:** proceed with what's available, note gaps.

### Phase 1.5: Web Presence Discovery + Search Analysis

**1. Ask user for additional links:**
Send message: "Есть ли ссылки на другие соцсети клиента? (YouTube, Facebook, TikTok, LinkedIn, VK, Telegram канал). Если нет — я поищу сам(а)."
If user provides links → note them for analysis. Don't wait long — proceed with search.

**2. Search client in Google and Yandex:**

Use `mcp__parallel-search__*` if available, otherwise `agent-browser`:

```bash
# Google searches (via Parallel Search or agent-browser)
# Search queries to run:
# 1. "<client name> <niche> <city>"
# 2. "<client name> instagram"  
# 3. "<website domain>"
# 4. "<client name> отзывы"
```

For Yandex (agent-browser):
```bash
agent-browser open "https://yandex.ru/search/?text=<client+name>+<niche>+<city>"
agent-browser wait --timeout 5000
agent-browser screenshot $WD/screenshots/yandex-search.png
agent-browser get text > $WD/yandex-results.txt
```

For Google (agent-browser):
```bash
agent-browser open "https://google.com/search?q=<client+name>+<niche>+<city>"
agent-browser wait --timeout 5000
agent-browser screenshot $WD/screenshots/google-search.png
agent-browser get text > $WD/google-results.txt
```

**3. Analyze search results:**
- What appears on page 1? (site, socials, reviews, directories, competitors)
- Google Knowledge Panel present?
- Yandex business card present?
- Negative results? (complaints, bad reviews)
- Client's site position for key queries
- Competitors appearing for same queries

**4. Build platform presence map:**
From search results + bio links + website links → discover all platforms:

```
| Platform | URL | Status | Notes |
|----------|-----|--------|-------|
| Instagram | @username | Analyzed | 1,344 followers |
| YouTube | @channel | Found, not analyzed | From Google search |
| Telegram | @channel | Found in bio | Channel link |
| Facebook | /page | Found in search | |
| TikTok | — | Not found | |
| LinkedIn | — | Not found | |
| VK | /group | Found in Yandex | |
| Website | domain.uz | Analyzed | |
| 2GIS/Yandex Maps | — | Found/Not found | Business listing |
```

Offer to analyze newly discovered platforms: "Нашёл YouTube канал — запустить анализ?"

### Phase 2: Read All Intelligence

Read every available file. Build mental model of:
- Who is this person/business
- What they sell, to whom, at what price
- What works well (strengths to acknowledge)
- What's broken (our opportunity to sell)
- What assets exist for funnels

### Phase 3: Generate Sales Briefing

Send via `send_message` in multiple messages (Telegram 4096 char limit):

**Message 1 — Client Overview:**
```
*BRIEFING: Встреча с <Name>*
*<Niche> | <Geography>*

📊 *Ключевые цифры:*
• Instagram: <followers> подписчиков, ER: <rate>%
• YouTube: <subs> подписчиков, <videoCount> видео
• Сайт: <domain> (<platform>)
• Цена услуг: <price range>

💼 *Бизнес:*
<2-3 sentence summary of what they do, for whom, how>

🎯 *Целевая аудитория:*
<demographics, pain points, buying behavior>
```

**Message 2 — Web Presence & Search:**
```
*🔍 ПРИСУТСТВИЕ В ИНТЕРНЕТЕ*

*Платформы:*
✅ Instagram: @username (проанализирован)
✅ Сайт: domain.uz (проанализирован)
⬜ YouTube: @channel (найден, не проанализирован)
⬜ Telegram: @channel (найден в био)
❌ TikTok: не найден
❌ LinkedIn: не найден
❌ Facebook: не найден

*Google (запрос "<имя> <ниша> <город>"):*
• Позиция сайта: #<N> / не найден
• Knowledge Panel: есть/нет
• Что на первой странице: <описание>
• Конкуренты в выдаче: <кто занимает топ>

*Yandex (тот же запрос):*
• Позиция: #<N> / не найден
• Карточка организации: есть/нет
• Яндекс.Карты: есть/нет

⚠️ *SEO-возможность:*
"По запросу '<ключевой запрос>' вас не находят — 
первые позиции занимают <конкуренты>. Воронка + контент исправят это."
```

**Message 3 — Strengths & Weaknesses:**
```
*АНАЛИЗ ВОЗМОЖНОСТЕЙ*

✅ *Сильные стороны (отметить на встрече):*
• <strength 1 with specific number>
• <strength 2>
• <strength 3>

⚠️ *Слабые места (наша возможность):*
• <weakness 1> → *Решение:* <what we offer>
• <weakness 2> → *Решение:* <what we offer>
• <weakness 3> → *Решение:* <what we offer>

💡 *Упущенный доход:*
"Вы теряете примерно $<X>/мес потому что <specific problem with numbers>"
```

**Message 4 — Talking Points:**
```
*КОЗЫРИ ДЛЯ ВСТРЕЧИ*

🎯 *Opener (установить экспертизу):*
"Я изучил(а) ваш профиль — у вас <specific impressive metric>. Это в <N>x выше среднего по нише. Значит аудитория горячая и готова покупать."

💰 *Ключевой аргумент (боль → решение):*
"Сейчас вы принимаете заявки через Директ — это <N> потерянных клиентов в месяц. Автоворонка может конвертировать <X>% из них автоматически."

📱 *Демонстрация:*
"Вот воронка которую я уже подготовил(а) для вашего бизнеса — [показать демо]. Она использует ваши реальные фото, цены и отзывы."

🤝 *Закрытие:*
"Запуск первой воронки — <N> дней. Вложения: <price>. Окупаемость при <N> клиентах."

❌ *Если возражение "дорого":*
"Одна воронка приносит <X> клиентов/мес × <price> = <revenue>. ROI через <N> месяцев."

❌ *Если возражение "я сам(а) могу":*
"Конечно. Но <N> часов вашего времени × ваш часовой rate = $<X>. Мы делаем это за <price> и <time>."

❌ *Если "надо подумать":*
"Понимаю. Пока думаете — конкуренты запускают свои воронки. Вот что изменится через 30 дней если начнём сейчас: <specific projection>"
```

**Message 5 — Recommended Funnels:**
```
*РЕКОМЕНДУЕМЫЕ ВОРОНКИ*

🔥 *Quick Win (запуск за 1 день):*
<funnel name> — <service> за <price>
Потенциал: <X> клиентов/мес = $<revenue>/мес

📈 *Основная воронка (запуск за 1 неделю):*
<funnel name> — <service>
Структура: Лендинг → <steps> → Оплата
Потенциал: $<revenue>/мес

🚀 *Масштабная (через 1-2 месяца):*
<funnel name> — курс/программа
Потенциал: $<revenue>/мес

💰 *Суммарный потенциал: $<total>/мес*
```

**Message 6 — Available Assets:**
```
*ГОТОВЫЕ АССЕТЫ*

📸 Фото для баннеров: <N> шт (banner-worthy)
🎥 Видео для уроков: <N> шт (транскрипты готовы)
⭐ Отзывы: <N> шт
💰 Цены: уже известны
📝 Тексты: <N> постов адаптируемы для лендингов

Всё это уже собрано и готово к использованию в воронке.
```

### Phase 4: Create Demo Funnel (optional)

If user says "создай демо-воронку" or "prepare demo":

1. Read client-profile.json → pick Quick Win funnel
2. Select best author photo (banner-worthy from catalog)
3. Use real services/prices from profile
4. If OctoFunnel CRM access available:
   - Open via agent-browser with saved auth
   - Create new funnel through Okto AI chat
   - Provide brief: client name, service, price, target audience
   - Include client's photo as banner
   - Save funnel URL
5. If no CRM access: create funnel brief document with all content ready for manual creation
6. Send demo link/brief to user

### Phase 5: Save to Wiki

Save briefing for future reference and repeat meetings:

`wiki/entities/client-<name>-prep.md`
```yaml
---
title: "Client Prep — <Name>"
type: entity
subtype: client-prep
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: ["[[entities/client-<name>]]"]
tags: [client-prep, meeting, sales]
confidence: high
---
```

Update index + log: `## [YYYY-MM-DD] ingest | Client prep: <Name>`
Git commit.

## Re-prep (repeat meetings)

If prep already exists → read previous, note what changed since last meeting:
"С прошлой встречи: +50 подписчиков, 3 новых поста, цена мастер-класса изменилась..."

## Cost

Zero API cost — reads existing data. Demo funnel creation may use OctoFunnel platform (free for account owner).
