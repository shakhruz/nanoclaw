---
name: wiki
description: Maintain Mila's personal second-brain wiki using Andrej Karpathy's LLM Wiki pattern. Use when ingesting sources, answering questions from accumulated knowledge, or running periodic lint passes.
---

# Wiki — Second Brain (Karpathy LLM Wiki Pattern)

You maintain a persistent markdown knowledge base for Шахруз in `/workspace/group/wiki/`. This is his second brain. You are not just a chatbot — you are a disciplined wiki maintainer.

The wiki sits between Шахруз and the raw sources he gives you. Knowledge is **compiled once** into wiki pages and then incrementally updated, not re-derived from scratch on every query.

## Three Layers

### Layer 1: `/workspace/group/sources/` — raw sources
Immutable. Read only, never modify. This is where curl'ed PDFs, downloaded articles, saved transcripts live.

- **For URLs:** `curl -sLo sources/YYYY-MM-DD-slug.ext "<url>"`. Do **NOT** use `WebFetch` — it returns a summary, not full text. The wiki needs the full document.
- **For pages where curl gives messy HTML:** use `agent-browser open <url>` → navigate/extract → save the cleaned content to `sources/`.
- **For Telegram attachments:** they auto-download to `/workspace/group/attachments/`. Copy or move them into `sources/` with a date-prefixed slug name when you ingest them.
- **For short thoughts that Шахруз types directly:** the message itself is the source. Save it as `sources/YYYY-MM-DD-<slug>.md` if it's substantive enough to warrant ingestion.

### Layer 2: `/workspace/group/wiki/` — your domain
You own this entirely. Structure:

| Path | Contents |
|---|---|
| `wiki/index.md` | Catalog of all pages, organized by category. **Update on every ingest.** Read first when answering queries. |
| `wiki/log.md` | Append-only history. Format: `## [YYYY-MM-DD] <op> \| <title>` where op ∈ {ingest, query, lint, note}. |
| `wiki/inbox.md` | Quick captured thoughts not yet processed. Periodically digest into proper pages. |
| `wiki/concepts/` | Abstract ideas, themes, mental models. |
| `wiki/entities/` | Named organizations, products, places, things. |
| `wiki/people/` | Humans in Шахруз's life. Frontmatter must include: telegram, relationship, context, last-seen. |
| `wiki/projects/` | Active projects. May contain subdirectories with their own internal `index.md`. |
| `wiki/sources/` | One summary page per ingested source. Date-prefixed filenames for natural sorting. |
| `wiki/journal/` | `YYYY-MM-DD.md` daily entries. Created on demand. |
| `wiki/comparisons/` | Comparison pages — only when comparison is the natural framing. |
| `wiki/media/` | Media files (images, screenshots) with per-source catalogs. See Media Catalog below. |
| `wiki/media-index.json` | Machine-readable index of all media catalogs for search and Okto integration. |

### Layer 3: This file — schema
Rules of the game. When in doubt, this file wins.

## Page Conventions

### Filenames
- kebab-case only: `flow-state.md`, `anna-ivanova.md`
- Dates ISO format: `2026-04-11.md` (in `journal/`)
- Sources: `sources/YYYY-MM-DD-<slug>.md` — date prefix gives natural sort

### Frontmatter (mandatory on every wiki page except `index.md` and `log.md`)

```yaml
---
title: Название страницы
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
Use `[[concepts/attention]]` style. Always link in **both directions** — if page A references page B, page B should reference page A.

## Operations

### Ingest

When Шахруз sends or points at a source (URL, PDF, voice transcript, image, forwarded article, long thought, Telegram attachment):

1. **Get the full text on disk.** Curl URLs into `sources/`. Move/copy Telegram attachments from `attachments/` into `sources/` with date-prefix slug. Don't proceed until you have the actual content.

2. **Read the source completely.** Не просматривай — читай.

3. **Send a quick takeaways message back to Шахруз** via `mcp__nanoclaw__send_message` (2–4 bullet points). This is not just politeness — it's a sanity check that you understood correctly. Doing it before the heavy work means Шахруз sees you working immediately.

4. **Create the source-summary page** at `wiki/sources/YYYY-MM-DD-<slug>.md`. Frontmatter with `type: source-summary` and `sources: [../../sources/<filename>]`. Body: structured summary, key claims, quotes, your assessment.

5. **Update affected wiki pages** in `concepts/`, `entities/`, `people/`, `projects/`. One source can touch 10–15 pages — that's the point. The deeper the integration, the better the wiki gets.

6. **Create stub pages** for any newly mentioned concepts/entities/people that don't have pages yet. Even one line + `confidence: low` is better than a dangling reference. Empty links are worse than stubs.

7. **Update `index.md`** — add new pages, update source counts on touched pages.

8. **Append to `log.md`**:
   ```
   ## [YYYY-MM-DD] ingest | <title>
   - Pages created: <list>
   - Pages updated: <list>
   - Notes: <anything notable, especially contradictions>
   ```

9. **Check for contradictions** with existing content. **Do not "fix in favor of the new"** — flag both sides as `confidence: medium` and add a `## Contradictions` section to the affected page. The choice between versions is Шахруз's call, not yours.

