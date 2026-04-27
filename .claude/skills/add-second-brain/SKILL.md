---
name: add-second-brain
description: Install a Karpathy-style second-brain wiki system on a NanoClaw install. Provisions directory scaffold, git + optional private GitHub backup, Obsidian config, container skill v2, CLAUDE.md pointer patches for curator + contributor groups, and weekly lint cron. Triggers on "add second brain", "install wiki", "set up second brain", "add knowledge base".
version: 1.0.0
---

# Add Second Brain

Install a persistent, Karpathy-style LLM Wiki on this NanoClaw install. Sets up the full opinionated stack:

- Directory scaffold (`sources/`, `concepts/`, `entities/`, `people/`, `projects/`, `journal/`, `comparisons/`, `media/`, `architecture/`)
- Seed files (`index.md`, `log.md`, `inbox.md`, `tags.md`, `essentials.md`)
- Git repo + optional private GitHub backup remote
- Obsidian vault config
- Container skill v2 (curator/contributor roles, git pull-rebase, media stubs, secrets guard)
- CLAUDE.md pointer patches for curator (main) and contributor (sub-agent) groups — replaces inline drift
- Weekly lint cron (Mon 09:00 Tashkent default)
- Morning-brief inbox-check hook (curator group)

Read `${CLAUDE_SKILL_DIR}/llm-wiki.md` first for the conceptual reference (Karpathy's pattern). Summarize to user briefly before proceeding.

---

## Phase 1: Pre-flight discovery

Use `AskUserQuestion` to collect parameters. Each has a sensible default.

1. **Wiki root path** (default: `groups/global/wiki/`) — relative to repo root. Shared global is recommended; group-local works too.
2. **Curator group folder** (default: detect group with `isMain=1` in `registered_groups`, fallback `telegram_main`) — the agent that performs full ingest and owns structure.
3. **Contributor group folders** (default: detect non-main, non-public registered groups) — agents that can read, write to inbox, and create role-scoped notes in `projects/<role>/`.
4. **Knowledge domain** (one short line, e.g. "personal second brain for Shakhruz: business + clients + AI research") — used to seed `essentials.md` and `index.md` placeholders.
5. **Obsidian config** (default: yes) — copies `.obsidian/` with graph + backlinks enabled.
6. **Private GitHub remote backup** (default: yes) — name pattern `<gh-username>-nanoclaw-wiki`. Detects existing repo and offers reconnect.
7. **Weekly lint cron** (default: yes, Mon 09:00 Tashkent) — scheduled task in curator group running container skill lint.

### Idempotency check

Before scaffolding, check if `<wiki_root>/index.md` already exists:

```bash
WIKI_ROOT="<answer>"
if [ -f "$WIKI_ROOT/index.md" ]; then
  echo "EXISTING_WIKI_DETECTED"
fi
```

If existing — switch to **upgrade mode**: skip Phase 2 (scaffold) and Phase 3 (git init), only update container skill (Phase 5), CLAUDE.md patches (Phase 6), morning-brief hook (Phase 7), media gitignore cleanup, scheduled lint (Phase 8). Tell the user explicitly: "Existing wiki detected — running upgrade mode, content untouched."

---

## Phase 2: Scaffold directory structure

```bash
WIKI_ROOT="<answer>"
SKILL_DIR="${CLAUDE_SKILL_DIR}"

mkdir -p "$WIKI_ROOT"/{sources,concepts,entities,people,projects,journal,comparisons,media,architecture}

# Top-level seed files
cp "$SKILL_DIR/templates/index.md"      "$WIKI_ROOT/index.md"
cp "$SKILL_DIR/templates/log.md"        "$WIKI_ROOT/log.md"
cp "$SKILL_DIR/templates/inbox.md"      "$WIKI_ROOT/inbox.md"
cp "$SKILL_DIR/templates/tags.md"       "$WIKI_ROOT/tags.md"
cp "$SKILL_DIR/templates/essentials.md" "$WIKI_ROOT/essentials.md"
cp "$SKILL_DIR/templates/.gitignore"    "$WIKI_ROOT/.gitignore"

# Subdir READMEs
for sub in journal sources concepts entities people projects; do
  cp "$SKILL_DIR/templates/$sub/README.md" "$WIKI_ROOT/$sub/README.md"
done
```

Stamp `essentials.md` with the user-provided domain line (find `<DOMAIN>` placeholder, replace).

---

## Phase 3: Git init + optional private GitHub remote

```bash
cd "$WIKI_ROOT"
git init -b main
git add -A
git commit -m "seed: initial wiki skeleton from /add-second-brain v1.0.0"
```

If user opted in to private remote backup (Phase 1 Q6):

```bash
# Verify gh CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
  echo "gh CLI not authenticated. Run: gh auth login. Skipping remote setup."
  exit 0
fi

GH_USER=$(gh api user --jq .login)
REPO_NAME="${GH_USER}-nanoclaw-wiki"  # configurable
REPO_FULL="${GH_USER}/${REPO_NAME}"

# Detect existing repo
if gh repo view "$REPO_FULL" --json name >/dev/null 2>&1; then
  # Existing repo — divergence handling
  echo "Existing repo $REPO_FULL detected. Archiving its current master as 'archive/pre-refactor-$(date +%Y-%m-%d)'."

  # Mirror current remote into archive branch
  TMP_DIR=$(mktemp -d)
  git -C "$TMP_DIR" clone --bare "https://github.com/$REPO_FULL.git" remote-snapshot.git
  ARCHIVE_BRANCH="archive/pre-refactor-$(date +%Y-%m-%d)"
  git -C "$TMP_DIR/remote-snapshot.git" push origin "HEAD:refs/heads/$ARCHIVE_BRANCH"
  rm -rf "$TMP_DIR"

  # Force-push local to remote master
  git remote add origin "https://github.com/$REPO_FULL.git"
  git branch -M main master
  git push -u origin master --force-with-lease
else
  # Fresh create
  gh repo create "$REPO_FULL" --private --source=. --remote=origin --push
fi
```

If remote opted out — skip silently, only local git.

If `gh` not installed/authenticated — print clear message + instructions to user, continue install without remote.

---

## Phase 4: Obsidian config (if opted in)

`.obsidian/` was copied in Phase 2. Verify three files exist: `app.json`, `appearance.json`, `workspace.json`. Tell the user: "Open `<wiki_root>` in Obsidian to use as a vault."

---

## Phase 5: Container skill v2

Backup current container skill, install v2:

```bash
CONTAINER_SKILL="container/skills/wiki/SKILL.md"
NEW_SKILL="${CLAUDE_SKILL_DIR}/templates/container-skill-wiki-v2.md"

if [ -f "$CONTAINER_SKILL" ]; then
  # Diff first, only backup if different
  if ! diff -q "$CONTAINER_SKILL" "$NEW_SKILL" >/dev/null; then
    cp "$CONTAINER_SKILL" "${CONTAINER_SKILL%.md}.v1.backup-$(date +%Y%m%d).md"
    cp "$NEW_SKILL" "$CONTAINER_SKILL"
    echo "Container skill updated to v2 (backup saved)."
  fi
else
  mkdir -p "$(dirname "$CONTAINER_SKILL")"
  cp "$NEW_SKILL" "$CONTAINER_SKILL"
fi
```

Container build is needed for changes to land — flag that for Phase 9.

---

## Phase 6: CLAUDE.md patches (DRY refactor)

For each group answered in Phase 1 (curator + contributors), patch its `groups/<folder>/CLAUDE.md`:

```bash
patch_claude_md() {
  local FOLDER="$1"
  local ROLE="$2"  # curator | contributor
  local CLAUDE_FILE="groups/$FOLDER/CLAUDE.md"
  local POINTER_FILE="${CLAUDE_SKILL_DIR}/templates/claude-md-${ROLE}.md"

  [ -f "$CLAUDE_FILE" ] || { echo "No CLAUDE.md in $FOLDER, skipping"; return; }

  # Find existing wiki section (anchor: "## Wiki" or "Wiki — Second Brain")
  # Replace block from "## Wiki" up to next "##" of same level with pointer content.
  # If no wiki section exists, append before "## Task Scripts" section, or at end.

  python3 - <<PYEOF
import re, sys, pathlib
claude = pathlib.Path("$CLAUDE_FILE")
pointer = pathlib.Path("$POINTER_FILE").read_text()
text = claude.read_text()

# Substitute <WIKI_ROOT> placeholder in pointer
pointer = pointer.replace("<WIKI_ROOT>", "$WIKI_ROOT")

# Match existing wiki section: from heading containing 'Wiki' up to next H2 or EOF
pattern = re.compile(r"^(##+ .*[Ww]iki[^\n]*\n)(.*?)(?=^##\s|\Z)", re.MULTILINE | re.DOTALL)
if pattern.search(text):
    text = pattern.sub(pointer + "\n", text)
else:
    # Append before '## Task Scripts' or at end
    if "## Task Scripts" in text:
        text = text.replace("## Task Scripts", pointer + "\n---\n\n## Task Scripts")
    else:
        text = text.rstrip() + "\n\n---\n\n" + pointer + "\n"

claude.write_text(text)
print(f"Patched {claude}")
PYEOF
}

# Curator
patch_claude_md "<curator_folder>" "curator"

# Contributors (loop)
for f in <contributor_folders>; do
  patch_claude_md "$f" "contributor"
done
```

Result: 97-line inline blocks in main CLAUDE.md and 24-line stubs in sub-agents are replaced with compact pointer blocks. Single source of truth = `container/skills/wiki/SKILL.md` (v2).

---

## Phase 7: Morning-brief inbox-check hook

For curator group only — find `groups/<curator_folder>/skills/morning-brief/SKILL.md` and add an inbox-check step after the existing brief sections (just before final delivery formatting). Append section:

```markdown

---

## Wiki Inbox Check (added by /add-second-brain)

Read `<WIKI_ROOT>/inbox.md`. If there are new entries since yesterday's brief (compare timestamps or simply note all current entries), include in the brief:

```
📥 *Wiki Inbox* (N new)
• [DATE] short note...
• [DATE] short note...

→ Хочешь чтобы я ingestнула эти заметки в wiki?
```

If inbox is empty or unchanged — skip this section silently.
```

If `morning-brief` skill doesn't exist for the curator — skip this phase, log a notice.

---

## Phase 8: Scheduled lint task

If user opted in (Phase 1 Q7):

Locate curator group's chat JID:

```bash
CURATOR_JID=$(sqlite3 store/messages.db "SELECT jid FROM registered_groups WHERE folder='<curator_folder>'")
```

Insert scheduled task via SQLite (the `mcp__nanoclaw__schedule_task` MCP is preferred when available; SQLite insert is fallback):

```bash
npx tsx -e "
const Database = require('better-sqlite3');
const { CronExpressionParser } = require('cron-parser');
const db = new Database('store/messages.db');
const cron = '0 9 * * 1';  // Mon 09:00
const tz = 'Asia/Tashkent';
const interval = CronExpressionParser.parse(cron, { tz });
const nextRun = interval.next().toISOString();
db.prepare(\`
  INSERT OR REPLACE INTO scheduled_tasks
  (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, context_mode, next_run, status, created_at)
  VALUES (?, ?, ?, ?, 'cron', ?, 'group', ?, 'active', ?)
\`).run(
  'wiki-lint-weekly',
  '<curator_folder>',
  '$CURATOR_JID',
  \`Запусти wiki lint по container skill /app/container/skills/wiki/SKILL.md.

Выполни 7 проверок:
1. Dead [[wiki-links]] — ссылки на несуществующие страницы
2. Orphan pages — страницы без входящих ссылок
3. Non-compliant frontmatter — отсутствующие/неверные поля
4. Sources без back-references — sources/ страницы которые никто не цитирует
5. Tag graph integrity — теги не из tags.md whitelist
6. Duplicate entities — fuzzy match по названию
7. Stale sources — sources/ страницы старше 30 дней без updates

Затем выведи metrics:
- +N новых страниц за неделю
- Top-5 активных тегов
- Stale sources >30 дней (count + список)
- Unreferenced pages
- Broken links

Финальный отчёт → send_message в чат + сохрани в <WIKI_ROOT>/lint-reports/YYYY-MM-DD.md (создай папку если нет)\`,
  cron,
  nextRun,
  new Date().toISOString()
);
db.close();
console.log('Scheduled wiki-lint-weekly task');
"
```

---

## Phase 9: Build, summary, verify

If container skill changed (Phase 5), tell user to rebuild container:

```bash
./container/build.sh
launchctl kickstart -k gui/$(id -u)/com.nanoclaw  # macOS
# Linux: systemctl --user restart nanoclaw
```

Print install summary:

```
✅ Second Brain installed at <WIKI_ROOT>

Created:
- 9 directories (sources, concepts, entities, people, projects, journal, comparisons, media, architecture)
- 5 seed files (index, log, inbox, tags, essentials)
- 6 subdir READMEs
- .gitignore (binary media excluded)
- .obsidian/ vault config (if enabled)

Git:
- Initialized at <WIKI_ROOT>
- Remote: <github-url> (if enabled)
- First commit: 'seed: initial wiki skeleton...'

Patches:
- container/skills/wiki/SKILL.md → v2 (curator/contributor, git pull-rebase, media stubs, secrets guard)
- groups/<curator>/CLAUDE.md → curator pointer block
- groups/<contributor>/CLAUDE.md (×N) → contributor pointer blocks
- groups/<curator>/skills/morning-brief → inbox-check hook (if applicable)

Scheduled:
- wiki-lint-weekly: Mon 09:00 Tashkent (if enabled)

Next steps:
1. Rebuild container: ./container/build.sh && launchctl kickstart -k gui/$(id -u)/com.nanoclaw
2. Test: send a source to the curator group, confirm Mila ingests it
3. Open <WIKI_ROOT> in Obsidian to navigate the vault visually
4. Read the Karpathy pattern reference: ${CLAUDE_SKILL_DIR}/llm-wiki.md
```

Sanity check — confirm critical files:

```bash
test -f "$WIKI_ROOT/index.md" || echo "WARN: index.md missing"
test -d "$WIKI_ROOT/.git"     || echo "WARN: git not initialized"
grep -q "container/skills/wiki/SKILL.md" "groups/$CURATOR_FOLDER/CLAUDE.md" || echo "WARN: curator pointer not patched"
```

---

## Removal

To uninstall:

1. Restore old container skill: `mv container/skills/wiki/SKILL.v1.backup-*.md container/skills/wiki/SKILL.md`
2. Restore CLAUDE.md from git: `git checkout HEAD -- groups/<each>/CLAUDE.md`
3. Delete scheduled lint: `sqlite3 store/messages.db "DELETE FROM scheduled_tasks WHERE id='wiki-lint-weekly'"`
4. Wiki content stays — delete manually if desired: `rm -rf <WIKI_ROOT>` (or just `git remote remove origin` to keep local)
5. Rebuild container

The wiki content itself is left intact by `/add-second-brain` removal — too valuable to auto-delete.

---

## Troubleshooting

**`gh: command not found`** → install GitHub CLI (`brew install gh`), then `gh auth login`. Re-run skill.

**Force-push refused (`--force-with-lease`)** → remote was modified after archive snapshot. Pull, resolve, retry. If you're certain remote is stale: `git push -u origin master --force` (without `--with-lease`).

**Container skill changes not picked up by Mila** → forgot to rebuild. `./container/build.sh && launchctl kickstart -k gui/$(id -u)/com.nanoclaw`. The build cache is aggressive — if changes still don't land, prune builder cache (see CLAUDE.md "Container Build Cache").

**Pointer patch destroyed wrong section** → restore: `git checkout HEAD -- groups/<folder>/CLAUDE.md`. The python regex looks for headings containing "Wiki" — if your CLAUDE.md has a different heading style, adjust manually.

**Mila still uses old wiki path** → check `groups/<folder>/CLAUDE.md` and `container/skills/wiki/SKILL.md` reference the new `<WIKI_ROOT>`. Old setups had `/workspace/group/wiki/`; v2 default is `/workspace/global/wiki/`.
