---
name: octofunnel-explorer
description: Systematically explore the OctoFunnel admin panel (ashotai.uz/crm) to document all platform capabilities, UI elements, and configuration options. Use when asked to explore, document, or understand the OctoFunnel platform.
---

# OctoFunnel Platform Explorer

Systematically explore and document the OctoFunnel admin panel at `ashotai.uz/crm`. Screenshot every page, document all UI elements, and save structured knowledge to the wiki for use by other skills (funnel-strategist, instagram-expert).

## Trigger

When user asks to:
- Explore or document OctoFunnel
- Understand what OctoFunnel can do
- "изучи октофаннел", "explore octofunnel", "что умеет октофаннел"
- "документируй CRM", "обзор платформы"
- When funnel-strategist needs platform data that doesn't exist yet

## Prerequisites

- `$OPENROUTER_API_KEY` — OpenRouter API key (container env var)
- `agent-browser` — browser automation tool
- Auth session: `/workspace/group/crm-auth.json` (CRM login credentials)

## Workflow

### Phase 0: Auth Setup

```bash
export WD=/workspace/group/octofunnel-exploration
mkdir -p $WD/{screenshots,pages}
```

Load CRM auth session:
```bash
for f in /workspace/group/*-auth.json; do
  [ -f "$f" ] && agent-browser state load "$f" && echo "Loaded: $f"
done
```

Navigate to CRM and verify login:
```bash
agent-browser open "https://ashotai.uz/crm"
agent-browser wait --load networkidle
agent-browser wait 2000
agent-browser screenshot $WD/screenshots/00-initial-load.png
agent-browser get url
```

If redirected to login page:
```bash
# Check for saved credentials
agent-browser snapshot -i
# Fill login form using snapshot refs
agent-browser fill @e<email> "<email>"
agent-browser fill @e<password> "<password>"
agent-browser click @e<submit>
agent-browser wait --load networkidle
agent-browser wait 2000
# Save auth state for future use
agent-browser state save /workspace/group/crm-auth.json
```

Send progress: "Вошел в OctoFunnel. Начинаю исследование платформы..."

### Phase 1: Dashboard Overview

```bash
agent-browser screenshot --full $WD/screenshots/01-dashboard-full.png
agent-browser snapshot -i > $WD/pages/dashboard-interactive.txt
agent-browser snapshot > $WD/pages/dashboard-full.txt
```

Document:
- Dashboard widgets and metrics displayed
- Navigation structure (sidebar, top menu)
- User role and permissions visible
- Quick action buttons
- Notification/alert areas

**Extract navigation map:**
From the snapshot, identify all main navigation items and their URLs. Build a sitemap:
```json
{
  "navigation": [
    {"label":"","url":"","icon":"","hasSubmenu":false,"submenuItems":[]}
  ]
}
```

Save to `$WD/navigation-map.json`.

### Phase 2: Systematic Page Crawl

Visit each section in priority order. For every page:

1. Navigate to the page
2. Wait for full load
3. Take full-page screenshot
4. Take above-fold screenshot
5. Get interactive elements snapshot
6. Get full accessibility tree
7. Extract all text content
8. Note all buttons, forms, dropdowns, toggles

**Priority order:**

#### Priority 1: Funnels Section
```bash
# Navigate to funnels
agent-browser open "https://ashotai.uz/crm/funnels"  # adjust URL based on nav map
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/02-funnels-list.png
agent-browser snapshot -i > $WD/pages/funnels-list.txt
```

Document:
- Funnel list view (how many funnels exist, their names, statuses)
- Funnel creation flow (click "Create" button, document each step)
- Funnel types available
- Funnel templates if any
- Funnel settings and configuration options

#### Priority 2: Okto AI Section
```bash
agent-browser open "https://ashotai.uz/crm/okto"  # adjust URL
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/03-okto-ai.png
agent-browser snapshot -i > $WD/pages/okto-ai.txt
```

Document:
- AI agent configuration options
- Prompt/instruction settings
- Knowledge base integration
- Conversation handling rules
- Channel connections
- Analytics on AI conversations

#### Priority 3: Courses Section
```bash
agent-browser open "https://ashotai.uz/crm/courses"  # adjust URL
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/04-courses.png
agent-browser snapshot -i > $WD/pages/courses.txt
```

Document:
- Course builder interface
- Lesson types (video, text, quiz, assignment)
- Drip content settings
- Student management
- Progress tracking
- Certificate generation

#### Priority 4: Clients / CRM Section
```bash
agent-browser open "https://ashotai.uz/crm/clients"  # adjust URL
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/05-clients.png
agent-browser snapshot -i > $WD/pages/clients.txt
```