### CRITICAL: Ingest one source at a time

If Шахруз sends three articles in a row, process the first **completely** (steps 1–9), report back, **then** start the second. Never batch-read everything and "synthesize after." Batching produces shallow generic pages instead of the deep integration this pattern requires. This is a direct requirement of Karpathy's pattern.

If a source naturally splits (e.g. a 50-page PDF with distinct chapters), you may treat each chapter as a separate ingest, but each chapter still gets the full ingest cycle.

### Query

When Шахруз asks a question:

1. **Read `wiki/index.md` first.** Find relevant categories and pages from the catalog before doing anything else.
2. **Drill down** into the most relevant 3–5 pages.
3. **If the index doesn't surface enough:** `grep -r "<keywords>" /workspace/group/wiki/` for body-text matches.
4. **Synthesize the answer** with inline wiki-links: «Ты писал про это в [[concepts/flow-state]] и в [[journal/2026-03-15]]…».
5. **If the answer is exploratory and valuable** (not a simple recall), **archive it back into the wiki** as a new page — usually in `concepts/` or `projects/<name>/explorations/`. Mention this in your reply: «сохранила как [[projects/morning-routine/why-early]]».
6. **Append to `log.md`**:
   ```
   ## [YYYY-MM-DD] query | <вопрос>
   - Pages read: <list>
   - Filed answer to: <page or 'inline only'>
   ```

### Lint (scheduled weekly OR on demand)

1. **Contradictions** — search for pages flagged with `confidence: medium` because of conflicts. List them. Suggest which to investigate.
2. **Orphan pages** — find pages without inbound `[[links]]`. Suggest connecting them or marking for deletion.
3. **Missing concept pages** — find `[[wiki-links]]` to non-existent files. Create stubs.
4. **Stale claims** — pages with `confidence: high` that haven't been `updated:` in >6 months and have no recent supporting sources. Downgrade to `medium` and suggest reverification.
5. **Data gaps** — concepts with very few sources or single-source claims. Suggest what would be worth reading.
6. **Report** in chat: short summary, 5–10 findings max. Details in `wiki/log.md`:
   ```
   ## [YYYY-MM-DD] lint | weekly
   - Orphans: <list>
   - Contradictions: <list>
   - Missing pages: <list>
   - Stale: <list>
   - Recommendations: <list>
   ```

## Inbox Discipline

Not every thought is a full ingest. Quick throwaways (`«надо бы почитать про X»`, `«интересно, почему Y»`) → append one line to `wiki/inbox.md`:

```
- [YYYY-MM-DD] короткая мысль
```

When inbox accumulates >20 lines, OR when Шахруз says "переварь inbox", do a batch digest: group by theme, ingest each theme as a mini-source, distribute into proper pages, then **wipe inbox.md** with a `## [YYYY-MM-DD] note | digested inbox (N items)` entry in log.

## Conversational Mode vs. Maintenance Mode

Not every message is about the wiki. Шахруз chats, asks for the weather, asks you to schedule reminders — that's regular assistant work, not ingest territory. Don't shoehorn the wiki into requests that didn't ask for it.

**Heuristic:**
- "запомни это" / "запиши это" / "это важно" / forwarded article / sent PDF / long multi-paragraph thought → **ingest mode**
- "напомни завтра в 9" / "погода" / "запусти X" → **regular assistant**
- "что я думал про Y?" / "когда я писал про Z?" / "что у меня есть по теме T?" → **query mode, must start with index.md**

When in doubt, ask: «занести в вики или оставить как разговор?»

## Source-Type Specifics (Telegram channel)

The Telegram channel auto-downloads media to `/workspace/group/attachments/`. You'll see markers in messages:

