---
name: telegram-ads
description: Generate Telegram Ads creatives — ad copy, banner images, and video ads. Analyzes client profile and funnel to craft compliant ads that convert. Supports sponsored messages (text), media-enhanced ads (image/video), and story ads. Use when asked to create Telegram ad campaigns or creatives.
---

# Telegram Ads Creative Generator

Generate complete ad packages: copy + image + video for Telegram Ads platform (ads.telegram.org).

## Trigger

"реклама в телеграм", "telegram ad", "telegram ads", "рекламный баннер", "креатив для телеграм"

## Prerequisites

- `$OPENROUTER_API_KEY` for image + video generation
- Client data from wiki (recommended) or ad text from user
- Funnel URL or bot username (what we're advertising)

## Related Skills

- **Before this skill:** Run `telegram-ads-research` to find channels, bots, and search phrases for targeting. The research produces a media plan with scored placements.
- **After this skill:** Run `telegram-ads-http` to create campaigns in ads.telegram.org and upload creatives.

## Targeted Mode (from media plan)

When a media plan exists (`wiki/entities/<client>-telegram-ads-mediaplan.md`), use **targeted mode** — generate creatives personalized to each placement:

1. Read the media plan → get top placements with audience analysis
2. For each placement, generate ad text that speaks to THAT audience
3. Generate banners matching the channel's visual tone
4. Result: N placement-specific creative packages instead of 1 generic

Example: channel about business automation gets "Автоматизируй продажи с ИИ", while a marketing channel gets "Твои клиенты из Instagram уходят к конкурентам — поставь бота".

## TON Payment Reference

- **Platform:** ads.telegram.org (web-only, no API)
- **Currency:** TON (Toncoin)
- **Min deposit:** 20 TON (≈ $105)
- **Min CPM bid:** 0.1 TON
- **Revenue split:** 50% goes to channel owners
- **Moderation:** 24-48 hours after submission
- **No limit on ad count** — create many targeted ads for different placements

## Telegram Ads Specs

### Ad Placements

| Placement | Text | Image | Video | CTA |
|-----------|------|-------|-------|-----|
| Sponsored message (classic) | 160 chars | No | No | 30 chars button |
| Sponsored message (media) | 160 chars | Yes | Yes | 30 chars button |
| Story ad (full-screen) | Overlay | 1080x1920 | 1080x1920, 15s | Swipe-up |

### Image Specs
- **Sponsored media:** 1280x720 (16:9 landscape) or 1080x1080 (1:1 square)
- **Story ad:** 1080x1920 (9:16 portrait, full-screen)
- **Format:** JPG/PNG, max 5MB
- **Text on image:** max 20% area
- Design for BOTH dark and light Telegram themes

### Video Specs
- **Sponsored media:** 1280x720 (16:9), up to 15 seconds
- **Story ad:** 1080x1920 (9:16), up to 15 seconds
- **Format:** H.264 MP4, max 10MB (sponsored) / 30MB (stories)
- **Audio:** Optional, muted by default — design for sound-off
- **Hook:** First 2 seconds must grab attention

### Text Rules
- Max 160 characters ad text (80-120 optimal)
- Max 30 characters CTA button
- No ALL CAPS entire text
- No excessive punctuation (!!!, ???)
- Emojis allowed (limited, 1-2 max)
- Language must match target audience
- No phone numbers in text
- No misleading or clickbait claims
- Review time: 24-48 hours

## Phase 1: Load Context

```
wiki/entities/olx-uz-platform.md              ← reference for compliance mindset
wiki/entities/<client>.md                      ← client profile
wiki/entities/<client>-funnel-strategy.md      ← which funnel to advertise
wiki/entities/brand-<client>.md                ← colors, tone
client-profiles/<client>/profile.json          ← structured data
client-profiles/<client>/reference-photo.jpg   ← for image generation
```

Extract: niche, USP, target audience pain points, brand colors, funnel URL/bot, credentials.

If user provides ad text — skip to Phase 3.
If no data — ask: "Что рекламируем? (бот/канал/воронка) + для кого?"

## Phase 2: Generate Ad Copy

### Step 1: Choose ad goal

```
Цель рекламы:
1. Подписка на канал — "Подписывайся на @channel"
2. Запуск бота — "Запусти @bot и получи..."
3. Переход на воронку — "Регистрируйся на вебинар/курс"
4. Mini App — "Открой приложение"
```

### Step 2: Write 3 variants (A/B/C)

Use AIDA framework adapted for 160 chars:

**Template: Attention + Interest + CTA**
```
[Attention hook — боль или вопрос] + [Benefit — что получит] + [CTA button — действие]
```

**Examples by niche:**

IT/AI обучение:
```
A: "Нейросети создают сайты за 30 минут. Научись этому бесплатно — 3 урока с практикой"
   CTA: "Начать обучение"

B: "ИИ заменит маркетологов? Нет — но маркетолог с ИИ заменит без. Освой за неделю"
   CTA: "Узнать как"

C: "Создавай лендинги, боты и воронки с помощью ИИ. Без кода, без дизайнера"
   CTA: "Попробовать бесплатно"
```

Услуги:
```
A: "Упаковка бизнеса онлайн за 30 минут. ИИ делает сайт, бота и воронку за вас"
   CTA: "Получить демо"

B: "<Name> помог 50+ клиентам запустить онлайн-продажи. Бесплатная консультация"
   CTA: "Записаться"
```

**Rules for each variant:**
- Count characters: body ≤ 160, CTA ≤ 30
- No ALL CAPS
- Max 1-2 emoji
- First 50 chars = hook (visible in preview)
- Specific > generic ("30 минут" > "быстро")
- Question hooks have highest CTR

Show all 3 to user, ask which to develop visuals for.

## Phase 3: Generate Ad Image

### Step 1: Choose format

```
Формат баннера:
1. Landscape 16:9 (1280x720) — для sponsored message
2. Square 1:1 (1080x1080) — для sponsored message
3. Story 9:16 (1080x1920) — для story ads
4. Все три — полный комплект
```

### Step 2: Design concept from ad copy

Analyze the chosen ad text and extract:
- **Key visual idea** — what image communicates the message
- **Emotional tone** — urgency, curiosity, trust, excitement
- **Color scheme** — from brand guide or auto-select

### Image Presets

| Preset | Visual | Best for |
|--------|--------|----------|
| Problem-Solution | Split: grey/dull left (problem) → bright/colorful right (solution) | Course/education |
| Social Proof | Person + numbers/metrics overlay | Consulting/services |
| Tool Demo | Screenshot/mockup of the product in action | SaaS/bot/app |
| Face + Hook | Person's face + large text hook on branded bg | Personal brand |
| Minimalist | Bold text on gradient, no photo | Universal |
| Before-After | Two states side by side | Transformation |

### Step 3: Generate

```bash
export WD=/workspace/global/telegram-ads/creatives/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
```

**With client reference photo:**
```bash
PHOTO_B64=$(base64 -w0 "<reference_photo_path>")

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model":"google/gemini-3.1-flash-image-preview",
    "messages":[{"role":"user","content":[
      {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$PHOTO_B64"'"}},
      {"type":"text","text":"Telegram ad banner, <WIDTH>x<HEIGHT>.
Ad concept: <VISUAL_CONCEPT>.
Use THIS person in the image.
Text overlay (Russian, Cyrillic, large and readable): '"'"'<SHORT_HOOK_TEXT>'"'"'
Background: <brand_colors gradient/solid>.
Style: modern, clean, high contrast, works on both dark and light backgrounds.
Minimal text — max 20% of image area. No small text. Bold and readable.
Professional advertising quality."}
    ]}]
  }'
```

**Without photo (text-focused):**
```
"Telegram ad banner, <WIDTH>x<HEIGHT>.
<VISUAL_CONCEPT>.
Large bold text (Russian, Cyrillic): '<HOOK_TEXT>'
Smaller subtitle: '<BENEFIT_TEXT>'
Background: <brand_colors>.
Style: advertising, high contrast, attention-grabbing.
Works on both dark and light Telegram themes.
Max 20% text coverage. Clean, no clutter."
```

Generate 2-3 variants per format. Save to `$WD/`.

## Phase 4: Generate Ad Video

### Step 1: Choose video preset

```
Видео-реклама:
1. Kinetic Text — анимированный текст на градиенте (5-10 сек)
2. Person + Effects — человек + VFX на фоне (5 сек)
3. Product Demo — показ продукта/бота в действии (10-15 сек)
4. Story Hook — интригующее начало + CTA (5-10 сек)
```

### Video Preset Prompts

| Preset | Prompt |
|--------|--------|
| Kinetic Text | "Animated text appearing word by word on a vibrant gradient background. Bold Russian text: '<AD_TEXT>'. Colors shift smoothly. Modern motion graphics style. Professional ad quality." |
| Person + Effects | "The person looks at camera, smiles confidently, <action>. Glowing particles and light effects around them. Text overlay appears: '<HOOK>'. Background: <brand_colors>. Cinematic, professional ad." |
| Product Demo | "Screen recording style: a phone/laptop showing a chat bot interface. Messages appear one by one. Clean UI. Text overlay: '<BENEFIT>'. Professional product demo aesthetic." |
| Story Hook | "Fast-paced montage: <problem_scene> cuts to <solution_scene>. Text flashes: '<HOOK>'. Ends with CTA: '<CTA_TEXT>'. Energetic, attention-grabbing. 9:16 vertical." |

### Step 2: Generate via OpenRouter Video API

```bash
# For sponsored message video (16:9):
IMAGE_B64=$(base64 -w0 "$WD/<best-banner>.png")

RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/videos" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"alibaba/wan-2.6\",
    \"prompt\": \"<PRESET_PROMPT>\",
    \"frame_images\": [{\"type\": \"image_url\", \"image_url\": {\"url\": \"data:image/png;base64,${IMAGE_B64}\"}, \"frame_type\": \"first_frame\"}],
    \"duration\": 5
  }")

VIDEO_ID=$(echo "$RESPONSE" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).id))")
```

Poll + download + post-process (same as design-avatar):
```bash
# Wait for completion
# Download from unsigned_urls[0]
# Post-process:
ffmpeg -y -i $WD/video-raw.mp4 \
  -vf "scale=1280:720" \
  -c:v libx264 -b:v 3000k -maxrate 4000k \
  -an -movflags +faststart \
  -t 15 \
  $WD/video-ad-16x9.mp4

# Verify ≤ 10MB
```

For story format (9:16), adjust scale to 1080:1920.

## Phase 5: Compliance Review

**Full policy reference:** https://ads.telegram.org/guidelines

### Past rejections (learn from these)

**2026-04-18 — "Воркшоп: продажи с AI" → REJECTED (destination)**
- Text: "Как продавать с помощью AI? Воркшоп для предпринимателей — разбор инструментов. Смотреть бесплатно."
- Destination: `t.me/ashotaiuz_bot`
- **Why:**
  - Personal question "Как продавать с помощью AI?" (5.4 — highlighting personal characteristics / asking personal questions about financial/business status)
  - "для предпринимателей" — targeting by professional status (same clause)
  - Bot that mostly redirects to funnel (ashotai.uz) — 4.3 "Mostly noninteractive bots designed to redirect elsewhere"
  - Possibly bot profile incomplete (4.1)

### Destination requirements (CRITICAL — most common rejection cause)

For **bot destinations** (`t.me/<bot>`):
- **Must have profile image** (not default)
- **Must have complete /about or description** (what the bot does, what value it provides)
- **Must respond to commands meaningfully** — not just send a single redirect link
- **Must provide user experience inside Telegram** — not be a thin wrapper that dumps a URL
- Bots that immediately redirect to an external funnel fail 4.3

**If advertising a bot:** make sure the bot has real content — FAQ, menu with options, multiple conversation branches. Link to funnel should be ONE option among several, not the whole bot.

For **channel destinations** (`t.me/<channel>`):
- Must have profile image AND description
- Must have had activity in the last 2 weeks
- Language must match the ad language

For **website destinations** (`https://...`):
- Must load from targeted countries
- No paywall/login block
- No auto-redirect (302, .htaccess) to a different domain

### Prohibited ad-text patterns (with rewrites)

| ❌ REJECTED pattern | Why | ✅ APPROVED rewrite |
|---|---|---|
| "Как продавать с помощью AI?" | 5.4 personal question | "AI-инструменты для продаж. Разбор на воркшопе." |
| "для предпринимателей" | 5.4 targeting by status | "Воркшоп по AI-автоматизации" |
| "для всех кто хочет заработать" | 5.4 targeting financial status | "Обучение работе с AI" |
| "Смотри что скрывают эксперты" | 5.4 clickbait / scare tactic | "Разбор инструментов от практика" |
| "Заработай $5000/мес" | 5.7 get-rich-quick | "Тарифы от $200/мес в описании" |
| "Гарантируем результат" | 5.4 absolute claim / 5.7 investment guarantee | "Практика на реальных кейсах" |
| "Лучший в СНГ курс" | 5.4 unsupported superlative | "Образовательная программа по AI" |
| "Не пропусти!" | 5.4 scare tactic | (just remove — let the value speak) |
| "ЖМИ!" / "!!!" / "🔥🔥🔥" | 2. editorial — excessive caps/punctuation/emoji | Calm, neutral tone |
| "Ты хочешь...?" | 5.4 addressing "you" with a personal question | "Обучение ...", "Программа..." |

### Pre-submission validator (run BEFORE uploading to ads.telegram.org)

```
TELEGRAM ADS CHECKLIST v2 (post-2026-04-18 rejection):

— AD TEXT —
[ ] ≤ 160 characters
[ ] No personal questions ("Как ты...?", "Хочешь...?", "Любишь...?")
[ ] No targeting by profession/status ("для предпринимателей", "для мам", "для начинающих")
[ ] No absolute claims ("лучший", "самый", "№1", "гарантия")
[ ] No income/get-rich claims ("заработай", "$X в месяц", "от $X")
[ ] No scare/urgency ("не пропусти", "последний шанс", "пока не поздно")
[ ] No "бесплатно" as the main hook (ok if factual: "доступ бесплатный")
[ ] No ALL CAPS words (except well-known acronyms: AI, CRM, API)
[ ] Max 1-2 emoji
[ ] No phone numbers
[ ] No double spaces / letter-spaced words (s p a c e d)
[ ] Proper punctuation (no "!!!" or "????")

— DESTINATION (bot) —
[ ] Bot has profile image (not default silhouette)
[ ] Bot /about filled with 2-3 sentences explaining what it does
[ ] Bot responds to /start with a menu of options, not just a link
[ ] Bot has 3+ meaningful commands/branches (not just redirect)
[ ] Bot is functional on mobile + desktop

— DESTINATION (channel) —
[ ] Channel has profile image
[ ] Channel has description (1-3 sentences)
[ ] Channel has ≥1 post in last 14 days
[ ] Channel post language matches ad language
[ ] Channel is NOT abandoned (posts > 30 days old → reject risk)

— DESTINATION (website) —
[ ] Loads in target countries (test with VPN)
[ ] No paywall / no login required
[ ] No 302 redirect to different domain
[ ] HTTPS only
[ ] Loads in < 5s

— CREATIVE (image/video) —
[ ] Image text ≤ 20% area
[ ] No fake buttons / UI mimicry
[ ] No before/after miracle transformation
[ ] No stock photos of people that might imply personal targeting
[ ] Video ≤ 15s (sponsored) / full-screen (story)
[ ] Video file ≤ 10MB (sponsored) / 30MB (story)
[ ] Hook in first 2 seconds

— TARGETING —
[ ] Language of ad matches language of target channels
[ ] Channel categories align with product (no "любое чтобы охват был больше")
```

### How to fix the 2026-04-18 rejection

Before resubmitting, do ALL of these:

1. **Rewrite ad text** — remove personal question + profession targeting:
   ```
   Before: "Как продавать с помощью AI? Воркшоп для предпринимателей — разбор инструментов. Смотреть бесплатно."
   After:  "Практический воркшоп по AI-инструментам. Разбор задач малого бизнеса. Запись доступна в боте."
   ```

2. **Fix bot destination** (`@ashotaiuz_bot`):
   - Set profile image (NanoClaw logo or Ashot's photo)
   - Fill /about: "AI-ассистент AshotAI. Воркшопы, разборы инструментов, запись эфиров."
   - Add /start menu with 3-5 buttons: Воркшоп | Последний эфир | Тарифы | Связаться | FAQ
   - Ensure each button leads to internal bot content (not just external URL)

3. **Alternative — switch destination to `@ashotonline`** (channel):
   - Channel has activity (daily posts now, AI news digest)
   - Has profile image and description
   - Lower rejection risk than bot

4. Resubmit via ads.telegram.org "Send to Review" button.

## Phase 6: Save & Deliver

Save to wiki:
```bash
cat > /workspace/group/wiki/entities/<client>-telegram-ad-<N>.md << 'EOF'
# Telegram Ad #N: <client>
Date: <date>
Goal: <subscription/bot/funnel>
Destination: <@bot or URL>

## Ad Variants
A: "<text>" | CTA: "<cta>"
B: "<text>" | CTA: "<cta>"
C: "<text>" | CTA: "<cta>"

## Creatives
- Banner 16:9: <path>
- Banner 1:1: <path>
- Story 9:16: <path>
- Video 16:9: <path>

## Compliance: PASSED
EOF
```

Deliver full package:
```
Рекламный пакет для Telegram Ads
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Цель: <goal>
Аудитория: <target>

Тексты (3 варианта A/B/C):
A: "<text>" [<chars> символов]
B: "<text>" [<chars> символов]
C: "<text>" [<chars> символов]

Баннеры: 16:9 + 1:1 + 9:16 (story)
Видео: 5-15 сек, H.264

Рекомендация: запустить A и B на тест, бюджет 50/50.
Проверка через 48ч после модерации.

Стоимость генерации: ~$0.02 (images) + ~$0.50 (video)
```

## A/B Testing Strategy

After launch:
- Run 2-3 text variants on same audience
- Run image vs video on same text
- Check after 48-72 hours: CTR, CPC, conversions
- Kill underperformers, scale winners
- Iterate: new variants based on winning patterns

## Search Phrase Creatives

When targeting search phrases, the ad text must directly answer the search intent:

| User searches | Ad should | Example |
|---------------|-----------|---------|
| "как создать бота" | Offer a solution | "Создай бота за 30 минут с ИИ — без кода" |
| "воронка продаж" | Show expertise | "Автоворонка с конверсией 12% — ИИ строит за тебя" |
| "курсы маркетинга" | Differentiate | "Не курсы — готовый инструмент. ИИ делает маркетинг за вас" |

Rules for search phrase ads:
- First 50 chars must match the search intent
- Use the exact phrase (or close variant) in the ad text
- CTA should be the logical next step after the search
- More specific = higher CTR (don't be generic)

## Cost

- Ad copy: $0 (generated by agent)
- Images (3 formats x 2 variants): ~$0.02
- Video (1 variant): ~$0.50
- Total creative package: ~$0.55
