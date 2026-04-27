---
name: octofunnel-editor
description: Edit existing OctoFunnel funnels — replace content, update testimonials, change images, batch modifications. Works with any OctoFunnel server. Use when asked to edit a funnel, update landing page content, replace testimonials, or modify funnel elements.
---

# OctoFunnel Funnel Editor

Edit **existing** funnels on any OctoFunnel server. For creating new funnels, use octofunnel-creator.

## Trigger

"отредактируй воронку", "замени отзыв", "обнови лендинг", "измени текст", "edit funnel", "замени все X на Y"

## Prerequisites

- `agent-browser` + CRM auth (`/workspace/group/*-auth.json`)
- Funnel ID or name (ask user if not provided)

## Known Servers

Read from `/workspace/group/config.json` (octofunnel.crm_url). Default: `https://ashotai.uz/crm`

## Workflow

### Phase 1: Select Funnel

```bash
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "<SERVER_URL>/?page=jf"
agent-browser wait --timeout 5000
agent-browser snapshot -i
```

List available funnels from snapshot. Find target funnel by ID or name. Click to open its editor OR find its ОКТО chat.

### Phase 2: Screenshot Current State

```bash
export WD=/workspace/group/funnel-edits/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
agent-browser open "<SERVER_URL>/?journey=<FUNNEL_ID>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/before.png
```

### Phase 3: Apply Edit via ОКТО Chat

Navigate to ОКТО: `<SERVER_URL>/?page=aih`. Find the chat bound to this funnel (each chat = one funnel). If multiple chats exist, find by funnel name in chat history.

```bash
agent-browser snapshot -i
agent-browser fill @<input-ref> "<EDIT COMMAND>"
agent-browser click @<send-button>
agent-browser wait --timeout 15000
```

**Verify loop** — after ОКТО responds:
1. `agent-browser snapshot` — read ОКТО's response
2. If "Воронка изменена!" → proceed to Phase 4
3. If ОКТО asks clarification → provide it, repeat
4. If ОКТО changed wrong block → say "Нет, я имел в виду [уточнение]", repeat
5. Max 3 retries, then report issue to user

### Phase 4: Upload Images (when needed)

To replace a banner/photo with a specific image from wiki/media:

**Option A — via ОКТО chat:**
Tell ОКТО: "Я хочу изменить картинки для референса в моей воронке" → ОКТО opens upload interface → use agent-browser to upload.

**Option B — via direct editor:**
```bash
agent-browser open "<SERVER_URL>/?journey=<FUNNEL_ID>"
# Navigate to the page with the image block
agent-browser snapshot -i
# Click the image block → find upload button
agent-browser click @<image-block>
agent-browser wait --timeout 3000
agent-browser upload @<file-input> "<PATH_TO_IMAGE>"
```

Image sources from wiki:
- `wiki/media/instagram/<client>/author/` — author portraits
- `wiki/media/instagram/<client>/products/` — product photos
- `wiki/media/youtube/<channel>/thumbnails/` — video thumbnails

### Phase 5: Batch Modifications

For replacing content across ALL pages/stages:

Tell ОКТО explicitly: "Найди ВСЕ упоминания '[OLD TEXT]' во всех страницах воронки и замени на '[NEW TEXT]'"

If ОКТО doesn't support batch → iterate manually:
1. List all stages/pages in the funnel
2. For each page: check if contains target text
3. Edit one by one, verify each

### Phase 6: Verify Live

Screenshot after edit:
```bash
agent-browser open "<SERVER_URL>/?journey=<FUNNEL_ID>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/after.png
```

Send before/after via `send_file`. If public URL available — screenshot live page too.

### Phase 7: Log

Append to `wiki/log.md`: `## [YYYY-MM-DD] edit | Funnel #<ID>: <description>`

## Content Sources

Check wiki first when replacing content:
- `wiki/sources/*testimonial*` — testimonials
- `wiki/entities/brand-ashotai.md` — brand voice
- `wiki/entities/<client>.md` — client data
- `wiki/media/` — photos and screenshots

## Safety

- Screenshot before AND after every edit
- Show user the change before confirming
- Never delete entire stages without explicit confirmation
- Verify loop: check ОКТО executed correctly after each command
