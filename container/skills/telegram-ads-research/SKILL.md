---
name: telegram-ads-research
description: Research Telegram channels, bots, and search phrases for ad targeting. Analyzes audiences via Telegram Scanner MCP and web catalogs, scores placements by relevance, generates targeted creatives and a media plan. Use before creating Telegram ad campaigns.
---

# Telegram Ads Placement Research

Find the best channels, bots, and search phrases to target with Telegram Ads. Analyze each placement's audience, then generate personalized creatives for each.

## Trigger

"найди каналы для рекламы", "telegram ads research", "куда запускать рекламу", "ресёрч площадок", "медиаплан для телеграм"

## Prerequisites

- Telegram Scanner MCP (Telethon, port 3002): `list_channels`, `get_messages`, `search_messages`
- `agent-browser` for web catalog browsing (tgstat.ru, telemetr.me)
- Client data from wiki (recommended):
  - `wiki/entities/<client>.md` — profile, services
  - `client-profiles/<client>/profile.json` — structured data
  - `wiki/entities/<client>-funnel-strategy.md` — target audience

## CRITICAL RULES — READ BEFORE STARTING

1. **EVERY channel/bot MUST be verified via agent-browser or Telegram Scanner.** Do NOT invent @usernames from memory. Open tgstat.ru, extract real data, screenshot the page. If you can't verify it exists — don't include it.

2. **Numbers must come from real sources.** Subscriber counts, avg views, ERR — extract from tgstat.ru/telemetr.me pages. If a stat is estimated, mark it explicitly: "~5K (est.)". Never present guesses as facts.

3. **Character count is law.** Ad text ≤ 160 chars, CTA ≤ 30 chars. Count EVERY creative with `echo -n "<text>" | wc -c` before including. Reject and rewrite anything over limit.

4. **NEVER fabricate case studies or testimonials.** No "Алишер, Ташкент: 23 клиента" unless this is a real person with a real result. Use product features and logical arguments instead. Fake social proof destroys trust and may violate Telegram Ads moderation rules.

5. **Use Telegram Scanner for deep analysis.** For every Tier 1 channel, read at least 20 recent posts via Scanner MCP or `t.me/s/<channel>`. Describe what the channel actually posts, not what you assume from the name.

6. **Save evidence.** For each verified channel, save a screenshot or tgstat page extract to `/workspace/global/telegram-ads/research/<client>/evidence/`. This proves the research is real.

## Telegram Ads Targeting Reference

Telegram Ads (ads.telegram.org) supports three targeting types:

| Type | What | Requirement | Strength |
|------|------|-------------|----------|
| **Channels** | Show ads in specific public channels | Channel has 1000+ subscribers | Know exactly what audience reads |
| **Bots** | Show ads to users of specific bots | Bot has 1000+ MAU | Know user intent from bot function |
| **Search phrases** | Show ads when users search Telegram | — | Pure intent signal, like search ads |

All three can be combined with country, language, and topic filters.

**Key insight:** Unlike Meta/Google, you pick EXACT placements. No algorithm decides. This means research quality directly determines ad performance. 100 mediocre placements < 10 perfect ones.

## Phase 1: Define Product & Audience

Load client profile or ask:

```
Что рекламируем?
• Бот: @bot_username
• Канал: @channel_username  
• Воронка/лендинг: URL
• Mini App: URL

Для кого? (ЦА)
• Ниша: <IT, бизнес, маркетинг, образование, красота, ...>
• Язык: <ru, uz, en>
• Гео: <Узбекистан, СНГ, весь мир>
• Боли: <что решаем>
```

From this, derive **seed keywords** (10-20 terms the target audience would follow/search):
```
Пример для OctaFunnel (AI автоворонки):
- автоворонки, воронка продаж, лид магнит
- чат-бот, бот для бизнеса, telegram bot
- онлайн курс, инфобизнес, продюсер
- маркетинг, smm, таргет, трафик
- ии для бизнеса, ai tools, нейросети
- фриланс, удалённая работа, заработок
```

## Phase 2: Channel Research

### 2a. Web catalog scan (agent-browser)

Search channel catalogs for each seed keyword:

```bash
agent-browser open "https://tgstat.ru/search?q=<keyword>&language=ru&country=uz"
# OR
agent-browser open "https://telemetr.me/channels/search/?q=<keyword>"
```

For each result page:
1. Take a snapshot: `agent-browser snapshot` — save to evidence folder
2. Extract REAL data from the page: channel name, @username, subscriber count, avg post views, ERR
3. Filter: subscribers > 1000 (required for ads targeting)
4. Note: language, topic, posting frequency

**Verification step:** For each channel, open `https://t.me/s/<username>` in agent-browser to confirm:
- The channel exists and is public
- The content matches the expected niche
- It's active (posted within last 7 days)

