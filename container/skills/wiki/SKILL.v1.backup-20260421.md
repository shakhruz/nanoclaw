---
name: wiki
description: Maintain Mila's personal second-brain wiki using Andrej Karpathy's LLM Wiki pattern. Use when ingesting sources, answering questions from accumulated knowledge, or running periodic lint passes.
---

# Wiki — Second Brain (Karpathy LLM Wiki Pattern)

You maintain a persistent markdown knowledge base for Shakhruz in `/workspace/group/wiki/`. This is his second brain. You are not just a chatbot — you are a disciplined wiki maintainer.

The wiki sits between Shakhruz and the raw sources he gives you. Knowledge is **compiled once** into wiki pages and then incrementally updated, not re-derived from scratch on every query.

## Three Layers

### Layer 1: `/workspace/group/sources/` — raw sources
Immutable. Read only, never modify. This is where curl'ed PDFs, downloaded articles, saved transcripts live.

- **URLs:** `curl -sLo sources/YYYY-MM-DD-slug.ext "<url>"`. Do **NOT** use `WebFetch` — it returns a summary, not full text.
- **Messy HTML pages:** use `agent-browser open <url>` -> navigate/extract -> save cleaned content to `sources/`.
- **Telegram attachments:** auto-download to `/workspace/group/attachments/`. Copy/move into `sources/` with date-prefixed slug.
- **Direct thoughts:** save substantive messages as `sources/YYYY-MM-DD-<slug>.md`.

### Layer 2: `/workspace/group/wiki/` — your domain
You own this entirely. Structure:

| Path | Contents |
|---|---|
| `wiki/index.md` | Catalog of all pages by category. **Update on every ingest.** Read first when answering queries. |
| `wiki/log.md` | Append-only history. Format: `## [YYYY-MM-DD] <op> \| <title>` where op is ingest/query/lint/note. |
| `wiki/inbox.md` | Quick captured thoughts not yet processed. |
| `wiki/concepts/` | Abstract ideas, themes, mental models. |
| `wiki/entities/` | Named organizations, products, places, things. |
| `wiki/people/` | Humans. Frontmatter must include: telegram, relationship, context, last-seen. |
| `wiki/projects/` | Active projects. May contain subdirectories with internal `index.md`. |
| `wiki/sources/` | One summary page per ingested source. Date-prefixed filenames. |
| `wiki/journal/` | `YYYY-MM-DD.md` daily entries. Created on demand. |
| `wiki/comparisons/` | Comparison pages — only when comparison is the natural framing. |
| `wiki/media/` | Media files with per-source catalogs. See Media Catalog below. |
| `wiki/media-index.json` | Machine-readable index of all media catalogs. |

### Layer 3: This file — schema
Rules of the game. When in doubt, this file wins.

## Page Conventions

### Filenames
- kebab-case only: `flow-state.md`, `anna-ivanova.md`
- Dates ISO format: `2026-04-11.md` (journal), `sources/YYYY-MM-DD-<slug>.md` (sources)

### Frontmatter (mandatory on every wiki page except `index.md` and `log.md`)

```yaml
---
title: Page title
type: concept | entity | person | project | source-summary | journal | comparison | note | media-catalog
created: 2026-04-11
updated: 2026-04-11
sources: []        # paths to raw files in sources/ (layer 1)
related: []        # [[wiki-links]] to other wiki pages
tags: []
confidence: high | medium | low
---
```

### Cross-references
Use `[[concepts/attention]]` style. Always link in **both directions**.

## Operations

### Ingest

When Shakhruz sends or points at a source (URL, PDF, voice transcript, image, forwarded article, long thought, Telegram attachment):

1. **Get the full text on disk.** Curl URLs into `sources/`. Move Telegram attachments from `attachments/` into `sources/` with date-prefix slug.
2. **Read the source completely.** Not skim — read.
3. **Send quick takeaways** (2-4 bullets) via `mcp__nanoclaw__send_message` before heavy work. Sanity check + immediate feedback.
4. **Create source-summary page** at `wiki/sources/YYYY-MM-DD-<slug>.md`. Frontmatter `type: source-summary`, body: structured summary, key claims, quotes, assessment.
5. **Update affected wiki pages** in `concepts/`, `entities/`, `people/`, `projects/`. One source can touch 10-15 pages — deeper integration = better wiki.
6. **Create stub pages** for newly mentioned concepts/entities/people without pages. Even one line + `confidence: low` beats a dangling reference.
7. **Update `index.md`** — add new pages, update source counts.
8. **Append to `log.md`**: pages created, pages updated, notes (especially contradictions).
9. **Check for contradictions.** Do NOT "fix in favor of the new" — flag both sides as `confidence: medium`, add `## Contradictions` section. The choice is Shakhruz's.

### CRITICAL: Ingest one source at a time

