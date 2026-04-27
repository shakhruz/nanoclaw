# Scripts, Services, and Launchd

## Custom scripts

### `scripts/admin-ipc-daemon.js`

**Disposition:** rewrite for two-DB. See [05-admin-ipc.md](05-admin-ipc.md). Don't copy verbatim.

When rewritten, place in v2 at the same path: `~/nanoclaw/nanoclaw-v2/scripts/admin-ipc-daemon.js`. The launchd plist that runs it will move from v1 path to v2 path during stage 6.

### `scripts/sync-skills-all-groups.sh`

**Disposition:** review and likely retire. In v1 this synced agent-runner-src skills across group folders. v2 has shared agent-runner (no per-group overlays), so this script is obsolete.

If the script also syncs container skills or other artifacts, repurpose accordingly. Read the script content during stage 3 and decide.

### `scripts/telegram-ads-tasks-migration-2026-04-22.sh` + `scripts/telegram-ads-tasks-phase2-migration.sh`

**Disposition:** these are one-shot migration scripts already executed. Their `prompts/` subfolders contain the actual scheduled-task prompts (budget-alert, daily-snapshot, keepalive, weekly-report, monthly-healthcheck). 

Keep the **prompts/ contents** for reference — they describe scheduled tasks that need to be re-registered in v2's task scheduler. The shell scripts themselves can stay archived; not needed at runtime.

### `scripts/web-tasks-migration-2026-04-23.sh`

Same pattern. Its `prompts/` subfolder (channel-promoter-daily, domain-health, weekly-inventory) describes scheduled tasks to re-create in v2.

## Scheduled task re-registration

After stage 3 (data copy) completes, re-register all scheduled tasks in v2. The list, gleaned from migration-script prompts:

| Task | Group | Cadence | Source prompt |
|---|---|---|---|
| budget-alert | mila (or telegram-ads admin) | daily | `scripts/telegram-ads-tasks-migration-*/prompts/budget-alert.md` |
| daily-snapshot | mila | daily morning | `scripts/telegram-ads-tasks-migration-*/prompts/daily-snapshot.md` |
| keepalive | mila | per few hours | `keepalive.md` |
| weekly-report | mila | weekly | `weekly-report.md` |
| monthly-healthcheck | mila | monthly | `monthly-healthcheck.md` |
| channel-promoter-daily | news-curator | daily | `scripts/web-tasks-migration-*/prompts/channel-promoter-daily.md` |
| domain-health | web-admin | weekly | `domain-health.md` |
| weekly-inventory | web-admin | weekly | `weekly-inventory.md` |

In v2, scheduled tasks live in the central DB as recurring messages_in rows (kind=`recurring`, with a cron expr and series_id). The setup skill or `/manage-tasks` (if it exists) walks through registration. Otherwise direct SQL or a small bootstrap script.

## admin-panel/

`admin-panel/server.cjs` is a lightweight Node viewer for lead chats. It reads from v1's session DB.

**Disposition:** copy to v2, then update DB queries.

Copy:
```bash
cp -r ~/nanoclaw/nanoclaw/admin-panel ~/nanoclaw/nanoclaw-v2/admin-panel
```

Update server.cjs to query v2's per-session `outbound.db` files instead of v1's monolithic session DB. The viewer pattern (HTTP server reading SQLite, rendering HTML) is the same; only the SQL changes.

The npm script `"admin-panel": "node admin-panel/server.cjs"` should be added to v2's package.json (after `pnpm install` completes).

## launchd

### Pre-migration plist (v1)

`~/Library/LaunchAgents/com.nanoclaw.plist` currently points at `~/nanoclaw/nanoclaw`.

### During migration

Don't touch the plist until stage 6. v2 boots from its own working directory under launchctl during stage 6 cutover.

### Stage 6 plist edits

Update these keys:
- `WorkingDirectory` → `~/nanoclaw/nanoclaw-v2`
- `ProgramArguments` → adjust if program path changed (likely still `node` or `bun` + entrypoint)
- `EnvironmentVariables` → drop any `TELEGRAM_BOT_POOL`, `TELEGRAM_BOT_POOL_ROLES` (decision 1B); confirm OneCLI vault env entries

After edit:
```bash
launchctl unload ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl load ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl kickstart -k gui/$(id -u)/com.nanoclaw
```

### Separate admin-ipc-daemon plist

If `admin-ipc-daemon.js` runs under its own launchd agent (likely — it's the host-side polling daemon), update its plist similarly to point at v2 path. Find with:

```bash
ls ~/Library/LaunchAgents/ | grep -i nanoclaw
ls ~/Library/LaunchAgents/ | grep -i admin
```

## .github/workflows

`bump-version.yml` and `update-tokens.yml` were modified. These are CI workflows on the fork's GitHub repo. They run on the GitHub side, not affected by the migration. Verify after stage 6 that they still match new branch/path conventions.

## .gitignore

Modified to exclude `*.backup-*.md` skill backup artifacts. Carry this rule forward to v2 — append the line if not already present:

```
*.backup-*.md
```

## Telethon MCP server (telegram-scanner)

Not a script in the repo, but mentioned in the inventory. Runs on host port 3002. Used by `telegram-channel-publisher`, `telegram-ads-research`, `funnel-tester`, `ai-news-digest`.

**Disposition:** unchanged. The Python service runs independently of NanoClaw. Container code reaches it via `host.containers.internal:3002` (Apple Container) or `host.docker.internal:3002` (Docker).

Verify after stage 6 that the v2 containers can still reach port 3002. Apple Container's host networking is configured by `/convert-to-apple-container` skill in stage 2.
