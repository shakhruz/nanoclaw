# LLM Wiki — Conceptual Reference

> Adapted from [karpathy/llm-wiki.md](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), with NanoClaw-specific operational extensions.

A pattern for building personal knowledge bases using LLMs.

This file communicates the high-level idea. The operational instantiation lives in `container/skills/wiki/SKILL.md` (v2, installed by `/add-second-brain`). Read this for *why*; read the container skill for *how*.

---

## The Core Idea

Most LLM-document interactions follow RAG: upload files, retrieve chunks at query time, generate answers. Knowledge re-derives on every question — no accumulation.

The LLM Wiki pattern differs fundamentally. The LLM incrementally builds and maintains a **persistent wiki** — a structured, interlinked markdown collection sitting between you and raw sources. When new material arrives, the LLM reads it, extracts key information, integrates it into existing wiki pages — updating entities, revising summaries, flagging contradictions, strengthening synthesis. **Knowledge compiles once and stays current.**

The wiki becomes a persistent, compounding artifact. Cross-references already exist. Contradictions are flagged. Synthesis reflects everything read. The wiki enriches with every source added.

**You source material and ask questions; the LLM maintains everything** — summarizing, cross-referencing, filing, organizing.

> *The LLM acts as programmer; Obsidian serves as IDE; the wiki functions as codebase.*

---

## Architecture — Three Layers

**Layer 1 — Raw sources** (`<wiki_root>/sources/` is *not* this layer in NanoClaw — see below)
Immutable curated documents (articles, papers, images, transcripts, voice notes). The LLM reads but never modifies. In NanoClaw, raw sources live at `/workspace/group/sources/` (per-group attachments and downloads).

**Layer 2 — The wiki** (`<wiki_root>/`)
LLM-generated markdown directories: summaries, entity pages, concept pages, comparisons, syntheses. The LLM owns this entirely — creating and updating pages while maintaining cross-references and consistency. *This is what `/add-second-brain` provisions.*

**Layer 3 — The schema** (`container/skills/wiki/SKILL.md`)
Configuration document explaining wiki structure, conventions, and workflows. **This file transforms the LLM into a disciplined wiki maintainer rather than a generic chatbot.**

---

## Operations

### Ingest

Drop new sources. The LLM reads, discusses takeaways, writes summaries, updates indexes, refreshes entity/concept/people pages, logs entries. Single source might touch 10–15 wiki pages.

**Critical: one source at a time.** Process completely (read → takeaways → source-summary → page updates → index → log → git commit), report back, *then* move to the next. Batching produces shallow generic pages and defeats the pattern.

### Query

Ask a question. LLM reads `index.md` first, drills into 3–5 most relevant pages, synthesizes with `[[wiki-links]]`. Good exploratory answers are filed back into the wiki as new pages — explorations compound rather than disappearing into chat history.

### Lint

Periodically (weekly default). Check: contradictions, stale claims, orphan pages, missing concept pages, broken cross-references, data gaps, duplicate entities, non-compliant frontmatter, stale sources >30 days. Report findings + metrics (pages added this week, top tags, broken links count).

---

## Indexing and Logging

**`index.md`** — content-oriented catalog of every page (link, one-line summary, source count), organized by category. Updated on every ingest. Read first when answering queries. Works surprisingly well at moderate scale (~hundreds of pages) without embedding-based RAG infrastructure.

**`log.md`** — append-only chronological record. Each entry: `## [YYYY-MM-DD] <op> | <title>` (op ∈ {ingest, query, lint, note, milestone, journal, digest, reflect, research}). Parseable with simple tools: `grep "^## \[" log.md | tail -10`.

**`essentials.md`** — quick session-start snapshot (~600 tokens). Active projects, key people, recent ingests, top entities, top concepts, statistics. Auto-updated on every ingest. Used as warm-start context when the agent boots.

**`tags.md`** — typed tag whitelist (`#DECISION`, `#PREFERENCE`, `#MILESTONE`, `#PROBLEM`, `#CONTACT`, `#ACTION`, `#INSIGHT`, `#WARNING`). Used inline in pages and in log entries.

**`inbox.md`** — quick captured thoughts not yet processed. Contributors append here; curator promotes to formal pages during morning brief or on demand.

---

## NanoClaw-Specific Extensions

These are operational additions on top of the bare Karpathy pattern, learned from production use:

### Curator vs Contributor roles

- **Curator** (typically `telegram_main`) — performs full ingest, owns structure, runs lint. Has read-write to all wiki layers.
- **Contributors** (sub-agents like `channel-promoter`, `partner-recruitment`, `client-profiler`) — read all, write to `inbox.md` and own `projects/<role>/` subdirectory. Cannot modify other contributors' work or restructure index.

### Inbox handoff

When a contributor writes to `inbox.md`, the curator's morning brief surfaces new entries. Curator decides: promote to formal page, dismiss, or leave for later.

### Git discipline

- Wiki has its own git repo (separate from main NanoClaw repo)
- `git pull --rebase` before commit (multi-machine safety)
- Commit on operation completion: `git add -A && git commit -m "<op>: <short title>"`
- `git push origin master 2>/dev/null || true` — non-blocking push to private remote backup

### Media stubs

Binary media (audio, video, images >1MB, PDF originals) are **NOT committed to git**. Instead, ingest creates a `.md` stub with metadata + path to local-only original. Keeps repo lean and pushable. PLAUD audio archives, video recordings stay on local disk only.

### Secrets guard

API keys, OAuth tokens, passwords are **never** put in wiki pages — even private repo. Use `onecli vault` for credentials. Pre-commit hook can scan for `sk-`, `pat-`, `token:` patterns.

### Obsidian as IDE

The wiki opens cleanly in Obsidian. `[[wiki-links]]` are followable. Graph view shows connectivity. Backlinks pane reveals what cites a page. Recommended plugins: Daily Notes, Templater, Dataview (for frontmatter queries).

---

## Why This Works

Knowledge base maintenance's tedious part is **bookkeeping**, not reading/thinking: cross-references, summaries currency, contradiction notes, consistency. Humans abandon wikis as maintenance burden outpaces value. **LLMs don't bore, don't forget updates, can touch 15 files in one pass.** Wiki maintenance becomes nearly free.

You curate sources, direct analysis, ask good questions, think about meaning. The LLM handles everything else.

This descends from Vannevar Bush's 1945 Memex — personal curated knowledge stores with associative document trails. Bush's vision resembled this more than what the web became: private, actively curated, with connections between documents as valuable as documents themselves. **Bush couldn't solve maintenance; LLMs handle that.**

---

## Optional: CLI Tools

At scale, search beyond `index.md` becomes necessary. [`qmd`](https://github.com/tobi/qmd) provides on-device hybrid search (BM25 + vector + LLM re-rank), available as CLI and MCP server.

For media-heavy wikis, build a per-source media-index (`media-index.json`) that catalogs binary stubs and enables fast image/video retrieval without scanning all files.

---

## Note

Directory structure, schema conventions, page formats, tooling — depend on domain, preferences, LLM choice. Everything is optional and modular. `/add-second-brain` provides one opinionated instantiation (Karpathy pattern + NanoClaw-specific extensions). Pick what's useful, override what isn't, evolve over time. The container skill v2 is meant to be edited as your practice matures.