Channels that fail verification → remove from list. Do NOT include unverified channels.

Save raw results to `/workspace/global/telegram-ads/research/<client>/channels-raw.md`
Save screenshots to `/workspace/global/telegram-ads/research/<client>/evidence/`

### 2b. Deep channel analysis (Telegram Scanner)

For top 20-30 channels from catalogs:

```
# If channel is in Scanner's reach:
search_messages(channel: "@channel_name", query: "", limit: 50)
```

Analyze last 50 posts for:
- **Content themes**: what topics dominate?
- **Tone**: formal/informal, educational/entertaining, Russian/Uzbek
- **Audience signals**: comments, reactions, forwards — who engages?
- **Ad presence**: are there already sponsored posts? What do they promote?
- **Posting rhythm**: daily? several per day? sporadic?

If Scanner can't access (not subscribed), use agent-browser:
```bash
agent-browser open "https://t.me/s/<channel_name>"
# Public preview shows last posts without subscription
```

### 2c. Categorize channels

Group by audience intent:

| Category | Example channels | Audience mindset |
|----------|-----------------|------------------|
| **Direct competitors** | Channels selling similar products | Already buying, need better offer |
| **Adjacent niche** | Related topic, not competing | Interested in area, warm lead |
| **Broad interest** | General business/tech/lifestyle | Need education, cold lead |
| **Local** | City/country-specific channels | Geo-relevant, any temperature |

**Priority: Direct > Adjacent > Local > Broad**

## Phase 3: Bot Research

### 3a. Find relevant bots

Search for bots in the niche:
```bash
# Web search for bot catalogs
agent-browser open "https://t.me/s/botlist_ru"
agent-browser open "https://tgstat.ru/bots?q=<keyword>"
```

Also search Telegram directly via agent-browser:
```bash
agent-browser open "https://t.me/search?q=<keyword>&type=bots"
```

### 3b. Analyze each bot

For each relevant bot:
1. Open via agent-browser: `https://t.me/<bot_username>`
2. Note: description, functionality, user count (if visible)
3. Infer audience: who uses this bot and why?
4. Score relevance to our product

Bot types valuable for targeting:

| Bot type | Why target | Example |
|----------|-----------|---------|
| Business tools | Users are business-minded | CRM bots, invoice bots |
| Education bots | Users want to learn | Course bots, quiz bots |
| Marketing bots | Users do marketing | SMM schedulers, analytics |
| Utility bots | Broad audience, specific intent | Currency, weather, translator |

### 3c. Verify and estimate reach

Bots need 1000+ MAU to be targetable.

**Verification:** For each bot, open `https://t.me/<bot_username>` in agent-browser:
- Confirm the bot exists and responds
- Read its description and /start message
- Check if subscriber/user count is visible
- If tgstat.ru has a page for the bot — extract real stats

**Mark clearly:** "verified" vs "unverified (from catalog listing)". Only include bots you actually confirmed exist. If you can't open the bot page — drop it.

## Phase 4: Search Phrase Research

### 4a. Generate phrase candidates

From seed keywords, expand into search queries users might type in Telegram search:

```
Категории фраз:

INTENT (ищут решение):
"как создать воронку продаж"
"бот для приёма заявок"
"автоматизация продаж телеграм"

BRAND (ищут конкретное):
"octafunnel"
"окто воронка"

PROBLEM (ищут из боли):
"мало клиентов"
"как продавать в телеграм"
"нет продаж с инстаграм"

COMPARISON (сравнивают):
"альтернатива getcourse"
"лучший конструктор ботов"
```

### 4b. Validate phrases

For each phrase, check what Telegram shows:
```bash
# Via agent-browser — open Telegram web search
agent-browser open "https://t.me/search?q=<phrase>"
```

Note: what channels/bots/posts appear? This is what users see when they search — our ad will appear here too.

### 4c. Prioritize phrases

Score each phrase:
- **Volume estimate**: common phrase vs niche
- **Intent strength**: "купить курс" > "что такое воронка"
- **Competition**: are competitors advertising on this phrase?
- **Relevance**: does the phrase match our offer?

## Phase 5: Scoring & Ranking

Create a master scoring table. **Only include verified placements** — every row must have a source (tgstat URL, t.me/s/ screenshot, or Scanner data).

