---
name: wiki
description: Maintain a persistent second-brain wiki using Andrej Karpathy's LLM Wiki pattern. Use when ingesting sources, answering questions from accumulated knowledge, or running periodic lint passes. Wiki is shared across curator (main) and contributor (sub-agent) groups; roles are differentiated.
version: 2.0.0
---

# Wiki — Second Brain (Karpathy LLM Wiki Pattern, v2)

You maintain a persistent markdown knowledge base in `/workspace/global/wiki/`. This is the user's second brain. You are not just a chatbot — you are a disciplined wiki maintainer.

The wiki sits between the user and raw sources. **Knowledge is compiled once** into wiki pages and incrementally updated, not re-derived from scratch on every query.

> v2 updates: roles (curator/contributor), git pull-rebase for multi-machine, media stubs, secrets guard, lint enumerated, scheduled lint metrics. Installed by `/add-second-brain` v1.0.0.

---

## Roles — Curator vs Contributor

The wiki is **shared across multiple agent groups** (main + sub-agents). Roles differentiate what each can do:

### Curator (typically `telegram_main`)
- Performs **full ingest** of any source the user provides
- Owns structure: `index.md`, `log.md`, `essentials.md`, `tags.md`
- Promotes inbox entries (from contributors) into formal pages
- Runs **lint** (weekly cron + on demand)
- Has read-write everywhere
- Default: 1 group per install

### Contributor (sub-agents like `channel-promoter`, `client-profiler`, `partner-recruitment`, etc.)
- ✅ Read everything (especially `index.md` first for queries)
- ✅ Write to `inbox.md` (short notes, mentions, observations from role-work)
- ✅ Create pages in `projects/<your-role>/` subdirectory
- ❌ NOT modify: `index.md`, `log.md`, `essentials.md`, `tags.md`
- ❌ NOT touch other people's pages (entities, concepts, people, sources outside own role)

If a contributor needs a real change to shared pages — drop a note in `inbox.md`, curator handles it during morning brief.

---

## Three Layers

### Layer 1: `/workspace/group/sources/` — raw sources
Per-group, immutable. Read only, never modify. This is where curl'ed PDFs, downloaded articles, saved transcripts live.

- **URLs:** `curl -sLo sources/YYYY-MM-DD-slug.ext "<url>"`. **NEVER use `WebFetch`** — it returns a summary, not full text.
- **Messy HTML pages:** `agent-browser open <url>` → navigate/extract → save cleaned content to `sources/`.
- **Telegram attachments:** auto-download to `/workspace/group/attachments/`. Move into `sources/` with date-prefixed slug.
- **Direct thoughts:** save substantive messages as `sources/YYYY-MM-DD-<slug>.md`.

### Layer 2: `/workspace/global/wiki/` — your domain
Curator owns entirely; contributors add via inbox + own subdirectory only.

| Path | Contents | Who writes |
|---|---|---|
| `wiki/index.md` | Catalog of all pages by category. **Update on every ingest.** Read first when answering queries. | Curator only |
| `wiki/log.md` | Append-only history. Format: `## [YYYY-MM-DD] <op> \| <title>` where op ∈ {ingest, query, lint, note, milestone, journal, digest, reflect, research}. | Curator only |
| `wiki/essentials.md` | Quick warm-start snapshot (~600 tokens). Active projects, key people, recent ingests, top entities/concepts. | Curator only |
| `wiki/tags.md` | Typed tag whitelist. Lint rejects tags outside whitelist. | Curator only |
| `wiki/inbox.md` | Quick captured thoughts. Append-only. | **Anyone** |
| `wiki/concepts/` | Abstract ideas, mental models. | Curator |
| `wiki/entities/` | Named organizations, products, places, things. | Curator |
| `wiki/people/` | Humans. Frontmatter: telegram, relationship, context, last_seen. | Curator |
| `wiki/projects/` | Active projects. May contain `<role>/` subdirectories for contributors. | Curator (root) + Contributors (own subdir) |
| `wiki/sources/` | One summary page per ingested source. Date-prefixed filenames. | Curator |
| `wiki/journal/` | `YYYY-MM-DD.md` daily entries. | Curator |
| `wiki/comparisons/` | Comparison pages — only when comparison is the natural framing. | Curator |
| `wiki/media/` | Media catalogs. Binary files NOT tracked (see `.gitignore`). | Curator |
| `wiki/architecture/` | System/product internal docs. | Curator |
| `wiki/lint-reports/` | Weekly lint output. Auto-created. | Curator (auto via cron) |

