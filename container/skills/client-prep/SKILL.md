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

**Message 2 — Strengths & Weaknesses:**
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

**Message 3 — Talking Points:**
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

**Message 4 — Recommended Funnels:**
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

**Message 5 — Available Assets:**
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
