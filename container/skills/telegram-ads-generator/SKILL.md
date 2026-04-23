---
name: telegram-ads-generator
description: Generate moderation-safe Telegram Ads (Sponsored Messages) — 160-char text, button label, channel/bot destination. Handles strict Telegram policy — no income claims, no "free" bait-and-switch, no misleading. Use when creating or fixing rejected Telegram ads.
---

# Telegram Ads Generator

Generate moderation-safe Telegram Sponsored Messages. Format: 160-char ad text + optional image/video + link to Telegram channel or bot.

## Trigger

"создай рекламу telegram", "telegram ads", "объявление в телеграм", "реклама в телеграм", "переделай рекламу", "исправь объявление телеграм", "telegram sponsored message"

## Prerequisites

- Client profile data from wiki (niche, USP, offer, target audience)
- Destination: Telegram channel or bot link (must be active, have profile photo and about-text)
- Reference to rejected ad if rewriting (understand WHY it was rejected first)

## Phase 1: Understand the Format

Telegram Ads = **Sponsored Messages** that appear:
- Inside public channels (1,000+ subscribers) between posts
- In Telegram global search results
- Inside bots (1,000+ monthly active users)

**Hard constraints:**
| Field | Limit | Notes |
|-------|-------|-------|
| Ad text | max 160 chars | including spaces, emojis count as 1-2 |
| Ad title | max 30 chars | shown as bold label on button |
| Destination | Telegram only | channel, bot, or post URL (t.me/...) |
| Image | optional | shows above text, increases CPM 50-100% |
| Video | ≤60 sec | optional, increases CPM 50-100% |

**Pricing model:** TON-based CPM auction. Minimum budget ~€1,500. CPM starts at 0.1 TON (~$0.34).

## Phase 2: Compliance Pre-flight (READ BEFORE WRITING)

Official source: ads.telegram.org/guidelines — Section 5 "Prohibited Content"

### 🔴 NEVER include (will get rejected):

**5.4 Deceptive/misleading/predatory:**
- Income promises: "$5000/мес", "заработай X", "зарабатывай на ИИ", "высокий доход"
- Guaranteed results: "100% результат", "гарантированно", "обязательно заработаешь"
- Exaggerated superlatives: "лучший в СНГ", "единственный эксперт", "№1 в Узбекистане"
- Scare tactics: "пока не поздно", "не упусти шанс", "все уже делают это"
- Personal targeting: "ты в долгах?", "твой бизнес теряет деньги?"
- Shock claims: "Я заработал миллион за месяц"

**5.7 Deceptive financial products:**
- Get-rich-quick: "разбогатей быстро", "без вложений", "без рисков"
- MLM/pyramid: "партнёрская программа с доходом", "пригласи и получай"
- Concealed fees: "бесплатно" + уточнение что ведёт к платному → REJECTED

**Other:**
- Income/earning numbers in any form: "$X/мес", "X сум в день"
- "Бесплатный воркшоп/марафон/курс" — если назначение бот/канал с платным предложением
- ALL CAPS words: "БЕСПЛАТНО", "СРОЧНО", "СЕЙЧАС"
- Excessive exclamation marks
- Competitor names

### ✅ SAFE alternatives:

| Запрещено | Безопасная замена |
|-----------|------------------|
| "Зарабатывай $5000 на ИИ" | "Внедряй ИИ в бизнес с нуля" |
| "Бесплатный воркшоп" | "Разбор кейса: бизнес + AI" |
| "Без вложений" | "Для предпринимателей Узбекистана" |
| "Лучший AI-ментор" | "AI-ментор с 30 годами в IT" |
| "Заработай в IT" | "Навыки AI для карьеры и бизнеса" |
| "Пока ещё можно" | "Первый шаг в AI — без воды" |
| "Гарантированный результат" | "Реальные проекты, не теория" |
| "Высокий доход" | "Востребованный навык" |

## Phase 3: Check Destination Quality

Before writing the ad, verify destination meets Telegram's requirements (Section 4):

```
[ ] Channel/bot has profile photo
[ ] Channel/bot has filled About/Description text
[ ] Channel has had posts in the last 14 days
[ ] Bot responds to /start command
[ ] No excessive CAPS/emojis in destination channel name or description
[ ] Channel has real content (not empty or test)
```

If destination fails any check → fix destination FIRST, then write the ad.

## Phase 4: Generate Ad Copy

### Formula: [Hook] + [Value prop] + [CTA or identity]

**Hook options (5-20 chars):**
- Problem-aware: "Внедряешь AI в бизнес?"
- Audience-specific: "Предпринимателям Узбекистана"
- Curiosity: "Как AI меняет малый бизнес"
- Authority: "Chief AI Officer о цифровой автоматизации"

**Value prop (80-100 chars):**
- What they'll LEARN (not earn)
- Concrete skill or tool
- Who it's for
- Social proof without income claims

**CTA (15-30 chars):**
- "Подпишись на канал" / "Открой бота" (if destination is channel/bot)
- "Подробнее @ashotonline"
- "Узнай больше"
- Do NOT use aggressive CTAs: "Жми сейчас!", "Переходи немедленно!"