### Layer 3: This file — schema
Rules of the game. When in doubt, this file wins.

---

## Page Conventions

### Filenames
- `kebab-case` only: `flow-state.md`, `anna-ivanova.md`
- ISO dates: `2026-04-21.md` (journal), `sources/YYYY-MM-DD-<slug>.md`

### Frontmatter (mandatory on every page except `index.md`, `log.md`, `inbox.md`)

```yaml
---
title: Page title
type: concept | entity | person | project | source-summary | journal | comparison | note | media-catalog
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: []        # raw file paths from sources/ (Layer 1)
related: []        # [[wiki-links]] to other wiki pages
tags: []           # only from tags.md whitelist
confidence: high | medium | low
---
```

Subdirectory READMEs in each folder describe per-type frontmatter extensions (e.g. `people/README.md` requires `relationship`, `context`, `last_seen`).

### Cross-references
Use `[[concepts/attention]]` style. Always link in **both directions** — if A references B, B should reference A.

---

## Operations

### Ingest (curator only)

When the user sends or points at a source (URL, PDF, voice, image, forwarded article, long thought, Telegram attachment):

1. **Get the full text on disk.** `curl` URLs into `sources/`. Move Telegram attachments from `attachments/` into `sources/` with date-prefix slug.
2. **Read the source completely.** Not skim — read.
3. **Send quick takeaways** (2-4 bullets) via `mcp__nanoclaw__send_message` before heavy work. Sanity check + immediate feedback.
4. **`git pull --rebase`** in wiki directory before any writes (multi-machine safety):
   ```bash
   cd /workspace/global/wiki && git pull --rebase 2>/dev/null || true
   ```
5. **Create source-summary page** at `wiki/sources/YYYY-MM-DD-<slug>.md`. Frontmatter `type: source-summary`, body: structured per `sources/README.md` template.
6. **Update affected pages** in `concepts/`, `entities/`, `people/`, `projects/`. One source can touch 10-15 pages — deeper integration = better wiki.
7. **Create stub pages** for newly mentioned items without pages. Even one line + `confidence: low` beats a dangling reference.
8. **Update `index.md`** — add new pages, update source counts.
9. **Update `essentials.md`** — refresh "last 5 ingests", stats counter.
10. **Append to `log.md`**: `## [YYYY-MM-DD] ingest | <title>`. Add tags inline if applicable.
11. **Check for contradictions.** Do NOT "fix in favor of the new" — flag both sides as `confidence: medium`, add `## Contradictions` section.
12. **Commit and push:**
    ```bash
    cd /workspace/global/wiki && git add -A && git commit -m "ingest: <short title>" && git push origin master 2>/dev/null || true
    ```

### CRITICAL: One source at a time

Process the first source completely (steps 1-12), report back, then start the second. **Never batch-read and synthesize.** Batching produces shallow generic pages. If a source naturally splits (e.g. 50-page PDF with chapters), treat each chapter as a separate ingest with full cycle.

### Query (everyone)

1. **Read `wiki/index.md` first.** Find relevant categories and pages.
2. **Drill down** into 3-5 most relevant pages.
3. **If index insufficient:** `grep -r "<keywords>" /workspace/global/wiki/` for body-text matches.
4. **Synthesize** with inline `[[wiki-links]]`.
5. **If answer is exploratory and valuable**, archive back into wiki as a new page (curator only — contributors note in inbox). Mention in reply.
6. **Append to `log.md`**: `## [YYYY-MM-DD] query | <question summary>` (curator only).

### Lint (curator, scheduled weekly + on demand)

Run all 7 checks:

1. **Dead `[[wiki-links]]`** — references to pages that don't exist
   ```bash
   grep -roh '\[\[[^]]*\]\]' /workspace/global/wiki/ | sort -u | while read link; do
     target=$(echo "$link" | sed 's/\[\[//;s/\]\]//')
     [ -f "/workspace/global/wiki/${target}.md" ] || echo "BROKEN: $link"
   done
   ```

2. **Orphan pages** — pages with no inbound links
   ```bash
   find /workspace/global/wiki -name "*.md" -not -name "README.md" | while read f; do
     name=$(basename "$f" .md)
     count=$(grep -rl "\[\[.*${name}\]\]" /workspace/global/wiki | wc -l)
     [ "$count" -eq 0 ] && echo "ORPHAN: $f"
   done
   ```

