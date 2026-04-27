# Migration Plan

## Strategy: sibling-clone with manual swap

The fork is too divergent for in-place upgrade. Use `migrate-v2.sh` from `upstream/migrate/v1-to-v2`:

```bash
cd ~/nanoclaw
git -C nanoclaw fetch upstream migrate/v1-to-v2
git -C nanoclaw show upstream/migrate/v1-to-v2:migrate-v2.sh > /tmp/migrate-v2.sh
bash /tmp/migrate-v2.sh ~/nanoclaw/nanoclaw
# creates sibling ~/nanoclaw/nanoclaw-v2 with clean v2 + copied data
```

v1 stays untouched until manual swap of `launchctl` to the new tree.

## Staging

The migration runs in 6 stages. Validate each before proceeding.

### Stage 1: bootstrap clean v2 (sibling clone)

1. Run `migrate-v2.sh` — creates `~/nanoclaw/nanoclaw-v2`, `pnpm install`, central DB seeded.
2. Symlink data dirs from v1 read-only for the validation phase. **Do NOT yet copy `groups/` or `.env`** — first verify clean v2 boots.
3. `bash nanoclaw.sh` walks through OneCLI auth, container build, first agent. Use a throwaway test agent at this stage, not Mila.
4. Verify: send a test message via the bundled CLI channel, get a reply. If yes, stage 1 done.

### Stage 2: install Apple Container + base skills

User decisions: keep Apple Container.

```
/convert-to-apple-container    # opt-in in v2; restores macOS-native runtime
/add-telegram                  # from upstream channels branch
```

Skip: `/add-gmail` (not yet shipped, decision 2), `/add-whatsapp` (not in active use), `/add-discord`, `/add-slack`.

Verify: pair a single test Telegram bot, send `@TestBot ping`, get a reply.

### Stage 3: bring in data and credentials

1. Copy `~/nanoclaw/nanoclaw/groups/` → `~/nanoclaw/nanoclaw-v2/groups/` (verbatim).
2. Migrate credentials to OneCLI vault (decision 3 — see [09-credentials.md](09-credentials.md)). Most are already in vault on v1.
3. Copy custom container skills: `~/nanoclaw/nanoclaw/container/skills/` → `~/nanoclaw/nanoclaw-v2/container/skills/` (71 skills, see [06-container-skills.md](06-container-skills.md)).
4. Copy `admin-panel/`, custom `scripts/` (see [08-scripts-services.md](08-scripts-services.md)).

Verify: `ls groups/` matches v1, OneCLI lists all expected secrets, container builds with new skills baked in.

### Stage 4: register channels and wire entity model

Per [07-groups.md](07-groups.md), create the agent groups and messaging groups in v2's central DB. Order:

1. Create Mila agent group (shared workspace).
2. Create each specialist agent group (telegram_octo, telegram_main, telegram_ashotai-experts, telegram_channel-promoter, telegram_client-profiler, telegram_inbox, telegram_instagram, telegram_partner-recruitment, telegram_youtube-manager).
3. Create lead-handler agent group (per-thread).
4. Wire each Telegram chat to the right agent_group via `messaging_group_agents`.
5. Create agent-to-agent destinations: every specialist ↔ Mila bidirectional; specialists ↔ each other only where current CLAUDE.md implies coordination (telegram_octo wave-based orchestration, telegram_main team).

Verify: send a message to one of the specialist chats, confirm the right agent group's container wakes up, response is delivered.

### Stage 5: port admin-IPC to two-DB

Decision 3: rewrite immediately. See [05-admin-ipc.md](05-admin-ipc.md). This is the highest-risk step.

1. Add `admin_ipc_requests` and `admin_ipc_responses` tables to inbound.db / outbound.db schema (or use existing `messages_in` / `messages_out` with a `kind='admin_ipc_request'`).
2. Rewrite `scripts/admin-ipc-daemon.js` to subscribe to inbound DB rows instead of polling files.
3. Rewrite Telegram callback_query handler to write decisions to inbound.db instead of `groups/global/admin-ipc/decisions/`.
4. Update container skill `admin-ipc/SKILL.md` (the agent-side helper) to use new MCP tool instead of file write.
5. Add executor registry for auto-approve actions (ping, web_publish, web_deploy, copy_file, install_skills, render tasks).

Verify: have a sub-agent issue `request_admin_decision('ping', {...})` from a test conversation; daemon receives it, auto-executes ping, writes response, sub-agent reads it back.

### Stage 6: full cutover

1. Stop v1 service: `launchctl unload ~/Library/LaunchAgents/com.nanoclaw.plist`
2. Update plist `WorkingDirectory` and `ProgramArguments` paths to v2 tree.
3. `launchctl load ~/Library/LaunchAgents/com.nanoclaw.plist`
4. Send live test message from primary Telegram chat, confirm full pipeline.
5. Watch logs for 30 minutes. If healthy, archive `~/nanoclaw/nanoclaw` (rename to `nanoclaw-v1-archived-2026-04-27`). If broken, swap launchd back to v1 path; v1 untouched.

## Risk areas

| Area | Risk | Mitigation |
|---|---|---|
| Admin-IPC rewrite | Behaviour change in human-approval pipeline could halt all sub-agent operations | Stage 5 isolated from cutover; test exhaustively before Stage 6 |
| `tg_lead-*` per-thread mapping | Existing 3 lead chats need to find their session under v2's per-thread model | Pre-populate `messaging_groups.thread_id` rows from v1 group folder names |
| Container skill paths | Some skills reference `/workspace/global/admin-ipc/...` directly | Audit container/skills/admin-ipc/, telegram-ads-*, web-* — search for hardcoded paths |
| OneCLI vault | If migration loses an env mapping, integrations break silently | Compare `onecli list` before and after Stage 3; manually re-add any missing |
| 18 groups CLAUDE.md | Composed CLAUDE.md in v2 (shared base + per-group fragments) is a different system | Keep group-specific CLAUDE.md as fragments; let v2 inject the shared base |

## Rollback

At every stage, v1 is intact and runnable. Roll back is `launchctl unload` v2 + `launchctl load` v1's original plist.

The pre-migration WIP commit is `fa905f35` on branch `main`. Tag will be created in Phase 2.