### Templates by objective:

**Template 1: Channel growth (AI/tech education)**
```
[Аудитория] — [что узнают].
[Конкретный навык без дохода]. [Автор + credibility].
Подпишись: @channel
```
Example (160 chars max):
```
Предприниматели Узбекистана — внедряй ИИ в бизнес.
Автоматизация продаж, AI-агенты, автоворонки. Chief AI Officer с 30 годами опыта.
Канал: @ashotonline
```

**Template 2: Bot/workshop (lead gen)**
```
[Проблема-вопрос без угрозы]. [Что получат: навык/инструмент].
[Credibility без дохода]. [CTA]
```
Example:
```
Хочешь автоматизировать продажи с помощью ИИ?
Разбор реальных кейсов: воронки, боты, AI-агенты для бизнеса.
Пиши @shakhruz_ashirov или открой бот:
```

**Template 3: Authority / personal brand**
```
[Чем занимается автор — факт, без хвастовства].
[Тема канала — конкретно]. [Для кого].
```
Example:
```
Chief AI Officer. 30 лет в IT, 100+ продуктов.
Канал об AI, автоворонках и росте бизнеса — для предпринимателей Узбекистана.
@ashotonline
```

## Phase 5: Generate 3 Variants

Generate minimum 3 variants with different angles:
1. **Education angle** — упор на обучение и навык
2. **Authority angle** — упор на экспертизу и credibility
3. **Community angle** — упор на аудиторию (такие же предприниматели)

For each variant, count characters:
```bash
echo -n "YOUR AD TEXT" | wc -c
```
Must be ≤ 160. If over — trim, do NOT cut value, cut filler words.

## Phase 6: Ad Title (button label, max 30 chars)

The title appears on the button below the ad text. Options:
- Channel name: "@ashotonline"
- Action: "Открыть канал"
- Topic: "AI для бизнеса"
- CTA: "Узнать больше"

Check: `echo -n "TITLE" | wc -c` ≤ 30.

## Phase 7: Compliance Checklist

Run before delivering:

```
[ ] Ad text ≤ 160 characters
[ ] No income promises ($X/мес, зарабатывай, высокий доход)
[ ] No "бесплатно" for paid-upsell funnel
[ ] No guaranteed results
[ ] No ALL CAPS words
[ ] No scare/urgency tactics
[ ] No income numbers of any kind
[ ] No competitor names
[ ] Destination is t.me/... link (not external URL unless special format)
[ ] Destination channel is active (posts in last 14 days)
[ ] Destination has profile photo and about text
[ ] Ad title ≤ 30 characters
[ ] Single link in ad (not multiple @mentions)
```

If ANY fails → rewrite. Do not submit.

## Phase 8: What to Fix When Ad is Rejected

Check rejection reason in Telegram Ads cabinet:

| Rejection reason | What to fix |
|-----------------|-------------|
| "Deceptive, misleading, or predatory" | Remove income claims, free bait, superlatives |
| "Destination requirements not met" | Add photo + about to channel/bot; post content |
| "Prohibited financial products/services" | Remove get-rich-quick elements |
| "Clickbait" | Soften hooks, add factual credibility |
| "Third party rights" | Remove brand names, competitor mentions |
| Generic rejection | Test each element separately; tone down urgency |

**Rewriting rejected ads:**
1. Read rejection reason carefully
2. Identify ALL violating elements (usually more than one)
3. Rewrite from scratch using Safe Alternatives table above
4. Do not just replace one word — reframe the entire message

## Phase 9: Save & Deliver

Output format:
```
TELEGRAM AD — Вариант #N

Текст объявления (X/160 символов):
<ad text>

Заголовок кнопки (X/30 символов):
<button title>

Назначение: t.me/<channel_or_bot>

Проверка модерации:
✅ Без обещаний дохода
✅ Без "бесплатно" для платного продукта
✅ Активное назначение
✅ ≤ 160 символов
✅ Заголовок ≤ 30 символов
```

Save to: `wiki/entities/<client>-telegram-ads.md`

## Cost Reference

| Format | CPM Base | Notes |
|--------|----------|-------|
| Text only | 0.1 TON (~$0.34) | cheapest, fastest moderation |
| Text + image | 0.15-0.2 TON | +50% CPM |
| Text + video | 0.2-0.3 TON | +100% CPM |
| Minimum budget | ~€1,500 (≈$1,650) | required to start |

Note: Telegram Ads runs on TON blockchain payments. Requires TON wallet or Telegram Stars.

## Notes

- Telegram does NOT collect user data — targeting is by channel topics, not demographics
- Ads are hidden from Telegram Premium users (they don't see ads)
- Moderation takes 3-5 business days for Finance/Education verticals
- Rejection bans can carry over to future ads — clean history matters
- For CIS/UZ audience: "IT Community of Uzbekistan", "Бизнес Узбекистан", "Предприниматели СНГ" are good targeting channels
