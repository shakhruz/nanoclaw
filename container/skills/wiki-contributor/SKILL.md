---
name: wiki-contributor
description: Contribute to the shared second-brain wiki as a sub-agent. Use when you want to drop a quick note into the shared inbox, or create a role-scoped page under projects/<your-role>/. Read-only everywhere else — curator (main) owns structure.
version: 1.0.0
---

# Wiki Contributor — sub-agent write access to the shared wiki

You are a **contributor** to the shared wiki at `/workspace/global/wiki/`. The wiki is the user's second brain, owned and structured by the **curator** (main agent). You have a narrow, safe surface for writes:

- ✅ Append to `/workspace/global/wiki/inbox.md` — short notes, observations, mentions
- ✅ Create pages under `/workspace/global/wiki/projects/<your-role>/` — your role's own workspace
- ❌ Never touch `index.md`, `log.md`, `essentials.md`, `tags.md` (curator-only)
- ❌ Never edit other roles' subdirectories under `projects/`
- ❌ Never touch `people/`, `entities/`, `concepts/`, `sources/` root — route via inbox

Your role is read from `$NANOCLAW_GROUP` (e.g. `telegram_channel-promoter`). Your own subdir is `projects/<role-slug>/` where the slug is the group folder stripped of the `telegram_` prefix (so `telegram_channel-promoter` → `projects/channel-promoter/`).

---

## When to use this skill

**Use it when:**
- You notice something in your role-work (a new competitor, a campaign insight, a lead segment) that the curator should know about → drop into `inbox.md`
- You want to keep a working note for your own role (draft, research log, checklist) → create under `projects/<your-role>/`
- You've finished a piece of research you want to share across agents → inbox first; let the curator promote it to a formal page

**Do NOT use it for:**
- Modifying shared pages (index, log, essentials, tags, or any root `concepts/entities/people/sources/` page) — these are curator-only and the pre-commit hook will reject your commit
- Long-term storage of role-private data — your group's own `/workspace/group/` is the right place for that
- Quick throwaways that aren't worth the curator's attention — those belong in your group folder's own notes, not the shared inbox

---

## Two operations

### 1. Drop a note into the shared inbox

Append one line to `/workspace/global/wiki/inbox.md`:

```bash
cd /workspace/global/wiki
git pull --rebase 2>/dev/null || true
TS=$(date +"%Y-%m-%d %H:%M")
ROLE="${NANOCLAW_GROUP#telegram_}"
echo "- [$TS] [${ROLE}] <your note here>" >> inbox.md
git add inbox.md
git commit -m "inbox(${ROLE}): <short summary>"
git push origin master 2>/dev/null || true
```

**Rules for inbox entries:**
- One line. If it needs more than one sentence, it's a page, not an inbox note.
- Prefix with `[<role>]` (the skill-provided template does this) so the curator can triage.
- Mention concrete entities in `[[wiki-links]]` form if they already exist — helps the curator wire it up during promotion.
- No secrets. See the secrets guard in the main `wiki` skill — same rules apply.

### 2. Create or update a role-scoped page

Write to `/workspace/global/wiki/projects/<your-role>/<page-slug>.md`. Create the subdirectory on first use.

```bash
cd /workspace/global/wiki
git pull --rebase 2>/dev/null || true
ROLE="${NANOCLAW_GROUP#telegram_}"
mkdir -p "projects/${ROLE}"

# Write the file (use Write tool for the body; frontmatter is mandatory)
# Required frontmatter:
#   title, type (project | note | research-log), created, updated,
#   sources: [], related: [], tags: [], confidence: (high|medium|low)

git add "projects/${ROLE}/<slug>.md"
git commit -m "note(${ROLE}): <short title>"
git push origin master 2>/dev/null || true
```

**Rules for role-scoped pages:**
- Filename is `kebab-case.md`.
- Frontmatter is mandatory — the curator's lint will flag pages that miss it.
- Cross-link both directions with `[[wiki-links]]` when you reference other pages.
- Tags must come from `/workspace/global/wiki/tags.md` whitelist. If you need a new tag, drop a note in inbox asking the curator to whitelist it.

---

## Before every write — pull rebase

The wiki is shared across machines and agents. Always:

```bash
cd /workspace/global/wiki && git pull --rebase 2>/dev/null || true
```

If the rebase has conflicts, **stop**. Don't auto-resolve. Report to the user via `mcp__nanoclaw__send_message` that there's a wiki conflict and let the curator sort it out.

---

## What happens if you write where you shouldn't

The wiki repo has a **pre-commit hook** that checks `$NANOCLAW_GROUP` + `$NANOCLAW_ROLE`. If you (as a contributor) try to commit changes to curator-only paths, the commit aborts with a clear message. You'll need to:

1. `git reset HEAD <file>` the disallowed change
2. `git checkout -- <file>` to revert your working copy
3. Re-route the intent through `inbox.md` instead

Don't try to bypass the hook with `--no-verify`. It's a safety net, not a nuisance.

---

## Reading the wiki

You have **full read access** to every file under `/workspace/global/wiki/`. Use it:

1. **Start queries with `index.md`** — that's the catalog.
2. **Drill into 3-5 relevant pages** from there.
3. **Fallback to grep** if the index doesn't cover your topic:
   ```bash
   grep -r "<keywords>" /workspace/global/wiki/ | head -20
   ```
4. Don't re-derive knowledge from scratch — the curator has already compiled it. If you find gaps, drop an inbox note asking the curator to fill them in.

---

## Quick reference — helper script

A convenience helper is available at `${CLAUDE_SKILL_DIR}/wiki-contributor.sh`:

```bash
# Append to inbox
${CLAUDE_SKILL_DIR}/wiki-contributor.sh inbox "Campaign X is outperforming Y by 40% CTR"

# Create a role-scoped page
${CLAUDE_SKILL_DIR}/wiki-contributor.sh page growth-experiments-apr <<'MD'
---
title: Growth experiments April 2026
type: project
created: 2026-04-22
updated: 2026-04-22
sources: []
related: []
tags: []
confidence: medium
---

Body of the page...
MD
```

The helper handles pull-rebase, role detection, path validation, commit message formatting, and push. Use it for common cases; drop to manual bash for anything custom.
