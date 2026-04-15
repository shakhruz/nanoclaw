---
name: plaud-transcript
description: Process PLAUD.AI meeting transcriptions for wiki ingest. Parses structured summaries and raw transcripts, identifies speakers and action items, creates source-summaries and updates wiki pages. Use when processing PLAUD emails or when user shares a PLAUD transcript manually.
---

# PLAUD Transcript Processor

Process recordings from PLAUD.AI device — meeting transcriptions, consultations, brainstorms, casual conversations. Extract structured knowledge and ingest into the wiki second brain.

## Trigger

- Automated: called by plaud-gmail-watcher after extracting email
- Manual: user shares a PLAUD transcript or says "обработай запись PLAUD"

## Input Format

PLAUD emails arrive from `"PLAUD.AI" <no-reply@plaud.ai>` with subject `[Plaud-AutoFlow] MM-DD <Title>`.

### Email Body (AI-generated summary)

Structured sections — not all are always present:
- **Обзор / Overview** — high-level summary
- **Справочная информация** — background context
- **Болевые точки** — pain points discussed
- **Ожидания** — expectations and goals
- **Рекомендации от ИИ** — AI recommendations
- **Список задач / План действий** — action items
- **The Vibe / The Dynamic** — (English recordings) tone and sentiment

### Attachments (text files)

| File | Content |
|------|---------|
| `транскрипт.txt` | Raw transcript with speaker labels (Speaker 0, Speaker 1...) |
| `резюме-Client Needs.txt` | Client needs analysis |
| `резюме-Key Points.txt` | Key points summary |
| `резюме-Meeting Minutes.txt` | Meeting minutes format |

Not all attachments are always present. The raw transcript is the most valuable.

## Processing Pipeline

### Step 1: Parse Metadata

Extract from subject and body:

```yaml
date: 2026-04-15          # from subject [Plaud-AutoFlow] MM-DD
title: <descriptive title>  # from subject after date
language: ru|en|mixed       # detect from body/transcript
type: consultation|meeting|brainstorm|casual|lecture|masterclass
```

### Step 2: Identify Participants

From email body and transcript context:
1. Look for explicit names in the body ("Клиент: Никита", "Консультант: Ашот")
2. Map Speaker labels to real names using context clues:
   - "я" patterns from Shakhruz's perspective → Speaker = Shakhruz/Ашот
   - Named references ("Никита сказал", "как я говорил")
   - Role markers ("клиент", "консультант", "партнёр")
3. Check `wiki/people/` for known contacts to enrich identification
4. If unsure, keep as "Speaker 0", "Speaker 1" — don't fabricate

### Step 3: Save Raw Sources

```bash
SLUG="YYYY-MM-DD-<kebab-title>"
mkdir -p /workspace/group/sources/plaud/$SLUG

# Save email body as summary
cat > /workspace/group/sources/plaud/$SLUG/summary.md << 'EOF'
---
source: plaud
date: YYYY-MM-DD
title: <title>
participants: [name1, name2]
type: <type>
---

<email body content>
EOF

# Save attachments
cp транскрипт.txt /workspace/group/sources/plaud/$SLUG/transcript.txt
cp резюме-*.txt /workspace/group/sources/plaud/$SLUG/
```

### Step 4: Create Source Summary for Wiki

Create `wiki/sources/YYYY-MM-DD-plaud-<slug>.md`:

```markdown
---
title: "PLAUD: <Title>"
type: source-summary
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: [sources/plaud/<slug>/transcript.txt]
related: []
tags: [plaud, meeting, <topic-tags>]
confidence: high
plaud:
  date: YYYY-MM-DD
  duration: <if available>
  participants: [name1, name2]
  type: <meeting type>
  language: ru|en|mixed
---

## Контекст

<1-2 sentences: who, when, why this conversation happened>

## Ключевые тезисы

<5-10 bullet points — the actual substance, not meta-description>
<Each point should be a specific fact, decision, insight, or opinion>

## Участники и позиции

### <Name 1> (role)
- <Their key points, positions, concerns>

### <Name 2> (role)
- <Their key points, positions, concerns>

## Решения и договорённости

<Specific decisions made during the conversation>

## Action Items

- [ ] <task> — <who> — <deadline if mentioned>

## Цитаты

> <2-3 notable direct quotes from the transcript, with speaker attribution>

## Связи

- [[wiki-link-to-related-concept]]
- [[wiki-link-to-person]]
- [[wiki-link-to-project]]
```

### Step 5: Update Wiki Pages

Standard wiki ingest — update 10-15 pages:

1. **People** (`wiki/people/`):
   - Create or update pages for each participant
   - Add `last-seen: YYYY-MM-DD`, update context, relationship
   - Add reference to this meeting in their page

2. **Concepts** (`wiki/concepts/`):
   - Update or create concept pages for key topics discussed
   - Link back to this source

3. **Projects** (`wiki/projects/`):
   - If a project was discussed, update its page with new information

4. **Entities** (`wiki/entities/`):
   - Companies, products, platforms mentioned

5. **Journal** (`wiki/journal/YYYY-MM-DD.md`):
   - Add entry about this meeting

6. **Index** (`wiki/index.md`):
   - Add source-summary entry

7. **Log** (`wiki/log.md`):
   - Append: `## [YYYY-MM-DD] ingest | PLAUD: <title>`

### Step 6: Git Commit

```bash
cd /workspace/group
git add -A
git commit -m "ingest: PLAUD recording — <title> (<date>)"
```

## Speaker Identification Heuristics

Since PLAUD uses generic "Speaker 0/1/2" labels, use these heuristics:

1. **Shakhruz is almost always present** — he owns the device
2. **Shakhruz typically speaks most** — he's usually the consultant/host
3. **Context from wiki**: check `wiki/people/` for scheduled meetings, known contacts
4. **Name drops**: "Никита, послушай" → next speaker is likely Никита
5. **Self-references**: "мой проект NanoClaw" → this is Shakhruz
6. **Role consistency**: once mapped, a speaker keeps their role throughout

When confidence is low, use format: `Speaker 0 (предположительно Никита)`.

## Quality Rules

- **One recording = one ingest.** Never batch multiple recordings.
- **Substance over meta.** "They discussed AI" is useless. "Ашот предложил модель подписки $200/мес с 60% партнёрам" is useful.
- **Preserve disagreements.** If participants disagreed, capture both positions.
- **Action items must be specific.** "Обсудить позже" → skip. "Никита: изучить воркшоп до пятницы" → keep.
- **Quotes add value.** Pick 2-3 quotes that capture the essence, not pleasantries.
- **Don't sanitize.** If the conversation was blunt, the wiki entry should reflect that tone.
