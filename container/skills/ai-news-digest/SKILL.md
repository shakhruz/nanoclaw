---
name: ai-news-digest
description: Daily AI news digest from curated Telegram channels. Reads the NEWS folder via Telegram Scanner, analyzes last 24h of posts across all channels, deduplicates overlapping stories, ranks by importance, and delivers a morning briefing with analysis and personal relevance. Use for morning briefings or on-demand digest requests.
---

# AI News Morning Digest

Scan curated AI-focused Telegram channels every morning, synthesize the most important stories into a concise briefing with personal context for Shakhruz.

## Trigger

- Scheduled: daily at 8:00 Tashkent (via scheduled task)
- On-demand: "новости", "сводка", "что нового в AI", "ai news", "digest"

## Prerequisites

- Telegram Scanner MCP (Telethon, port 3002): `list_channels`, `get_messages`, `search_messages`
- NEWS folder in Telegram (curated by Shakhruz via Telegram app)
- Wiki context for relevance analysis (OctaFunnel, AshotAI, current projects)

## Philosophy

This is NOT a feed aggregator. It's a **research assistant**. Each morning digest should answer:

1. **What actually happened in AI yesterday?** (not: what did people post about)
2. **Why should Shakhruz care?** (connection to his business, projects, interests)
3. **What's worth reading in full?** (link prioritization)
4. **Is a topic heating up?** (trend detection across days)

Quality bar: after reading the 5-minute digest, Shakhruz knows what he needs to know — no opening Telegram required.

## Channel Sources

### Primary: NEWS folder (Shakhruz-curated)
Access via Telegram Scanner:
```
list_channels() → channels in NEWS folder
```

These are Shakhruz's trusted sources. Priority signal — stories mentioned here matter most.

### Secondary: Ad-research channels (business relevance)
Channels we identified for Telegram Ads targeting (`wiki/entities/octafunnel-telegram-ads-mediaplan.md`) — reading these tells us what our target audience cares about. Not for news itself, but for market signal.

### Adding new channels
If the user mentions a new AI channel worth tracking, or if research reveals a high-signal source:
1. Confirm with user: "Добавить @channel_name в NEWS folder?"
2. If yes: the user adds it manually via Telegram app (Scanner reads folder dynamically)
3. Alternative: subscribe via Scanner's Telethon session, then user adds to NEWS folder

Scanner cannot modify folder membership — folder management is user-controlled.

## Workflow

### Step 1: Gather raw material

```
channels = list_channels()  # All channels in NEWS folder
```

For each channel, pull last 24 hours of posts:
```
posts = get_messages(channel=<id>, since=<24h ago>, limit=50)
```

Collect post metadata:
- Channel name + @username
- Post date/time
- Post text (full)
- Views, forwards, reactions (engagement signals)
- Media type (text, image, video, link)
- Post URL (t.me/<channel>/<msg_id>)

Raw dump goes to `/workspace/group/ai-news/YYYY-MM-DD/raw-posts.json`.

### Step 2: Classify posts

Each post is one of:

| Category | Description | Example |
|----------|-------------|---------|
| 🚀 **Launch** | New product/model/feature released | "OpenAI announces GPT-5..." |
| 📊 **Research** | Paper, benchmark, technique | "New method for RAG..." |
| 💰 **Business** | Funding, acquisition, pricing | "Anthropic raises $5B..." |
| 🏛️ **Policy** | Regulation, legal, geopolitics | "EU AI Act amendment..." |
| 🎯 **Tool/Tip** | Practical how-to, workflow | "How to use Claude for X..." |
| 💭 **Opinion** | Analysis, hot take, prediction | "Why LLMs won't replace..." |
| 📢 **Event** | Conference, demo, livestream | "AI Summit tomorrow..." |
| 🗞️ **Meta-news** | News about AI industry itself | "Layoffs at AI startup..." |

Skip: memes without substance, pure promotion of unknown tools, chain forwards with no added value.

### Step 3: Deduplicate stories

Multiple channels often post the same story. Group by topic:
- Same URL referenced → same story
- Same person/company + same event → same story
- Same paper/announcement → same story

For each story cluster:
- Keep the most detailed/earliest post as primary
- Note how many channels covered it (signal of importance)
- Aggregate engagement across all mentions

### Step 4: Score importance

For each story cluster:

```
importance_score = 
  channel_coverage (1-5)      # how many NEWS channels covered it
  × 3
+ total_engagement (0-10)     # normalized views+forwards+reactions
  × 2
+ category_weight (1-10)      # Launch/Research > Meta-news
  × 2
+ personal_relevance (0-10)   # matches Shakhruz's interests
  × 3
```