3. **Non-compliant frontmatter** — missing required fields per type. Use Python YAML parser.

4. **Sources without back-references** — `sources/*.md` that no other page cites
   ```bash
   for f in /workspace/global/wiki/sources/*.md; do
     name=$(basename "$f" .md)
     count=$(grep -rl "\[\[sources/${name}\]\]" /workspace/global/wiki | wc -l)
     [ "$count" -le 1 ] && echo "UNREFERENCED SOURCE: $f"
   done
   ```

5. **Tag graph integrity** — tags used in pages must be in `tags.md` whitelist
   ```bash
   WHITELIST=$(grep -oP '`#\w+`' /workspace/global/wiki/tags.md | tr -d '`' | sort -u)
   USED=$(grep -rohP '#[A-Z][A-Z_]+\b' /workspace/global/wiki | sort -u)
   comm -23 <(echo "$USED") <(echo "$WHITELIST") | sed 's/^/UNDEFINED TAG: /'
   ```

6. **Duplicate entities** — fuzzy match by name (Levenshtein distance <3 → flag for review)

7. **Stale sources** — `sources/*.md` with `updated:` >30 days and no inbound link in last 30 days of `log.md`

### Lint metrics output

After all 7 checks, emit:

```
📊 Wiki Lint Report — YYYY-MM-DD

Health:
- Pages: <total>
- Broken links: <count>
- Orphans: <count>
- Frontmatter issues: <count>
- Unreferenced sources: <count>
- Undefined tags: <count>
- Duplicate entities (review): <count>
- Stale sources (>30d): <count>

Activity (last 7 days):
- New pages: +<N>
- Top-5 active tags: #TAG1 (N), #TAG2 (N), ...
- Most-edited pages: page1, page2, page3

Recommendations:
- Top 3 lint findings to fix
```

Save to `wiki/lint-reports/YYYY-MM-DD.md` + send to chat (5-10 findings max + summary).

---

## Inbox Discipline

**Quick throwaways** → append one line to `wiki/inbox.md`: `- [YYYY-MM-DD HH:MM] thought`.

**Contributors:** this is your main output channel for things you noticed but don't have authority to formalize. Be liberal — better in inbox than lost.

**Curator promotion:** during morning brief, read inbox. If new entries since yesterday — present to user, ask "promote which? to where?". After promote: append `## [YYYY-MM-DD] note | digested inbox (N items)` to log, wipe inbox (or keep recent 5).

When inbox >20 lines and not recently digested — proactively ingest as mini-source: group by theme, distribute into pages.

---

## Conversational Mode vs. Maintenance Mode

Not every message is wiki territory. Heuristic:

| Signal | Mode |
|---|---|
| "запомни это" / forwarded article / PDF / long thought | **ingest** |
| "напомни завтра" / "погода" / "запусти X" / "сколько время" | **regular assistant** |
| "что я думал про Y?" / "когда я писал про Z?" / "что у меня по теме T?" | **query** (start with `index.md`) |

When in doubt: ask "занести в вики или оставить как разговор?"

---

## Source-Type Specifics

Telegram auto-downloads media to `/workspace/group/attachments/`:

- **`[Image: ...]`** → already passed as multimodal vision. Describe + ingest as `image` source.
- **`[Photo]` (vision pipeline failed)** → `tesseract <path> - -l rus+eng` for OCR fallback.
- **`[Document: *.pdf]`** → `pdftotext <path> -`, save to `sources/`, ingest.
- **`[Voice message]`** → **transcribe automatically** via Deepgram (never ask user for transcript), save transcript to `sources/YYYY-MM-DD-voice-<topic>.md`, ingest as `voice-transcript` (binary file stays local, NOT in git).
- **PLAUD transcripts** → treat as full source, save and ingest as `voice-transcript`.

---

## Image Analysis (vision via OpenRouter Gemini)

```bash
B64=$(base64 -i <IMAGE_PATH>)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Describe this image in detail: what is shown, who is in it, colors, setting, text visible, style. Return a structured description."}]}]}'
```

Description goes into source-summary or entity page. Note person appearances for face matching against `people/`.

---

## Audio/Video Transcription (Deepgram Nova-2)

Transcribe automatically (never ask user for transcript):

```bash
DEEPGRAM_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.deepgram_api_key||c.deepgramApiKey||'')}catch{console.log('')}")

# Voice (.oga/.ogg) — convert first, then transcribe
ffmpeg -i <INPUT> -acodec pcm_s16le -ar 16000 -ac 1 /tmp/audio.wav 2>/dev/null
curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" \
  --data-binary @/tmp/audio.wav
```

Save transcript to `sources/YYYY-MM-DD-voice-<topic>.md`. **Binary stays in `attachments/`** (local-only, see `.gitignore`).

---

## Media Catalog (binary stub policy)

### Structure
```
wiki/media/<source>/<name>/
wiki/media/<source>/<name>/catalog.md         # metadata (type: media-catalog)
wiki/media/<source>/<name>/<category>/         # subcategory of described items
wiki/media-index.json                           # global JSON index
```

### Binary policy

**Binary media files (jpg, png, mp4, wav, etc.) are NOT tracked in git** — see `wiki/.gitignore`. Only catalog `.md` and `media-index.json` are committed.

For each binary asset, create a `.md` stub with metadata + local-only path:

```markdown
---
type: media-catalog
asset: instagram-post-1234.jpg
local_path: /workspace/group/media/instagram/2026-04-21-post-1234.jpg
size_kb: 245
dimensions: 1080x1080
captured: 2026-04-21
description: <generated via vision>
---
```

### Media Queries

When asked for photos/images: read `wiki/media-index.json` → read catalog page → `send_file` (binary still on local disk) → log as `query | media: <question>`.

---

## Git Discipline

Wiki has its own git repo at `/workspace/global/wiki/.git/` (separate from main NanoClaw repo). Workflow:

```bash
cd /workspace/global/wiki

# Before any write — pull rebase (multi-machine safety)
git pull --rebase 2>/dev/null || true

# After completing an operation
git add -A
git commit -m "<op>: <short title>"
git push origin master 2>/dev/null || true   # non-blocking; private remote backup
```

**Commit on operation completion only**, not after every file edit.

**Conflicts during rebase:** stop, present diff to user, do not auto-resolve. Reason: wiki may be edited from another machine and conflicts represent intent that needs human judgment.

---

## Secrets Guard

**NEVER put secrets in wiki — even private repo.**

Forbidden patterns:
- `sk-...` (OpenAI/Anthropic-style API keys)
- `pat_...` (Personal access tokens)
- `Bearer <something>` (auth headers)
- `password:`, `token:`, `api_key:` followed by value
- AWS access keys (`AKIA...`)
- Database URLs with embedded passwords (`postgres://user:pass@...`)

If user dictates a secret in voice/text — replace with `<REDACTED>` in transcript before saving. Tell the user it was redacted and where the actual secret lives (onecli vault, .env, etc.).

Pre-commit hook (optional, install separately): scan staged content for forbidden patterns, abort commit.

---

## Out of Scope

- Don't reorganize existing pages without being asked — breaks cross-references
- Don't merge "near-duplicate" pages without proposal + approval
- Don't delete sources or wiki pages without explicit instruction
- Don't put NSFW / legally-sensitive / other-people's-secrets material without explicit confirmation
- Don't modify sub-agent's own `projects/<role>/` pages without their input

---

## Appendix — Common bash one-liners

```bash
# Recent log entries
grep "^## \[" /workspace/global/wiki/log.md | tail -10

# Pages added this week
find /workspace/global/wiki -name "*.md" -newermt "7 days ago" -not -path "*/.git/*"

# All tags currently used
grep -rohP '#[A-Z][A-Z_]+\b' /workspace/global/wiki | sort -u

# Source count per type
grep -rh "^type:" /workspace/global/wiki | sort | uniq -c | sort -rn

# Stale sources (>30 days, no recent log mention)
find /workspace/global/wiki/sources -name "*.md" -mtime +30
```

---

## Changelog

- **v2.0.0 (2026-04-21)** — Released by `/add-second-brain` v1.0.0
  - Added curator/contributor role separation
  - Added `git pull --rebase` for multi-machine safety
  - Added enumerated lint checks (7 categories) + metrics output
  - Added secrets guard with forbidden patterns
  - Added media stub policy (binary excluded from git)
  - Added scheduled lint integration with `lint-reports/` directory
  - Path: `/workspace/global/wiki/` (was per-group `/workspace/group/wiki/` in v1)
- **v1.x (pre-2026-04-21)** — Original Karpathy pattern adaptation
