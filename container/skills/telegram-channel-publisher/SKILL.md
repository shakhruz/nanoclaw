---
name: telegram-channel-publisher
description: Publish posts to Telegram channels and groups via @ashot_ashirov_ai userbot (Telegram Scanner MCP). Handles formatting, image attachment, and audience-specific surfaces (@ashotonline public channel, reality chat, partners chat). Use when delivering AI news digests, reality posts, case studies, tutorials, or offers.
---

# Telegram Channel Publisher

Orchestrates publishing to Telegram surfaces via the authenticated userbot. The userbot (`@ashot_ashirov_ai`) is admin in all target surfaces and can post directly.

## Trigger

- "опубликуй в канал", "post to channel", "опубликуй в ashotonline"
- Called by other skills (e.g., `ai-news-digest`) when public publishing is needed
- Scheduled tasks that produce publishable content

## Prerequisites

- `telegram-scanner` MCP running on port 3002 with new tools:
  - `mcp__telegram-scanner__publish_to_channel(channel, text, image_path, disable_notification)`
  - `mcp__telegram-scanner__publish_story(text, image_path)`
  - `mcp__telegram-scanner__get_channel_admins(channel)`
- Bot backup: if Telethon fails, fall back to Bot API via `@mila_gpt_bot` (also admin)
- Image files (optional) at known paths in `/workspace/group/`

## Target surfaces

| Surface | Username / JID | Purpose | Cadence |
|---------|----------------|---------|---------|
| Public channel | `@ashotonline` | Broad audience, reality + daily AI digest | multiple per day |
| Reality chat (private) | TBD (user provides JID) | Warm followers, deeper content | 3-5 per day |
| Partners chat | TBD (user provides JID) | Paying clients/partners | 2-4 per week |

## Publishing policy

**Auto-publish mode (current default).** Shakhruz moderates post-factum — can delete/edit any post. No pre-approval required.

**Exception:** If content mentions competitors by name, contains financial claims, or references clients without masking — pause and ask for approval via `send_message` before publishing.

## Formatting rules (Telegram Markdown)

Supported: `*bold*`, `_italic_`, `` `code` ``, ` ```блок``` `, `[text](url)`

**NEVER use double-star `**bold**`** — Telegram's Markdown rejects it (uses `*` only).

### Public channel post structure (ashotonline)

```
<emoji headline> *<Заголовок жирным>*

<Основной контент 2-4 короткими абзацами>

<Опционально: bullet list>
• Пункт 1
• Пункт 2

💭 <Личный тон Ашота: "что я думаю", "мой взгляд">

<Hashtags>
#<категория> #<тема>
```

### Reality chat post structure (deeper, rawer)

```
<Без эмодзи-заголовка, сразу в суть>

<Числа, сырые наблюдения, 3-5 предложений>

<Что я бы сделал иначе / открытый вопрос>
```

### Partners chat post structure (value + community)

```
*<Заголовок>* — <дата>

<Value-content: tutorial / case / news filter>

<Концентрат применимости: "для вас это значит...">

🔗 <Deep links к деталям если нужно>
```

## Typical workflow

### 1. Prepare content

Take input (digest, case study, reality note, etc.) and shape it per target surface structure.

### 2. Add image (optional but recommended for @ashotonline)

- For daily AI digest: generate preview image via OpenRouter image model
- For case studies: client photo or screenshot
- For tutorials: screenshot of result
- Save to `/workspace/group/content/YYYY-MM-DD-<slug>.jpg`

Daily digest image prompt template (run via `curl https://openrouter.ai/api/v1/chat/completions`):

```
"A clean, modern header graphic for an AI news digest. 
16:9 aspect ratio. Dark background (Telegram dark theme friendly).
Central element: <topic visual cue from top story>.
Text overlay: 'AI сводка — <DD month>'.
Style: minimalist, professional, blue/purple accent colors."
```

### 3. Publish

Call the right tool for the surface:

**Public channel (@ashotonline):**
```
mcp__telegram-scanner__publish_to_channel(
  channel="ashotonline",
  text="<formatted post>",
  image_path="/workspace/group/content/YYYY-MM-DD-digest.jpg"
)
```

**Reality chat / Partners chat** (both are private groups — use JID):

If chat is **registered in NanoClaw** as a group, use standard `send_message` IPC tool (faster).

If not registered, use Telethon via telegram-scanner:
```
mcp__telegram-scanner__publish_to_channel(
  channel="<numeric_chat_id or @username>",
  text="<formatted post>"
)
```

### 4. Archive

Save the published content to:
```
/workspace/group/content/YYYY-MM-DD/<surface>-<slug>.md
```

With frontmatter:
```yaml
---
date: YYYY-MM-DD
surface: ashotonline | reality-chat | partners-chat
type: digest | reality | tutorial | case | offer
post_url: https://t.me/...
image: path to image if used
---
```

### 5. Report to Shakhruz

After publishing, send brief confirmation to main chat:
```
📢 Опубликовала в @ashotonline: <title>
🔗 <post_url>
```

## Fallback: Bot API via @mila_gpt_bot

If Telethon userbot fails (rare — session issue, rate limit):
1. Log error
2. Try via standard Bot API — @mila_gpt_bot is admin too
3. Note: Bot API has different URL format and formatting constraints — may require reformatting text for MarkdownV2 escape rules

If both fail, save draft to `/workspace/group/content/failed/` and ping Shakhruz.

## Moderation flags (pause + ask)

Skip auto-publish and ask for approval when post contains:
- Competitor names (Denis Kozionov excepted — founder, not competitor)
- Unverified financial claims ("заработай $5000" without context)
- Client names or specific revenue numbers (mask them)
- Legal/medical/financial advice that could backfire

If unsure — default to asking.

## Related skills

- `ai-news-digest` — produces daily digest → this skill publishes it
- `content-planner` — plans what to post across surfaces
- `design-social-post` — generates preview images
- `telegram-scanner` — the underlying MCP server with publishing tools