Personal relevance rules:
- **+10**: Mentions Claude, Anthropic, OctoFunnel, our stack
- **+8**: Telegram Ads, Telegram bots, automation tools
- **+7**: Sales funnels, AI for business, infobusiness
- **+6**: RU/UZ market specifically
- **+5**: Entrepreneur/small business focus
- **+3**: General AI research/industry
- **0**: Unrelated (celebrity gossip, generic politics)

### Step 5: Identify trends

Compare against previous days:
```
Check /workspace/group/ai-news/YYYY-MM-DD-1/digest.md and -2/
```

A topic is "heating up" if:
- Multiple channels covered it 2-3 days in a row
- Engagement increased day-over-day
- It connects to something Shakhruz has been working on

Flag heating topics with 🔥 in the digest.

### Step 6: Synthesize briefing

**Translation rules (EN → RU):**

If a story originates from an English-language channel:
- **Headline**: translate to Russian (natural, not literal — convey meaning)
- **Summary**: write in Russian (don't just translate — synthesize what matters)
- **Quotes**: keep in original English, add Russian translation in parentheses
- **At end of story**: append `*EN источник: @channel_name*`
- **Link**: always keep original URL (t.me/...)

Example:
```
### 1. OpenAI выпустила новую модель GPT-5 с улучшенным reasoning
OpenAI анонсировала GPT-5 — модель с встроенным chain-of-thought reasoning, 
которая обходит предыдущие бенчмарки на 15%. Доступна в API с сегодняшнего дня.
📰 Освещено: @ai_news, @openai_official  
🔗 [Подробнее](t.me/ai_news/12345)
💡 **Почему важно:** Прямое влияние на Claude как конкурента.
*EN источник: @openai_official*
```

Structure:

```markdown
# AI-сводка <DD Month YYYY>
*Просканировано: N каналов, M постов | Отобрано: K историй*

## 🔥 Горячее сегодня

### 1. <Story headline>
<2-3 sentence summary>
📰 Освещено: @channel1, @channel2, @channel3
🔗 [Подробнее](t.me/channel/post_id)
💡 **Почему важно:** <personal relevance explanation>

### 2. <Story headline>
...

## 📊 Что ещё стоит знать

### Запуски и продукты
- Brief bullet on launch X [link]
- Brief bullet on launch Y [link]

### Исследования и техники
- New paper on Z [link] — TL;DR
- Benchmark result [link]

### Бизнес и деньги
- Funding round [link]
- Acquisition [link]

## 💭 Интересные мнения

- "<quote snippet>" — @channel [link]
  Мой взгляд: <optional Mila commentary>

## 📈 Тренды недели

- 🔥 Topic X — 3 день подряд в топе, набирает обороты
- 📉 Topic Y — вчера активно обсуждали, сегодня стихло

## 🎯 Action items для тебя

- [ ] Посмотреть <specific thing>, потенциально для OctaFunnel
- [ ] Ответить на вопрос от @someone
- [ ] ...

---
*Следующая сводка: завтра 8:00 | Каналы: /sources | Обратная связь: ответ на это сообщение*
```

### Step 7: Deliver

**Quiet day skip:** If no stories scored above importance threshold (e.g. all scores < 30), OR the story list is empty — do NOT send a message. Log to `wiki/log.md` as `## [date] digest | skipped (quiet day, N posts scanned, no important stories)` and exit silently. Don't fabricate importance to fill space.

Otherwise: send the **private** version via `send_message` to Shakhruz in the main chat.

If digest is long (>4000 chars), split by major section breaks. Telegram limit per message is 4096.

### Step 7b: Public publish (if enabled)

If the task config sets `public_publish: true` and `public_channel: "@ashotonline"` (or similar), ALSO prepare a **public-facing version** and publish via `telegram-channel-publisher` skill.

**Public version differs from private:**
- **More personal tone** — "я вижу", "мне кажется", "важно для нас" (not neutral news-speak)
- **Top 3-5 stories only** (not everything from private digest)
- **Each story: 1-2 sentences + Ашот's take**
- **No action items / no weekly trend section** (those are Shakhruz-personal)
- **Hashtags at bottom:** `#AIновости #{date}`
- **Preview image** generated via OpenRouter

**Run through `humanizer-ru` before publishing (MANDATORY).** Public posts must not read as AI-generic — pass the draft through humanizer-ru skill to strip канцелярит, negative parallelisms, "важно отметить" phrases, and add Ashot's voice. Without this step, the channel sounds like a generic AI feed. Never skip.

Template for public digest:

```
🌅 *AI сводка — {DD month}*

<Краткое введение 1-2 предложения, что день принёс>

*🚀 <Story 1 headline>*
<1-2 sentences>
💭 <Личное мнение Ашота>
🔗 [подробнее]({url})

*📊 <Story 2 headline>*
...

— — —
Если вы хотите следить за AI без скроллинга 10 каналов — этот канал для вас. Ежедневная сводка, без воды.

#AIновости #{YYYY_MM_DD}
```

**Generate preview image** (16:9, 1280x720) — dark background, topic visual cue, text "AI сводка — DD month". Save to `/workspace/group/content/{date}-ai-digest.jpg`.

**Publish via telegram-channel-publisher:**
```
mcp__telegram-scanner__publish_to_channel(
  channel="ashotonline",
  text="<public digest text>",
  image_path="/workspace/group/content/{date}-ai-digest.jpg"
)
```

After publishing, notify Shakhruz in main chat:
```
📢 Опубликовала в @ashotonline: AI сводка за <date>
🔗 <post_url>
```

Auto-publish without approval — Shakhruz moderates post-factum.

### Step 8: Wiki Ingest (top-5 stories)

For the **top-5 highest-scored stories** of the day, create full wiki source-summaries. This makes them searchable for content planning later.

For each top-5 story:

1. Create `wiki/sources/YYYY-MM-DD-ai-news-<slug>.md`:

```markdown
---
title: "<Story headline in Russian>"
type: source-summary
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources:
  - <original t.me link>
  - <other sources if multiple channels covered>
related: []
tags: [ai-news, <topic-tags>]
confidence: high
ai-news:
  date: YYYY-MM-DD
  score: <importance score>
  channels: [@ch1, @ch2]
  category: launch|research|business|policy|tool|opinion|event|meta
  language: ru|en (original)
---

## Что произошло

<Russian summary, 3-5 sentences>

## Контекст

<Why this matters, how it connects to AI landscape>

## Релевантность для Ашота

<Personal relevance explanation — why it matters for OctaFunnel, NanoClaw, or his interests>

## Источники

- Primary: [t.me link]
- Coverage: @channel1, @channel2, @channel3
- English original (если применимо): [link]

## Связи

- [[concepts/<related-concept>]]
- [[entities/<related-entity>]]
```

2. Update relevant wiki pages (concepts, entities, people) with references to this story.
3. Add entry to `wiki/index.md` under appropriate category.
4. Git commit and push (auto-backup to shakhruz/nanoclaw-wiki kicks in).

**Do NOT ingest stories below top-5** — that creates noise in the wiki. Only the most important daily stories should become persistent knowledge.

### Step 9: Archive

Save full digest to:
```
/workspace/group/ai-news/YYYY-MM-DD/digest.md
/workspace/group/ai-news/YYYY-MM-DD/raw-posts.json
/workspace/group/ai-news/YYYY-MM-DD/scored-stories.json
```

Also update wiki log:
```
wiki/log.md
## [YYYY-MM-DD] digest | AI news briefing (K stories, top: <headline>)
```

## Schedule Setup

Two scheduled tasks — daily morning + weekly Sunday meta-digest.

### Daily morning digest

```
prompt: "Run AI news digest. Read ai-news-digest skill. Process last 24h of NEWS folder channels via Telegram Scanner. Deliver morning briefing to chat. Ingest top-5 stories to wiki/sources/. Archive in /workspace/group/ai-news/. Skip delivery if quiet day."
schedule_type: cron
schedule_value: "0 8 * * *"   # 8:00 Tashkent daily
context_mode: group
```

### Weekly meta-digest (Sunday evening)

```
prompt: "Run weekly AI meta-digest. Read ai-news-digest skill (Weekly Meta section). Synthesize last 7 days of digests. Deliver to chat Sunday 19:00 Tashkent."
schedule_type: cron
schedule_value: "0 19 * * 0"   # Sunday 19:00 Tashkent
context_mode: group
```

## Weekly Meta-Digest (Sunday 19:00)

The weekly digest is a higher-level synthesis — not a sum of daily digests, but a narrative arc of the week.

### Input

Read last 7 daily digests from `/workspace/group/ai-news/YYYY-MM-DD/digest.md` and their scored-stories.json.

### Output structure

```markdown
# Твоя неделя в AI: <DD-DD Month>

*Просканировано за неделю: N каналов × 7 дней = M постов | Отобрано в digests: K историй*

## 🎯 Главные темы недели

### 1. <Topic headline>
<2-3 sentences: what happened, why it mattered, how it evolved through the week>
📅 Пик: <date> | Освещение: X дней подряд
🔗 Ключевые истории: [link1], [link2]
💡 **Итог:** <takeaway for Shakhruz>

### 2. <Topic headline>
...

## 📊 Статистика недели

- Самый активный канал: @X (Y постов, Z вошли в digests)
- Самая обсуждаемая тема: <topic> — освещено N раз
- Новые темы на радаре: <emerging trends>

## 🏆 Топ-каналы по релевантности

| Канал | Релевантных историй | Комментарий |
|-------|--------------------|-----|
| @ch1 | 8 | Стабильно качественный сигнал |
| @ch2 | 5 | Хорош для Launch-новостей |
| @ch3 | 3 | Больше шума, но иногда важное |

## 💾 Что пошло в wiki

<list of top-5 stories ingested this week, with wiki links>

## 🔮 Что следить на следующей неделе

- <upcoming events, expected announcements>
- <topics that need watching>

## 🎯 Рекомендации по контенту

<suggestions for content plan based on week's themes — what to post on OctaFunnel, what clients are asking about>
```

### Algorithm

1. Aggregate all stories from 7 days
2. Cluster similar stories across days → topic threads
3. Rank topic threads by: total coverage × avg relevance × recency weight
4. Identify evolution: which topics grew, shrank, emerged, died
5. Extract channel performance: which channels provided most signal
6. Generate content recommendations based on what Shakhruz's target audience (ad-research channels) is talking about

Save to `/workspace/group/ai-news/weekly/YYYY-WW.md` (week number).

## On-demand mode

If user says "новости" or "сводка" during the day:
- If morning digest already exists (< 6 hours old) → send link/summary to archived digest
- If > 6 hours old → generate fresh "update" digest (only NEW posts since last run)
- Mark update digests clearly: "*Обновление с утренней сводки*"

## Personal Relevance Database

Maintain a file `/workspace/group/ai-news/relevance-topics.md`:

```markdown
# Темы высокой важности для Шахруза

## Критично (+10)
- Claude, Anthropic, claude-code
- OctaFunnel, OCTO, NanoClaw, Mila
- Любые новости от Denis Kozionov

## Высоко (+7 to +8)
- Telegram Ads, Telegram Bot API
- Sales funnels automation
- AI agents, agent frameworks (LangChain, AutoGPT, etc.)
- RAG, knowledge bases, second brain systems

## Интересно (+5 to +6)
- Узбекистан tech market
- Инфобизнес, онлайн-образование
- ЦА нашей рекламы (предприниматели, маркетологи)

## Общее (+3)
- AI research papers
- Industry news
- Model releases

## Игнорировать (0)
- Celebrity AI drama
- Политика без AI-контекста
- Крипто-хайп без конкретики
```

Update this file when Shakhruz's interests shift (new project, new client, etc.).

## Quality Control

After generating a digest, validate:

1. **Every story has a real t.me link** — verify via agent-browser if uncertain
2. **No duplicate stories** — same news shouldn't appear twice
3. **Briefing is scannable** — user should get value in 2 minutes of reading
4. **Personal relevance is explained** — not just "this is important"
5. **Character budget respected** — primary message ≤ 4000 chars

If a day has nothing important (rare), send a minimal digest:
```
Сегодня спокойно в AI — ничего критичного.
Мелкое: <1-2 notable items>
```

Better to send "nothing happened" than to fabricate importance.

## Anti-patterns

- ❌ Raw list of all posts (that's a feed reader, not a digest)
- ❌ Generic "AI продолжает развиваться" summaries
- ❌ Including story without verifying it exists (hallucinated channels)
- ❌ Personal relevance without specific connection ("может быть полезно для бизнеса")
- ❌ Missing links (can't verify → can't trust)
- ❌ Same story repeated because it was in 3 channels

## Evolution

Weekly review (Sundays):
- Which stories did Shakhruz react to / save / share?
- Which channels consistently deliver value vs noise?
- Are any topics trending that should be added to relevance DB?
- Should any channels be removed from NEWS folder?

Send weekly meta-report: "Твоя неделя в AI: топ-5 тем, которые ты сохранил. Каналы-лидеры: ..."
