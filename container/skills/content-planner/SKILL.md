---
name: content-planner
description: Create weekly/monthly content plans for social media. Generates topics, formats, posting schedule across platforms (YouTube, Instagram, Telegram, LinkedIn). Reads brand guide, analytics, and audience data to optimize for engagement and conversion. Use when asked to plan content, create a content calendar, or schedule posts.
---

# Content Planner — Social Media Content Strategy

Generate data-driven content plans based on brand identity, analytics performance, audience behavior, and business goals. Plans are actionable — each item has topic, format, platform, and can be sent to design skills for creation.

## Trigger

"контент-план", "план контента на неделю/месяц", "content plan", "что публиковать", "контент-календарь"

## Data Sources

Read before planning:
```bash
# Brand identity
cat /workspace/group/wiki/entities/brand-ashotai.md 2>/dev/null

# Analytics — what content works
cat /workspace/group/zernio-analytics/summary.json 2>/dev/null
cat /workspace/group/zernio-analytics/best-time.json 2>/dev/null
cat /workspace/group/zernio-analytics/frequency.json 2>/dev/null

# Existing content — what's already covered
ls /workspace/group/youtube-analysis/*/channel-summary.json 2>/dev/null
cat /workspace/group/instagram-analysis/*/okto-summary.json 2>/dev/null

# Client cases for content
ls /workspace/group/wiki/entities/farangismaster*.md 2>/dev/null
```

## Workflow

### Phase 1: Audit Current State

From analytics data determine:
- Current posting frequency per platform
- Best performing content (by views, ER, saves)
- Best posting times
- Content gaps (topics not covered)
- Audience interests (from comments, FAQ)

### Phase 2: Set Goals for Period

Ask user or infer from context:
- **Period:** week / 2 weeks / month
- **Goal:** grow followers / drive workshop signups / build authority / launch product
- **Platforms:** which ones active (YouTube, Instagram, Telegram, LinkedIn, X)
- **Capacity:** how many posts/videos per week realistic

Default if not specified: 1 week, all platforms, conversion to ashotai.uz.

### Phase 3: Generate Content Plan

**Content mix formula** (adjust by goal):
- 40% Educational — tips, how-tos, frameworks (builds authority)
- 30% Promotional — offers, case studies, CTAs (drives conversion)
- 20% Personal — behind-scenes, journey, story (builds trust)
- 10% Engagement — polls, questions, trends (boosts algorithm)

**For each content piece specify:**
```
Day: [Пн/Вт/Ср/Чт/Пт/Сб/Вс]
Time: [HH:MM] (from best-time analytics)
Platform: [YouTube / Instagram / Telegram / LinkedIn]
Format: [Video / Carousel / Reel / Post / Story / Article]
Topic: [конкретная тема]
Hook: [первая строка/заголовок]
CTA: [куда ведём — ashotai.uz / TG канал / DM]
Type: [educational / promotional / personal / engagement]
Design skill: [design-instagram-carousel / design-youtube-thumbnail / design-social-post]
```

### Phase 4: Content Calendar

Send as structured message:

```
📅 *КОНТЕНТ-ПЛАН: [период]*
Цель: [goal]

*Понедельник [дата]*
🎬 09:00 YouTube — "Как создать воронку за 30 мин" (educational)
   → Hook: "90% экспертов делают это неправильно"
   → CTA: ashotai.uz
📸 18:00 Instagram — Карусель "5 ошибок в онлайн-продажах" (educational)
   → design-instagram-carousel format: LISTICLE

*Вторник [дата]*
📱 10:00 Telegram — Кейс Фарангиз: "Первая воронка за 1 день" (promotional)
   → design-social-post format: CASE
💼 14:00 LinkedIn — Статья "ИИ в маркетинге 2026" (educational)

*Среда [дата]*
🎬 09:00 YouTube — "Реалити: мой путь к $5000/мес, неделя 3" (personal)
📸 12:00 Instagram — Reel: закулисье работы с ИИ (personal)
📱 18:00 Telegram — Опрос "Какая ваша главная проблема в продажах?" (engagement)

...
```

### Phase 5: Cross-Platform Repurposing Map

Show how one piece of content becomes multiple:

```
*♻️ REPURPOSING*

YouTube видео "Как создать воронку за 30 мин"
  → Instagram: карусель из 5 ключевых шагов (STEPS)
  → Telegram: текстовый пост с главным инсайтом
  → LinkedIn: статья-разбор для профессионалов
  → X/Twitter: 3 твита-тезиса
  → YouTube Shorts: 60-сек отрывок лучшего момента
```

### Phase 6: Topic Bank

Generate 20-30 тем на будущее, сгруппированных:

```
*📚 БАНК ТЫСЯЧ ТЕМ*

*Educational:*
• Как выбрать нишу для онлайн-бизнеса
• 3 типа воронок: какой подходит тебе
• Сколько стоит запуск автоворонки
...

*Promotional:*
• Кейс: $X за Y дней с воронкой Z
• Бесплатный воркшоп — что внутри
...

*Personal:*
• Мой путь: от $0 до первого клиента
• Как я потерял $5000 на первой воронке
...
```

### Phase 7: Save & Schedule

**Save plan to wiki:** `wiki/projects/content-plan-YYYY-MM-DD.md`

**Offer to create content:**
"Начать создавать контент по плану? Могу сгенерировать карусель для понедельника прямо сейчас."
→ Запустить design-instagram-carousel / design-youtube-thumbnail

**Offer to schedule:**
"Запланировать публикации через Zernio?"
→ Запустить zernio-publisher с расписанием

## Recurring Plan (weekly auto-generation)

Can be set as scheduled task:
```
prompt: "Создай контент-план на следующую неделю. Прочитай аналитику за текущую неделю, brand guide, и банк тем. Отправь план в чат."
schedule_type: cron
schedule_value: "0 19 * * 0"  (Sunday 19:00 — plan for next week)
context_mode: group
```

## Integration with Other Skills

| After planning | Skill to use |
|---------------|-------------|
| Create carousel | design-instagram-carousel |
| Create thumbnail | design-youtube-thumbnail |
| Create post visual | design-social-post |
| Publish to platforms | zernio-publisher |
| Track performance | zernio-analytics |
| Weekly review | zernio-monitor |
