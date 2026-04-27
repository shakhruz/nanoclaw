---
name: plaud-gmail-watcher
description: Automatically import PLAUD.AI transcriptions from Gmail. Scheduled task that finds unread PLAUD emails, extracts transcriptions and attachments, saves to sources, triggers wiki ingest, and archives processed emails. Use to set up or manage the PLAUD auto-import pipeline.
---

# PLAUD Gmail Watcher

Automated pipeline: Gmail → extract → save → wiki ingest → archive.

## Setup

Create a scheduled task that runs periodically to check for new PLAUD emails.

### Schedule Task

```
prompt: |
  Check Gmail for new PLAUD.AI transcription emails and process them.

  1. Search: from:no-reply@plaud.ai is:unread
  2. If no results — exit silently (wrap in <internal> tags)
  3. For each email (process ONE at a time, oldest first):
     a. Read full email (body + attachments list)
     b. Save raw sources to /workspace/group/sources/plaud/YYYY-MM-DD-<slug>/
     c. Process via plaud-transcript skill (full wiki ingest)
     d. After successful ingest, mark email as read
     e. Report: "Импортировал запись PLAUD: <title> (<date>)"
  4. If more than 1 email found, process only the first and say how many remain

  IMPORTANT: Process ONE email per run. Multiple emails = multiple runs.
  This prevents context overflow on large transcripts.

schedule_type: cron
schedule_value: "0 */2 * * *"    # every 2 hours
context_mode: group
```

### Script Guard (optional, saves API calls)

Use a script to check Gmail before waking the agent:

```bash
# Script checks if there are unread PLAUD emails
# Requires Gmail API access from the container

RESULT=$(node --input-type=module -e "
  // Use the gmail MCP tool via IPC to check for unread PLAUD emails
  // If no tool access in script, use a simpler HTTP check
  console.log(JSON.stringify({ wakeAgent: true, data: { reason: 'periodic-check' } }));
")
echo "$RESULT"
```

Note: Since Gmail search requires MCP auth which scripts can't use directly, the simplest approach is to always wake the agent and let it exit early via `<internal>` tags when there are no emails. The agent invocation cost is minimal when it exits immediately.

## Processing Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌──────────┐
│ Gmail Search │────▶│ Read Email   │────▶│ Save to sources/ │────▶│ Wiki     │
│ PLAUD unread │     │ body + attach│     │ plaud/YYYY-MM-DD │     │ Ingest   │
└─────────────┘     └──────────────┘     └─────────────────┘     └──────────┘
                                                                       │
                                          ┌──────────────┐             │
                                          │ Mark Read    │◀────────────┘
                                          │ + Archive    │
                                          └──────────────┘
```

## Step-by-Step Processing

### 1. Search Gmail

```
mcp__gmail__search_messages(q: "from:no-reply@plaud.ai is:unread", maxResults: 5)
```

If no results → exit with `<internal>No PLAUD emails</internal>`.

### 2. Read Oldest Email First

```
mcp__gmail__read_message(messageId: <oldest message id>)
```

Extract:
- Subject → parse date and title from `[Plaud-AutoFlow] MM-DD <Title>`
- Body → full AI summary text
- Attachments list → note filenames and sizes

### 3. Save Raw Sources

Create directory and save files:

```bash
DATE="YYYY-MM-DD"  # from subject
SLUG="<kebab-case-title>"
DIR="/workspace/group/sources/plaud/${DATE}-${SLUG}"
mkdir -p "$DIR"
```

Save email body as `$DIR/summary.md` with frontmatter:
```markdown
---
source: plaud-email
date: YYYY-MM-DD
title: <from subject>
from: no-reply@plaud.ai
message_id: <gmail message id>
---

<email body>
```

For attachments: Gmail MCP may not support direct download. If attachments are available, save them. If not, the email body summary is sufficient — it contains the AI-processed content which is often more useful than raw transcript for wiki purposes.

### 4. Wiki Ingest

Follow the `plaud-transcript` skill pipeline:
- Create source-summary in `wiki/sources/`
- Update people, concepts, projects, entities
- Update index.md and log.md
- Git commit

### 5. Post-Processing Email

After successful ingest:

```
# Mark as read
mcp__gmail__modify_message(messageId: <id>, removeLabelIds: ["UNREAD"])

# Optional: add label for tracking
mcp__gmail__modify_message(messageId: <id>, addLabelIds: ["PLAUD-Processed"])
```

Note: If label "PLAUD-Processed" doesn't exist, create it first or skip labeling.
Archive from inbox is optional — some users prefer to keep processed emails visible.

### 6. Report

Send message to chat:
```
Импортировал запись PLAUD: <title>
Дата: <date> | Участники: <names>
Wiki: sources/YYYY-MM-DD-plaud-<slug>.md
Обновлено страниц: <N>
```

If more unread PLAUD emails remain:
```
Ещё <N> писем от PLAUD ждут обработки. Обработаю в следующем цикле.
```

## Email Identification

### Primary pattern
- From: `no-reply@plaud.ai`
- Subject starts with: `[Plaud-AutoFlow]`

### Fallback patterns (in case format changes)
- From contains: `plaud.ai`
- Subject contains: `Plaud` or `PLAUD`
- Body contains structured sections (Обзор, Ключевая Сводка, The Vibe)

## Error Handling

- **Gmail auth fails**: log error, retry next cycle
- **Email parse fails**: save raw email body to sources anyway, skip wiki ingest, don't mark as read
- **Wiki ingest fails**: save sources (they're preserved), don't mark as read, report error
- **Attachment download fails**: proceed with body-only ingest, note in source-summary that transcript attachment was unavailable

## Management Commands

User can say:
- "проверь почту PLAUD" → run immediately (don't wait for schedule)
- "покажи необработанные PLAUD" → search and list without processing
- "обработай PLAUD за <date>" → find specific email and process
- "останови импорт PLAUD" → pause the scheduled task