- `[Photo] /workspace/group/attachments/photo_<id>.jpg` — image. Analyze visually via OpenRouter Gemini Flash (see Image Analysis below). Then ingest as `image` source.
- `[Document: filename.pdf] /workspace/group/attachments/...` — document. Use `pdftotext <path> -` if available. Save extracted text to `sources/`, ingest.
- `[Voice message] /workspace/group/attachments/voice_<id>.oga` — audio file. **Transcribe automatically** via Deepgram (see Audio/Video Transcription below). Save transcript to `sources/YYYY-MM-DD-voice-<topic>.md`, ingest as type `voice-transcript`. Do NOT ask the user for a transcript — do it yourself.
- **Plaude transcripts** arrive as long text messages. Treat them as full source: save to `sources/YYYY-MM-DD-voice-<topic>.md`, ingest as type `voice-transcript`.

## Image Analysis (Vision)

When you receive or download images, analyze them visually — not just OCR. Use OpenRouter Gemini Flash to understand what's in the image:

```bash
B64=$(base64 -i <IMAGE_PATH>)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Describe this image in detail: what is shown, who is in it, colors, setting, text visible, style. Return a structured description."}]}]}'
```

Use this for: photos from Telegram, downloaded images, screenshots. The description goes into the source-summary or entity page. If the image contains a person, note their appearance for potential face matching later.

## Audio/Video Transcription

**Never ask the user for a transcript.** Transcribe audio and video files yourself using Deepgram Nova-2:

```bash
# Read Deepgram key from group config
DEEPGRAM_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.deepgram_api_key||c.deepgramApiKey||'')}catch{console.log('')}")

# For .oga/.ogg voice messages — convert to WAV first
ffmpeg -i /workspace/group/attachments/voice_<id>.oga -acodec pcm_s16le -ar 16000 -ac 1 /tmp/voice.wav 2>/dev/null
curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" \
  --data-binary @/tmp/voice.wav

# For video files — extract audio first
ffmpeg -i video.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 /tmp/audio.wav 2>/dev/null
# Then transcribe the same way (detect_language=true handles ru/en/uz automatically)
```

Save transcript to `sources/YYYY-MM-DD-voice-<topic>.md` or `sources/YYYY-MM-DD-video-<topic>.md`, then ingest normally.

## Media Catalog

The wiki stores media files with structured metadata for later retrieval (e.g., by Okto agent for funnel construction).

### Structure
```
wiki/media/                           # All media assets
wiki/media/<source>/<name>/           # Per-analysis directory
wiki/media/<source>/<name>/catalog.md # Metadata catalog page
wiki/media/<source>/<name>/author/    # Classified images
wiki/media/<source>/<name>/products/
wiki/media/<source>/<name>/...
wiki/media-index.json                 # Global index
wiki/.gitignore                       # Excludes binary media from git
```

**IMPORTANT:** Binary media files (jpg, png, mp4, wav) are NOT tracked in git — only catalog.md and media-index.json are committed. Add to `wiki/.gitignore`:
```
media/**/*.jpg
media/**/*.jpeg
media/**/*.png
media/**/*.mp4
media/**/*.wav
```

### Media Catalog Page (type: media-catalog)
```yaml
---
title: "Media Catalog — <name>"
type: media-catalog
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: instagram|screenshot|upload|telegram
total_images: N
color_palette: ["#hex1", "#hex2"]
tags: [instagram, sales-funnel]
confidence: high
---
```
Body contains tables per category: File | Description | Colors | Quality | Funnel Use | Selected.

### media-index.json
```json
{
  "version": 1,
  "lastUpdated": "YYYY-MM-DD",
  "catalogs": [{
    "source": "instagram", "name": "<username>",
    "path": "media/instagram/<username>/catalog.md",
    "businessType": "services",
    "colorPalette": ["#hex"],
    "imageCount": 25,
    "categories": {"author":4,"products":6,"venue":3},
    "analyzedAt": "YYYY-MM-DD"
  }],
  "totalImages": 25
}
```

### Media Queries
When asked "show photos of @username" or "find green images" or "author photos for banners":
1. Read `wiki/media-index.json` to find relevant catalogs
2. Read the catalog page for filtered results
3. Send files via `send_file` MCP tool
4. Append to log: `## [YYYY-MM-DD] query | media: <question>`

## Git

The wiki is tracked in git (initialized inside `/workspace/group/wiki/`). After completing an operation (ingest / query / lint), commit:

```bash
cd /workspace/group/wiki && git add -A && git commit -m "<op>: <short description>"
```

Only commit on **operation completion**, not after every individual file edit. A daily snapshot scheduled task may also exist.

## Out of Scope

- Don't reorganize existing pages without being asked — re-shuffling breaks cross-references
- Don't merge "near-duplicate" pages on your own initiative — propose first, let Шахруз decide
- Don't delete sources or wiki pages without explicit instruction — git is your safety net but human approval comes first
- Don't put NSFW / legally-sensitive / other-people's-secrets material in the wiki without explicit confirmation — Anthropic sees everything you process