```markdown
## Scoring: <Client> Telegram Ads Placements

### Channels (ranked by score)
| # | Channel | Subs | Avg Views | ERR | Source | Verified | Relevance | Category | Score |
|---|---------|------|-----------|-----|--------|----------|-----------|----------|-------|
| 1 | @channel_a | 45K | 8.2K | 18% | tgstat | ✅ | 9/10 | Direct | 92 |
| 2 | @channel_b | 120K | 15K | 12% | t.me/s | ✅ | 7/10 | Adjacent | 85 |

### Bots (ranked by score)  
| # | Bot | Est. MAU | Source | Verified | Relevance | User Intent | Score |
|---|-----|----------|--------|----------|-----------|-------------|-------|
| 1 | @bot_a | 5K | tgstat | ✅ | 8/10 | Business tools | 88 |

### Search Phrases (ranked by priority)
| # | Phrase | Intent | Volume Est. | Competition | Score |
|---|--------|--------|------------|-------------|-------|
| 1 | "создать воронку продаж" | High | Medium | Low | 90 |
```

Scoring formula:
- Relevance (0-10) × 3
- Reach (subscribers/MAU normalized 0-10) × 2  
- Engagement (views/ERR normalized 0-10) × 2
- Intent match (0-10) × 3

**Minimum for inclusion:** Verified = ✅ required for Tier 1 and Tier 2. Tier 3 can include unverified candidates marked with ⚠️.

## Phase 6: Generate Targeted Creatives

For **each of the top 5-10 placements**, generate a personalized ad.

### Mandatory character count

Before finalizing ANY creative, count characters:
```bash
echo -n "Текст рекламы здесь" | wc -c
# Must be ≤ 160 for ad text
echo -n "Кнопка CTA" | wc -c  
# Must be ≤ 30 for CTA button
```
If over limit — rewrite until it fits. Include the character count in the output: `[143/160]`.

### No fake testimonials

**NEVER** generate fictional case studies, fake client names, or invented results. Instead use:
- Product features: "ИИ-воронка строится за 30 минут"
- Logical arguments: "50 клиентов × $200 = $10K выручка"
- Questions: "Готовый AI-бизнес за 4 недели — хочешь попробовать?"
- Specific mechanics: "Платформа OctoFunnel + 6 месяцев бесплатно"

### Channel-specific creative

Read the channel's ACTUAL content (from Scanner or t.me/s/) → understand audience → write ad in their language:

```
Канал: @uzbek_business (бизнес в Узбекистане, узб+рус, 30K подписчиков)
Аудитория: предприниматели 25-45, Ташкент, ищут масштабирование
Проверено: tgstat.ru + t.me/s/uzbek_business (скриншот в evidence/)

Текст: "ИИ-воронка продаёт 24/7. Без менеджера, без сайта" [49/160]
CTA: "Попробовать бесплатно" [21/30]

Почему работает: аудитория знает свой бизнес, но не знает 
про автоматизацию. "24/7" резонирует с болью нанимать менеджеров.
```

For each creative, also generate matching banner if the channel supports media ads.

### Phrase-specific creative

```
Фраза: "бот для приёма заявок"
Текст: "Бот, который сам продаёт — не просто собирает заявки. 
Построй воронку за 30 минут с помощью ИИ"
CTA: "Создать бота"

Почему работает: пользователь ищет бота → мы даём бота И больше.
Фраза "30 минут" конкретна, "ИИ" = дифференциатор.
```

## Phase 7: Media Plan

Compile everything into a media plan:

```markdown
# Медиаплан Telegram Ads: <Product>
Дата: <date>
Подготовлено: AshotAI

## Продукт
<название, URL, что рекламируем>

## Целевая аудитория
<описание ЦА, язык, гео>

## Площадки

### Каналы (N штук)
| Канал | Подписчики | Категория | Креатив |
|-------|------------|-----------|---------|
| @ch1 | 45K | Direct | "Текст варианта A..." |
| @ch2 | 120K | Adjacent | "Текст варианта B..." |

### Боты (N штук)
| Бот | MAU | Категория | Креатив |
|-----|-----|-----------|---------|
| @bot1 | 5K | Tools | "Текст..." |

### Поисковые фразы (N штук)
| Фраза | Интент | Креатив |
|-------|--------|---------|
| "создать воронку" | High | "Текст..." |

## Бюджет
- Тестовый бюджет: X TON (≈ $Y)
- Распределение: 50% каналы, 30% фразы, 20% боты
- CPM ожидание: 0.1-0.5 TON
- Длительность теста: 7 дней

## Стратегия масштабирования
1. Неделя 1: запуск по всем площадкам, минимальный бюджет
2. Неделя 2: отключить площадки с CTR < 0.5%, удвоить бюджет на лидеров
3. Неделя 3+: добавить новые каналы, расширить фразы по аналогии с winning
```

Save to: `wiki/entities/<client>-telegram-ads-mediaplan.md`
Also save raw research to: `/workspace/global/telegram-ads/research/<client>/`

## Integration with Other Skills

- **After research** → use `telegram-ads` skill to generate full creative packages (banners, video) for winning placements
- **After creatives** → use `telegram-ads-manager` skill to create campaigns in ads.telegram.org
- **Ongoing** → re-run research monthly to find new channels/bots, expand media plan
