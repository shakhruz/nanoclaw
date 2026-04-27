---
name: octofunnel-explorer
description: Systematically explore the OctoFunnel admin panel (ashotai.uz/crm) to document all platform capabilities. Use when asked to explore, document, or understand the OctoFunnel platform.
---

# OctoFunnel Platform Explorer

Explore and document the OctoFunnel admin panel. Screenshot every page, document UI elements, save to wiki.

## Trigger

"изучи октофаннел", "explore octofunnel", "документируй CRM", "обзор платформы"

## Prerequisites

- `$OPENROUTER_API_KEY`, `agent-browser`, `/workspace/group/crm-auth.json`

## Page Crawl Pattern

For EVERY page visited, follow this exact pattern:
```bash
agent-browser open "<URL>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/screenshots/<NN>-<section>.png
agent-browser snapshot -i > $WD/pages/<section>.txt
```
Document: purpose, key UI elements, buttons/forms, sub-pages/tabs.

## Workflow

### Phase 0: Auth & Setup

```bash
export WD=/workspace/group/octofunnel-exploration
mkdir -p $WD/{screenshots,pages}
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "https://ashotai.uz/crm"
agent-browser wait --timeout 5000
```
If login page → fill credentials, submit, save: `agent-browser state save /workspace/group/crm-auth.json`

### Phase 1: Dashboard + Navigation Map

Screenshot dashboard. Extract ALL navigation items from snapshot → save to `$WD/navigation-map.json`:
```json
{"navigation": [{"label":"","url":"","hasSubmenu":false}]}
```

### Phase 2: Crawl All Sections (priority order)

Visit each section using the Page Crawl Pattern above.

**Priority 1 — Funnels:** List view, creation flow, funnel types, templates, settings. Open existing funnel (#16 "AI Business") to study editor.

**Priority 2 — Okto AI:** Configuration, system prompt, knowledge base, channel connections, conversation history, capabilities.

**Priority 3 — Courses:** Builder, lesson types, student management, progress tracking.

**Priority 4 — Clients/CRM:** Contact list, filters, detail page, tags, segments, communication history.

**Priority 5 — Analytics:** Metrics, funnel conversion, revenue, traffic sources, date filters, export.

**Priority 6 — Messaging/Channels:** Connected channels (Telegram, IG, WhatsApp, VK, MAX), broadcasts, templates, auto-replies.

**Priority 7 — Settings:** Account, payments (lava.top, Click.uz, Payme.uz), domain, API, team, branding.

### Phase 3: Deep-Dive — Funnel Editor

The most important section. Open existing funnel editor:
- **Canvas type** — drag-and-drop? wizard? linear?
- **Block types:** message (text/image/video), input (buttons/forms/payments), logic (conditions/delays/splits), integrations
- **Triggers** — keyword, button, link, schedule, API
- **Templates** — pre-built funnels
- **Preview/test** — how to test before publishing
- **Per-block analytics** — conversion at each step

Screenshot each block type's config panel.

### Phase 4: Deep-Dive — Okto AI

- Model settings, system prompt, knowledge base
- Conversation flow, handoff rules
- Channel integration, action capabilities (tag contacts, trigger funnels, payments)

### Phase 5: Visual Analysis

For 5-8 key screenshots, run OpenRouter Gemini Flash:
```bash
B64=$(base64 -i $WD/screenshots/<file>.png)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Analyze this CRM screenshot. Describe: 1) Section 2) All UI elements 3) Data shown 4) Configuration options 5) Notable features"}]}]}'
```

### Phase 6: Save to Wiki

Create `wiki/entities/octofunnel-platform.md` with sections: Overview, Navigation, Funnels (types, editor, blocks, triggers), Okto AI, Courses, CRM, Channels, Analytics, Payments, Settings, Key Capabilities, Limitations.

Copy screenshots to `wiki/media/octofunnel/screenshots/`, create `catalog.md`.
Update index + log + git commit.

### Phase 7: Report

Send summary: platform overview, key capabilities, funnel builder, Okto AI, channels, payments, limitations. Send 3-5 key screenshots via `send_file`.

## Rules

- **Don't modify live data.** Read-only exploration. Don't publish funnels or send messages.
- **Note URLs** for each section → direct navigation later.
- **If page already documented** in wiki → focus on missing/incomplete sections.

## Cost

~$0.05-0.15: OpenRouter vision for 5-8 screenshots.