Document:
- Contact list view and filters
- Contact detail page (fields, tags, notes)
- Segmentation capabilities
- Import/export options
- Communication history

#### Priority 5: Analytics Section
```bash
agent-browser open "https://ashotai.uz/crm/analytics"  # adjust URL
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/06-analytics.png
agent-browser snapshot -i > $WD/pages/analytics.txt
```

Document:
- Dashboard metrics and charts
- Funnel analytics (conversion rates, drop-off)
- Revenue tracking
- Traffic sources
- Date range filters
- Export capabilities

#### Priority 6: Messaging / Channels Section
```bash
agent-browser open "https://ashotai.uz/crm/messaging"  # adjust URL
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/07-messaging.png
agent-browser snapshot -i > $WD/pages/messaging.txt
```

Document:
- Connected channels (Telegram, Instagram, WhatsApp, VK, MAX)
- Channel configuration for each
- Broadcast / mass messaging
- Message templates
- Auto-response rules

#### Priority 7: Settings Section
```bash
agent-browser open "https://ashotai.uz/crm/settings"  # adjust URL
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/08-settings.png
agent-browser snapshot -i > $WD/pages/settings.txt
```

Document:
- Account settings
- Payment processor connections (lava.top, Click.uz, Payme.uz)
- Domain settings
- API keys / webhooks
- Team members / roles
- Notification preferences
- Branding / white-label options

### Phase 3: Deep-Dive — Funnel Editor

This is the most important section. Explore the funnel builder in depth:

```bash
# Open an existing funnel or create a test funnel
agent-browser snapshot -i  # Find "Create funnel" or existing funnel to edit
agent-browser click @e<funnel-item>
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/10-funnel-editor.png
```

Document the funnel editor:
- **Canvas/builder type** — visual drag-and-drop? Step-by-step wizard? Linear editor?
- **Available block types:**
  - Message blocks (text, image, video, file)
  - Input blocks (buttons, quick replies, forms, payments)
  - Logic blocks (conditions, delays, A/B split, tags)
  - Integration blocks (webhooks, API calls, CRM actions)
- **Trigger types** — what starts a funnel (keyword, button, link, schedule, API)
- **Branching logic** — how conditional paths work
- **Templates** — pre-built funnel templates available
- **Preview/test mode** — how to test a funnel before publishing
- **Publishing flow** — how funnels go live
- **Analytics per block** — conversion data at each step

Screenshot each block type's configuration panel:
```bash
# For each block type found
agent-browser click @e<block>
agent-browser wait 1000
agent-browser screenshot $WD/screenshots/10-funnel-block-<type>.png
agent-browser snapshot -i > $WD/pages/funnel-block-<type>.txt
```

### Phase 4: Deep-Dive — Okto AI

Explore the AI agent configuration thoroughly:

```bash
agent-browser open "https://ashotai.uz/crm/okto"  # adjust URL
agent-browser wait --load networkidle
```

Document:
- **AI model settings** — which AI models available, temperature, context length
- **System prompt / instructions** — where to configure AI behavior
- **Knowledge base** — how to add documents, FAQs, product info
- **Conversation flow** — how AI handles different intents
- **Handoff rules** — when AI transfers to human
- **Training / fine-tuning** — any learning from conversations
- **Channel integration** — which channels Okto can respond in
- **Action capabilities** — can Okto trigger funnels, tag contacts, process payments?
- **Analytics** — conversation metrics, satisfaction scores

Screenshot each configuration panel:
```bash
agent-browser screenshot $WD/screenshots/11-okto-<section>.png
```

### Phase 5: Visual Analysis

For key screenshots, run OpenRouter vision analysis:

```bash
B64=$(base64 -i $WD/screenshots/<filename>.png)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Analyze this CRM/funnel platform screenshot. Describe:\n1) What section of the platform is this?\n2) All visible UI elements (buttons, forms, toggles, lists)\n3) Data shown (metrics, counts, statuses)\n4) Configuration options available\n5) Any notable features or limitations visible\nBe thorough — this is for platform documentation."}]}]}'
```

Run vision analysis on:
- Dashboard (overall platform capabilities)
- Funnel editor (builder interface and block types)
- Okto AI configuration (AI capabilities)
- Settings / Payment processors (integration options)

### Phase 6: Save to Wiki

**6a. Create comprehensive wiki entity page:**

