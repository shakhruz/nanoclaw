---
name: octofunnel-creator
description: Create new OctoFunnel funnels for clients using data from wiki — profile, services, pricing, photos. Fills ОКТО's 3 context layers (business profile, visual style, reference photos), then instructs ОКТО to generate the funnel. Use when asked to create a funnel, build a landing page, or set up a sales funnel for a client.
---

# OctoFunnel Funnel Creator

Create new funnels for clients by feeding ОКТО AI with client data from wiki. Automates the entire funnel creation workflow — from context setup to generation to domain connection.

## Trigger

"создай воронку для @client", "новая воронка", "build funnel", "сделай лендинг для клиента", "демо-воронка"

## Prerequisites

- `agent-browser` + CRM auth
- Client data in wiki (from instagram-analyzer, client-profile, etc.)
- Funnel type recommendation (from funnel-strategist — optional)

## Workflow

### Phase 1: Gather Client Data from Wiki

```bash
CLIENT="<client-name>"
echo "=== Available data ===" 
cat /workspace/group/wiki/entities/$CLIENT.md 2>/dev/null | head -5 && echo "IG entity: OK" || echo "IG entity: MISSING"
cat /workspace/group/wiki/entities/client-$CLIENT.md 2>/dev/null | head -5 && echo "Profile: OK" || echo "Profile: MISSING"
cat /workspace/group/instagram-analysis/$CLIENT/okto-summary.json 2>/dev/null | head -5 && echo "Okto summary: OK" || echo "MISSING"
cat /workspace/group/wiki/entities/$CLIENT-funnel-strategy.md 2>/dev/null | head -5 && echo "Funnel strategy: OK" || echo "MISSING"
ls /workspace/group/wiki/media/instagram/$CLIENT/author/ 2>/dev/null && echo "Author photos: OK" || echo "MISSING"
```

If client data is missing → suggest running instagram-analyzer + client-profile first.

Extract from available data:
- **Business name** and niche
- **Services** with descriptions and prices
- **Target audience** — demographics, pains, desires
- **Unique selling proposition**
- **Testimonials/social proof** from wiki sources
- **Color palette** from brand analysis
- **Author photos** paths from media catalog
- **Funnel type** from funnel-strategy (or ask user)

### Phase 2: Prepare ОКТО Brief

Compile a structured brief (max 2000 chars for chat message):

```
Brief template:
"Создай воронку [ТИП] для [ИМЯ КЛИЕНТА].

Ниша: [ниша]
Услуга: [конкретная услуга]
Цена: [цена в валюте]
Целевая аудитория: [кто, возраст, география, боль]
УТП: [уникальное торговое предложение]
Конкуренты: [чем отличаемся]

Структура:
- Лендинг: [заголовок + подзаголовок]
- Урок/шаг 1: [тема]
- Урок/шаг 2: [тема]  
- Оффер: [что предлагаем, по какой цене]

Отзыв для social proof:
[текст отзыва из wiki]

Язык: русский
Стиль: [профессиональный / тёплый / энергичный]"
```

### Phase 3: Open ОКТО & Configure Context

```bash
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "<SERVER_URL>/?page=aih"
agent-browser wait --timeout 5000
```

**Check if client profile already exists in ОКТО:**
- `agent-browser snapshot` — look at chat list in left panel
- If chat with client name exists → click it, use existing profile
- If no chat → start new one

**Fill 3 context layers** (panels at bottom of ОКТО chat):

**Layer 1 — Бизнес-профиль** (expand panel, fill textarea):
```
agent-browser snapshot -i
# Find "Профиль — Информация о бизнесе" panel
agent-browser click @<profile-panel>
agent-browser wait --timeout 2000
agent-browser snapshot -i
# Clear existing and fill with client data
agent-browser fill @<profile-textarea> "<BUSINESS_PROFILE_TEXT>"
```

Business profile content (from wiki):
```
Имя: [имя клиента]
Бизнес: [ниша и описание]
Услуги: [список с ценами]
Целевая аудитория: [описание]
УТП: [уникальное предложение]
Отзывы: [ключевые цитаты]
Сайт: [URL]
Контакт: [способы связи]
```

**Layer 2 — Визуальный стиль:**
```
agent-browser click @<style-panel>
agent-browser fill @<style-textarea> "<STYLE_PROMPT>"
```

Style prompt (from brand analysis or client's Instagram palette):
```
Стиль: [минималистичный / роскошный / тёплый]
Основные цвета: [#hex1, #hex2, #hex3]
Настроение: [спокойствие / энергия / доверие]
Шрифты: [крупные / элегантные]
```

**Layer 3 — Референсные фото:**
Upload author photos from wiki/media:
```
agent-browser click @<photos-panel>
agent-browser snapshot -i
# Find upload button/area
agent-browser upload @<photo-input> "/workspace/group/wiki/media/instagram/<CLIENT>/author/portrait-1.jpg"
```

Upload 3-5 лучших фото (banner-worthy from catalog).

### Phase 4: Generate Funnel

Send the brief to ОКТО:
```bash
agent-browser fill @<chat-input> "<BRIEF_TEXT>"
agent-browser click @<send-button>
```

ОКТО will ask 10-15 clarifying questions. Answer them using wiki data. When ОКТО starts generating:
- Wait for "Воронка создана!" confirmation
- Screenshot the result
- Send to user for review

### Phase 5: Review & Refine

```bash
export WD=/workspace/group/funnel-creates/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
agent-browser open "<SERVER_URL>/?journey=<NEW_FUNNEL_ID>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/funnel-created.png
```

Send screenshot to user. If changes needed → use octofunnel-editor skill.

### Phase 6: Connect Domain & Payment (optional)

If user wants to launch:
1. **Domain:** Settings → page domain → enter client domain
2. **Payment:** Settings → payment methods → select appropriate method
3. **Triggers:** Stage 0 → add Instagram keywords or Telegram bot trigger

### Phase 7: Save to Wiki & Report

Save funnel details to wiki:
- Update `wiki/entities/<client>.md` — add funnel link and ID
- Append to `wiki/log.md`: `## [YYYY-MM-DD] create | Funnel for <client>: <funnel name>`

Send to user:
```
✅ Воронка создана!
📱 Клиент: <name>
🔗 Редактор: <SERVER_URL>/?journey=<ID>
🌐 Публичная ссылка: <PUBLIC_URL>
📋 Тип: <funnel type>
💰 Услуга: <service> за <price>
```

## Funnel Types Reference

| Type | Best for | Structure |
|------|----------|-----------|
| Workshop | Бесплатный вебинар → платный продукт | Landing → 3 урока → Offer |
| Lead magnet | Бесплатный ресурс → nurture → продажа | Landing → Download → Email series → Offer |
| Direct sales | Продажа в лоб | Landing → Product page → Payment |
| Consultation | Запись на консультацию | Landing → Calendar/Form → Follow-up |
| Mini-course | Серия уроков → upsell | Landing → 3-5 lessons → Premium offer |

## Content Sources

All from wiki:
- `wiki/entities/<client>.md` — business data
- `wiki/entities/<client>-audit.md` — marketing insights
- `wiki/entities/<client>-funnel-strategy.md` — recommended funnels
- `wiki/sources/*testimonial*` — testimonials
- `wiki/media/instagram/<client>/` — photos
- `wiki/entities/brand-ashotai.md` — default brand (if client has no brand guide)
