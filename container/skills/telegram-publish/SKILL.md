---
name: telegram-publish
description: Publish posts to Telegram via the @ashot_ashirov_ai userbot using post-moderation flow (Mila schedules +1h, Shakhruz reviews and approves/edits/cancels before subscribers see). Also: stories, channel-stories, pin/forward, subscribe, DMs, scheduled-message management. Bash+curl+jq does MCP-handshake to telegram-scanner on host (port 3002).
---

# Telegram Publish (skill-based MCP bridge)

Self-contained skill that talks to the host's `telegram-scanner` MCP server via the official streamable-HTTP MCP protocol — but without needing `mcp__telegram-scanner__*` tools wired into the agent SDK. Pure bash + curl + jq, runs anywhere.

## 🔑 Post-moderation flow (default behavior)

**ВСЕГДА ставь scheduled с задержкой +1 час** (или другой интервал по запросу), не публикуй сразу. Подписчики не должны видеть пост до того, как Шахруз его подтвердил. После постановки — отчитайся в DM Шахрузу с превью и инструкцией:

```
🕐 Поставила пост в @ashotonline на 16:30 (через 1 час).
scheduled_id: 142

Превью:
[первые 200 символов поста]

Команды (просто пиши обычным языком — я разберу):
• «опубликуй сейчас» — досрочный выход
• «передвинь на 18:00» — изменить время
• «замени X на Y» — поправить текст
• «удали» — отменить публикацию
• ничего не пиши — выйдет автоматически в 16:30
```

Когда Шахруз даёт команду — используй соответствующий subcommand (`publish_now`, `reschedule`, `edit_sched`, `cancel`).

**Никаких исключений в режиме «начни публикацию» Mila не делает.** Default всегда `--schedule=+1h`. Единственный сценарий immediate — это когда ты при post-moderation сказал «опубликуй сейчас» уже поставленный scheduled. Тогда Mila вызывает `publish_now <channel> <scheduled_id>`, а не пере-публикует с `--immediate`.

Замечание по реакциям: эмодзи-реакции на сообщения (👀, 👏, ❤) — **отдельный механизм** через `mcp__nanoclaw__add_reaction` в core, не через этот скилл. Реакции всегда мгновенные, post-moderation flow к ним не применяется.

## Why this exists

`telegram-scanner` is an HTTP MCP on `host.containers.internal:3002`. NanoClaw v2's `container.json.mcpServers` field currently supports only stdio MCP. Until that gap is closed, this skill provides a working publishing path through the same scanner — and also serves as a reference implementation for any future skill that needs to call HTTP MCP servers from inside a container.

## When to use

- Publishing to `@ashotonline` (or any channel where the userbot is admin)
- Daily AI digests (`ai-news-digest` skill should call us)
- Reality-line posts, case studies, tutorials, offers
- Channel-stories (Telegram channel-stories feature)
- DMs from the userbot for testing funnels or lead-gen
- Pinning announcements, forwarding cross-channel content

For decisions about when to use the userbot vs the official @mila_gpt_bot, see the contract doc at `mila-nanoclaw/docs/telegram-userbot-vs-bot.md`.

## Quick reference

All commands run from inside the container. Outputs are short text or JSON depending on the underlying scanner tool.

```bash
SKILL=/app/skills/telegram-publish

# 1) Publish a post — default scheduled +1h (post-moderation)
echo '🌅 *Заголовок*

Тело поста с одинарными *bold* и _italic_.' > /tmp/post.md
bash $SKILL/publish.sh post ashotonline /tmp/post.md
# → "Published to @ashotonline. https://t.me/c/.../123 (scheduled for 2026-05-02T15:00:00+00:00)"

# 1a) Custom schedule offset
bash $SKILL/publish.sh post ashotonline /tmp/post.md --schedule=+30m
bash $SKILL/publish.sh post ashotonline /tmp/post.md --schedule=+2h
bash $SKILL/publish.sh post ashotonline /tmp/post.md --schedule=2026-05-03T05:00:00Z

# 1b) Immediate publish (rare — only when user explicitly asks)
bash $SKILL/publish.sh post ashotonline /tmp/post.md --immediate

# 2) With image (still scheduled +1h by default)
bash $SKILL/publish.sh post ashotonline /tmp/post.md /workspace/global/banners/may-02.jpg

# 3) Channel story
bash $SKILL/publish.sh ch_story ashotonline /workspace/global/stories/digest.jpg "Свежий обзор недели"

# 4) Pin a published message
bash $SKILL/publish.sh pin @ashotonline 123

# 5) Forward
bash $SKILL/publish.sh forward @durov 99 me --drop-author

# 6) Subscribe userbot to a new channel
bash $SKILL/publish.sh subscribe @some_new_ai_channel

# 7) DM
bash $SKILL/publish.sh dm mila_gpt_bot "/start ads_42"

# 8) Health metrics
bash $SKILL/publish.sh metrics
```

## Post-moderation commands — управление scheduled очередью