```bash
cat > /workspace/group/wiki/entities/octofunnel-platform.md << 'WIKI_EOF'
---
title: "OctoFunnel Platform"
type: entity
subtype: platform
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: []
tags: [octofunnel, crm, funnels, automation, platform]
confidence: high
---

# OctoFunnel Platform Documentation

## Overview
<Platform description based on exploration>

## Navigation Structure
<Full sitemap with URLs>

## Funnels
### Funnel Types
### Funnel Editor
### Block Types
### Triggers
### Templates

## Okto AI Agent
### Configuration
### Knowledge Base
### Capabilities
### Limitations

## Courses
### Builder
### Lesson Types
### Student Management

## Client CRM
### Contact Management
### Segmentation
### Tags

## Channels
### Connected Channels
### Channel Configuration
### Broadcasting

## Analytics
### Dashboard Metrics
### Funnel Analytics
### Revenue Tracking

## Payments
### lava.top
### Click.uz
### Payme.uz

## Settings
### Account
### API / Webhooks
### Team Management

## Key Capabilities Summary
<Bullet list of what can and cannot be done>

## Recommendations for Funnel Building
<Based on what was discovered about the platform's strengths>
WIKI_EOF
```

**6b. Create media catalog:**

```bash
MEDIA_DIR=/workspace/group/wiki/media/octofunnel
mkdir -p $MEDIA_DIR/screenshots
cp $WD/screenshots/* $MEDIA_DIR/screenshots/ 2>/dev/null

cat > $MEDIA_DIR/catalog.md << 'CAT_EOF'
---
title: "Media Catalog — OctoFunnel Platform"
type: media-catalog
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: screenshot
total_images: N
tags: [octofunnel, platform, documentation]
confidence: high
---

# OctoFunnel Platform Screenshots

| File | Section | Description | Key Elements |
|------|---------|-------------|--------------|
| 01-dashboard-full.png | Dashboard | Main dashboard view | ... |
| 02-funnels-list.png | Funnels | Funnel list view | ... |
| ... | ... | ... | ... |
CAT_EOF
```

**6c. Save structured exploration data:**

```bash
cat > $WD/exploration-data.json << 'DATA_EOF'
{
  "platform": "OctoFunnel",
  "url": "https://ashotai.uz/crm",
  "exploredAt": "YYYY-MM-DD",
  "navigation": [],
  "sections": {
    "funnels": {"url":"","features":[],"blockTypes":[],"templates":[]},
    "oktoAI": {"url":"","capabilities":[],"limitations":[]},
    "courses": {"url":"","features":[]},
    "clients": {"url":"","features":[]},
    "analytics": {"url":"","metrics":[]},
    "messaging": {"url":"","channels":[]},
    "settings": {"url":"","paymentProcessors":[],"integrations":[]}
  },
  "screenshots": []
}
DATA_EOF
```

**6d. Update wiki index, log, media-index.json:**

```bash
# Update log
cat >> /workspace/group/wiki/log.md << 'LOG_EOF'

## [YYYY-MM-DD] ingest | OctoFunnel platform exploration
- Pages created: entities/octofunnel-platform.md, media/octofunnel/catalog.md
- Pages updated: index.md
- Notes: Full platform exploration with N screenshots
LOG_EOF

# Git commit
cd /workspace/group/wiki && git add -A && git commit -m "ingest: octofunnel platform exploration"
```

### Phase 7: Report to User

Send a structured summary via `send_message`:

1. **Platform overview** — what OctoFunnel is and what was discovered
2. **Key capabilities** — most important features found
3. **Funnel builder** — what types of funnels can be built, block types available
4. **Okto AI** — AI agent capabilities and configuration options
5. **Channels** — which messaging channels are supported
6. **Payments** — payment processors and how they integrate
7. **Notable findings** — anything unexpected or particularly useful
8. **Limitations** — what the platform cannot do or does poorly

Send 3-5 key screenshots via `send_file` showing the most important UI areas.

## Exploration Principles

- **Screenshot everything.** Every page, every modal, every settings panel. More screenshots = better documentation for future reference.
- **Document all UI elements.** Buttons, dropdowns, toggles, forms — document what each does even if you can't test it without affecting live data.
- **Don't modify live data.** Explore read-only. Don't publish funnels, send messages, or change settings unless explicitly asked to.
- **Note URLs.** Save the actual URL for each section so future navigation is direct.
- **Check for updates.** If `wiki/entities/octofunnel-platform.md` already exists, read it first and focus on sections that are missing or marked as incomplete.

## Error Handling

- **Login fails / session expired:** Ask user for credentials, re-authenticate, save new auth state
- **Page not found:** Platform may have been updated. Explore from dashboard navigation instead
- **Loading errors:** Wait longer, retry once. Some pages are SPA with heavy JS
- **Access denied on certain pages:** Note the restriction, move on to next section
- **Platform in maintenance:** Report to user, retry later
- **UI language mismatch:** Platform may be in Russian or Uzbek. Document in the language shown, translate key terms

## Cost

~$0.10-0.25 per exploration: OpenRouter vision for screenshot analysis only. No external API costs.
