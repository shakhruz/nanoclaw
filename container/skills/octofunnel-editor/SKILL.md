---
name: octofunnel-editor
description: Modify OctoFunnel funnels — edit pages, replace content, update testimonials, change images, manage stages. Works with any OctoFunnel server and funnel. Use when asked to edit a funnel, update landing page content, replace testimonials, or modify funnel structure.
---

# OctoFunnel Funnel Editor

Edit funnels on any OctoFunnel server through ОКТО AI chat or direct page editor. Universal — works with different servers and funnels.

## Trigger

"отредактируй воронку", "замени отзыв", "обнови лендинг", "измени текст на странице", "edit funnel"

## Prerequisites

- `agent-browser` with saved CRM auth (`/workspace/group/crm-auth.json`)
- Funnel ID and server URL (ask user if not provided)

## Known Servers

| Server | URL | Auth |
|--------|-----|------|
| AshotAI | https://ashotai.uz/crm | `/workspace/group/crm-auth.json` |

Read additional servers from `/workspace/group/config.json` (octofunnel section) if available.

## Editing Methods

### Method 1: Via ОКТО AI Chat (recommended)

ОКТО understands natural language commands and can modify funnel blocks directly.

```bash
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "<SERVER_URL>/?page=aih"
agent-browser wait --timeout 5000
```

Find the chat for the target funnel (each ОКТО chat is bound to a funnel). If no chat exists — start new one.

**Send edit commands via chat input:**
```bash
agent-browser snapshot -i
# Find the chat input field
agent-browser fill @<input-ref> "<EDIT COMMAND>"
agent-browser click @<send-button>
agent-browser wait --timeout 10000
```

**Edit command examples:**
- "Замени отзыв Виталия Тарасюка на: [новый текст отзыва]"
- "Измени заголовок на странице Урок 1 на: [новый заголовок]"
- "Замени изображение баннера на странице входа"
- "Добавь новый блок с текстом после второго блока"
- "Удали блок с отзывом на странице Урок 3"

ОКТО подтверждает: "Воронка изменена!" + кнопка для просмотра.

### Method 2: Direct Page Editor (for precise control)

```bash
agent-browser open "<SERVER_URL>/?journey=<FUNNEL_ID>"
agent-browser wait --timeout 5000
agent-browser screenshot $WD/before-edit.png
```

Navigate to specific stage/page, find the block to edit via snapshot, click to edit, modify content.

## Workflow

### Phase 1: Understand the Task

Determine:
- **Server URL** (default: ashotai.uz/crm)
- **Funnel ID** (e.g. 16 for AI Business)
- **What to change** (text, image, testimonial, structure)
- **New content** (from wiki, user input, or generated)

### Phase 2: Read Current State

```bash
export WD=/workspace/group/funnel-edits/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
```

Screenshot the current page/block before editing:
```bash
agent-browser open "<SERVER_URL>/?journey=<FUNNEL_ID>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/before.png
```

### Phase 3: Apply Edit

Use Method 1 (ОКТО chat) or Method 2 (direct editor). After edit:

```bash
agent-browser screenshot --full $WD/after.png
```

Send both before/after to user via `send_file` for confirmation.

### Phase 4: Verify

Open the public funnel URL and screenshot the live page:
```bash
agent-browser open "<PUBLIC_FUNNEL_URL>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/live-verify.png
```

Send to user: "Изменение применено. Вот как выглядит на живом сайте:"

### Phase 5: Log to Wiki

Append to `wiki/log.md`:
```
## [YYYY-MM-DD] edit | Funnel #<ID>: <what was changed>
```

## Content Sources for Edits

When replacing content, check wiki first:
- `wiki/sources/*testimonial*` — testimonials/case studies
- `wiki/entities/brand-ashotai.md` — brand voice, colors
- `wiki/entities/<client>.md` — client data for case study blocks
- `wiki/media/instagram/<client>/catalog.md` — photos for banners

## Safety

- **Screenshot before AND after** every edit
- **Show user the change** before confirming it's final
- **Never delete entire stages** without explicit confirmation
- **Keep backup** — ОКТО has undo, but screenshots are insurance