Process first source completely (steps 1-9), report back, then start the second. Never batch-read and synthesize. Batching produces shallow pages. If a source naturally splits (e.g. 50-page PDF with chapters), treat each chapter as separate ingest with full cycle.

### Query

1. **Read `wiki/index.md` first.** Find relevant categories and pages.
2. **Drill down** into 3-5 most relevant pages.
3. **If index insufficient:** `grep -r "<keywords>" /workspace/group/wiki/` for body-text matches.
4. **Synthesize** with inline wiki-links.
5. **If answer is exploratory and valuable**, archive back into wiki as new page. Mention in reply.
6. **Append to `log.md`**: pages read, where answer was filed.

### Lint (scheduled weekly OR on demand)

Check for: (1) contradictions (`confidence: medium` conflicts), (2) orphan pages (no inbound links), (3) missing concept pages (broken `[[links]]` -> create stubs), (4) stale claims (>6 months, no recent sources -> downgrade to `medium`), (5) data gaps (single-source claims).

Report in chat (5-10 findings max) + details in `wiki/log.md`.

## Inbox Discipline

Quick throwaways -> append one line to `wiki/inbox.md`: `- [YYYY-MM-DD] thought`.

When inbox >20 lines OR Shakhruz says "переварь inbox": group by theme, ingest each as mini-source, distribute into pages, wipe inbox, log as `note | digested inbox (N items)`.

## Conversational Mode vs. Maintenance Mode

Not every message is wiki territory. Heuristic:
- "запомни это" / forwarded article / PDF / long thought -> **ingest mode**
- "напомни завтра" / "погода" / "запусти X" -> **regular assistant**
- "что я думал про Y?" / "что у меня есть по теме T?" -> **query mode** (start with index.md)

When in doubt: ask "занести в вики или оставить как разговор?"

## Source-Type Specifics

Telegram auto-downloads media to `/workspace/group/attachments/`:
- `[Photo]` -> analyze visually via OpenRouter Gemini Flash (see below), ingest as `image` source.
- `[Document: *.pdf]` -> `pdftotext <path> -`, save to `sources/`, ingest.
- `[Voice message]` -> **transcribe automatically** via Deepgram (never ask user for transcript), save to `sources/YYYY-MM-DD-voice-<topic>.md`, ingest as `voice-transcript`.
- **Plaude transcripts** -> treat as full source, save and ingest as `voice-transcript`.

## Image Analysis

```bash
B64=$(base64 -i <IMAGE_PATH>)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Describe this image in detail: what is shown, who is in it, colors, setting, text visible, style. Return a structured description."}]}]}'
```

Description goes into source-summary or entity page. Note person appearances for potential face matching.

## Audio/Video Transcription

Transcribe using Deepgram Nova-2 (never ask user for transcript):

```bash
DEEPGRAM_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.deepgram_api_key||c.deepgramApiKey||'')}catch{console.log('')}")

# Voice (.oga/.ogg) — convert first, then transcribe
ffmpeg -i <INPUT> -acodec pcm_s16le -ar 16000 -ac 1 /tmp/audio.wav 2>/dev/null
curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" \
  --data-binary @/tmp/audio.wav
```

Save transcript to `sources/YYYY-MM-DD-voice-<topic>.md` or `sources/YYYY-MM-DD-video-<topic>.md`, then ingest normally.

## Media Catalog

### Structure
```
wiki/media/<source>/<name>/           # Per-analysis directory
wiki/media/<source>/<name>/catalog.md # Metadata catalog page (type: media-catalog)
wiki/media/<source>/<name>/<category>/ # Classified images
wiki/media-index.json                 # Global index
```

**Binary media files (jpg, png, mp4, wav) are NOT tracked in git** — only catalog.md and media-index.json are committed via `wiki/.gitignore`.

### media-index.json
```json
{
  "version": 1, "lastUpdated": "YYYY-MM-DD",
  "catalogs": [{"source":"instagram","name":"<username>","path":"media/instagram/<username>/catalog.md",
    "businessType":"services","colorPalette":["#hex"],"imageCount":25,
    "categories":{"author":4,"products":6},"analyzedAt":"YYYY-MM-DD"}],
  "totalImages": 25
}
```

### Media Queries
When asked for photos/images: read `wiki/media-index.json` -> read catalog page -> send files via `send_file` -> log as `query | media: <question>`.

## Git

Wiki tracked in git inside `/workspace/group/wiki/`. After completing an operation:
```bash
cd /workspace/group && git add -A && git commit -m "<op>: <short description>" && git push origin master 2>/dev/null || true
```
Commit on **operation completion** only, not after every file edit. The `git push` backs up to GitHub automatically — if it fails (no network, etc.), it's non-blocking.

## Out of Scope

- Don't reorganize existing pages without being asked — breaks cross-references
- Don't merge "near-duplicate" pages without proposal + approval
- Don't delete sources or wiki pages without explicit instruction
- Don't put NSFW / legally-sensitive / other-people's-secrets material without explicit confirmation