```bash
# Show scheduled queue (что ждёт публикации)
bash $SKILL/publish.sh list_scheduled @ashotonline

# Publish now (досрочно, по команде «опубликуй сейчас»)
bash $SKILL/publish.sh publish_now @ashotonline 142

# Cancel (по команде «удали» / «отмени»)
bash $SKILL/publish.sh cancel @ashotonline 142

# Reschedule (по команде «передвинь на 18:00» — accepts ISO or +Nh/+Nm)
bash $SKILL/publish.sh reschedule @ashotonline 142 +2h
bash $SKILL/publish.sh reschedule @ashotonline 142 2026-05-02T18:00:00Z

# Edit text/image/time of a scheduled post (комбо-команда «замени X на Y»)
echo "новый текст с *выделением*" > /tmp/edit.md
bash $SKILL/publish.sh edit_sched @ashotonline 142 --text=/tmp/edit.md
bash $SKILL/publish.sh edit_sched @ashotonline 142 --image=/workspace/global/new-banner.jpg
bash $SKILL/publish.sh edit_sched @ashotonline 142 --text=/tmp/edit.md --at=+30m
```

## Anatomy

- `lib/mcp-call.sh` — handshake helper (initialize → notifications/initialized → tools/call). Probes Apple Container DNS first, falls back to Docker's, then localhost. Returns the tool's text content cleanly.
- `publish.sh` — high-level wrapper for the eight common operations above.
- For exotic operations, call `lib/mcp-call.sh <tool_name> '<args_json>'` directly. All 18 scanner tools are reachable.

## Markdown rules (Telegram)

- ✅ Single `*bold*`, `_italic_`, `` `code` ``, ` ``` блок ``` `, `[text](url)`
- ❌ Double `**bold**` — Telegram rejects.
- ❌ `## headings` — not supported in Telegram messages.
- ✅ Emoji headers like `🌅 *Заголовок*`.
- Length: ≤4096 chars text-only, ≤1024 chars caption when image attached.

## Image paths

- `/workspace/global/...` — auto-translated by scanner to host path `<repo>/groups/global/...`. **Preferred** for shared assets.
- `/workspace/group/...` — translated using `NANOCLAW_GROUP_FOLDER` env (default `telegram_main`). Works only if scanner runs with that env. Reliable but brittle.
- Absolute host path — works only when caller already knows host paths (rare).
- For container-local files that aren't in /workspace/global/ — best to copy to `/workspace/global/pub-staging/` first.

## Common content patterns (skill compositions)

### AI news digest

`ai-news-digest` builds the text, then:
```bash
bash $SKILL/publish.sh post ashotonline /workspace/group/ai-news/$(date +%F)/post.md \
  /workspace/global/banners/digest-template.jpg
```

### Channel-curator: subscribe + verify

```bash
bash $SKILL/publish.sh subscribe @new_tier1_channel
bash $SKILL/publish.sh metrics | jq '.tools.subscribe_to_channel'
```

### Pin episode announcement (ai-club-publisher)

```bash
RESP=$(bash $SKILL/publish.sh post ashotonline /tmp/episode.md /tmp/cover.jpg)
MSGID=$(echo "$RESP" | grep -oE '/[0-9]+$' | tr -d /)
bash $SKILL/publish.sh pin @ashotonline "$MSGID"
```

## Health & troubleshooting

- **`mcp_unreachable`** in output → `telegram-scanner` host service is down. Tell user: «scanner лежит, на mac запусти `launchctl print gui/$(id -u)/com.nanoclaw.telegram-scanner` и посмотри state».
- **Auth-related errors** (e.g. `Failed to publish: ChatWriteForbiddenError`) → userbot lost admin rights or session corrupted. User does `/telegram-ads-auth` (re-auth flow).
- **Markdown errors** → check for double-stars, headings, or unsupported syntax.
- **FloodWait** → Telethon will auto-sleep; if frequent, slow down the cadence.

## Future migration

When NanoClaw v2 supports HTTP MCP in `container.json` (extension of `McpServerConfig` to allow `{type:"http", url, headers}`), this skill becomes redundant — `mcp__telegram-scanner__publish_to_channel` etc. will be native tools. At that point:
1. Add `"telegram-scanner": {"type":"http","url":"http://host.containers.internal:3002/mcp"}` to relevant `container.json` files.
2. Replace `bash $SKILL/publish.sh` calls in dependent skills with `mcp__telegram-scanner__publish_to_channel(...)`.
3. Mark this skill `archived/`.

This skill is a bridge — once the bridge is no longer needed, retire it cleanly.

## Sharing

The skill folder (`SKILL.md` + `publish.sh` + `lib/mcp-call.sh`) is self-contained. To use elsewhere:
1. Copy folder to `<install>/container/skills/telegram-publish/`.
2. Ensure the destination has its own `telegram-scanner` instance running on the host (port 3002 by default; override with `MCP_URL` env var).
3. The userbot whose session lives in scanner becomes the publishing identity.
