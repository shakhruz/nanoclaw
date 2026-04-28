---
name: wiki-contributor
description: Contribute observations to the shared second-brain wiki as a sub-agent. In v2, contributors don't write directly — they send notes to the curator via agent-to-agent messaging, and the curator promotes them into the wiki during ingest.
version: 2.0.0
---

# Wiki Contributor — v2 a2a-write pattern

You are a **contributor** to the shared wiki at `/workspace/global/wiki/`. The wiki is the user's second brain, owned and structured by the **curator** (typically the main agent — Mila). In NanoClaw v2 your write path is via agent-to-agent messaging, not direct filesystem writes.

## Why a2a (not direct writes)

In v2, sub-agents are spawned via `create_agent` and live in their own per-role agent groups. The shared wiki is mounted read-only into your container — direct writes physically can't happen. Instead:

- ✅ You **read** the wiki freely at `/workspace/global/wiki/`
- ✅ You **send notes** to the curator via `send_message(to="parent", channel="agent", text="<note>")` — the curator triages and writes
- ✅ Use a `[wiki-inbox]` or `[wiki-promote]` tag in your message text so the curator routes it correctly
- ❌ Don't try `echo >> wiki/inbox.md` — the mount is RO, the write fails silently or with permission denied
- ❌ Don't try `git add / commit` on `/workspace/global/wiki/` — same reason

## When to send a wiki note

**Send to curator when:**
- You found something during your role-work that should outlive this conversation (a competitor insight, a campaign result, a lead segment pattern)
- You want a shared page about a domain you're researching (so other roles benefit later)
- You've completed a piece of work and want it documented as a project artifact

**Don't bother the curator when:**
- It's a private working note for your own role only — write to `/workspace/agent/` (your own folder, RW)
- It's a draft you may discard — keep in your session memory
- It's already known content you can reference by `[[wiki-link]]`

## The two patterns

### Pattern 1: drop a note in the inbox

```
send_message({
  to: "parent",
  channel: "agent",
  text: "[wiki-inbox] [marketolog] Tier-2 turfirmy — средний чек 2-5M UZS, цикл 7-14 дней. Source: Apify scrape 2026-04-28."
})
```

The curator appends one-liners to `/workspace/global/wiki/inbox.md`. They get processed in the next morning brief / ingest pass into formal pages.

**Rules:**
- One sentence per inbox entry. If it's longer, it's a page request.
- Prefix with `[wiki-inbox] [<your-role>]` so the curator triages by role.
- Mention `[[entities/...]]` or `[[concepts/...]]` if you're touching existing pages — helps curator wire up cross-references.
- Cite source briefly (URL, file, conversation ID).

### Pattern 2: request a full page

```
send_message({
  to: "parent",
  channel: "agent",
  text: """
[wiki-promote] [marketolog] [project: octofunnel-instagram-2026-q2]

Title: OctoFunnel × Instagram кампания Q2 2026

Body:
<full content here, with frontmatter if you want — curator may adjust>
- Цель: 50 leads/день при CPL ≤ $4
- Аудитория: 5 ниш в центре Ташкента, Tier-1 (beauty + туризм) + Tier-2 (стоматология / учебные / недвижимость)
- KPI: ...
- Risks: ...

Sources: <urls / file paths>
Suggested path: projects/marketing/octofunnel-instagram-2026-q2.md
"""
})
```

The curator writes the full page (maybe with edits) and reports back via `<message to="<your-role>">page created at <path>` so you have a citable reference.

## Reading the wiki

You have full read access via `/workspace/global/wiki/`:

1. **Start with `index.md`** — that's the catalog of everything.
2. **Drill into 3–5 relevant pages** from there based on your task domain.
3. **Fallback to grep** if the index doesn't cover your topic:
   ```bash
   grep -r "<keywords>" /workspace/global/wiki/ | head -20
   ```
4. **Don't re-derive what's compiled** — if the curator already wrote about a client, a brand, an offer — cite the page, don't rewrite it from sources.

## Anti-patterns

- ❌ Trying to write to `/workspace/global/wiki/` directly (RO).
- ❌ Bypassing the curator and writing to your own `/workspace/agent/` and calling that "wiki" — the curator can't see it, other roles can't see it. If it should be shared, route through curator.
- ❌ Long inbox notes — promote those to full pages via Pattern 2.
- ❌ Storing secrets in any wiki content — same security rule as the curator's `wiki` skill.

## Curator's side (informational)

When the curator (Mila) receives a `[wiki-inbox]` or `[wiki-promote]` a2a message, they:

1. Validate the proposed content (no secrets, no bad facts)
2. For inbox: append the one-liner to `inbox.md`, possibly add a wiki-link if they're already in the area.
3. For promote: write the page at the suggested path (or a better one), commit, send back a confirmation with the final path.

You'll see the confirmation as an a2a follow-up — that's your signal the note made it in. If you don't see one within a minute or two, the curator either rejected it (you'd see why) or is busy — assume it's queued.
