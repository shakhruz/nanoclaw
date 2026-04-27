# Skill Interactions and Conflicts

Notes on inter-skill dependencies and known points of friction. Address these during stage 4–5 when wiring everything together.

## Known interactions

### `add-compact` ↔ session model

`add-compact` adds a `/compact` slash command that drops conversation history except a final summary. It depends on the agent-runner's session-id plumbing forwarding `newSessionId` after compaction.

**v2 risk:** v2's session-manager.ts is a rewrite (`src/session-manager.ts`, +398 LOC per inventory). Session ID handling may have changed. After stage 1 install:

1. Check whether `/compact` works natively. If yes, drop `add-compact` entirely.
2. If `/compact` doesn't exist but the SDK supports it, the v1 patch in `src/session-commands.ts` may be portable. Read v2's `session-manager.ts` first — port only if v2 has the necessary hooks.

### `channel-formatting` ↔ v2 channel adapters

v1's formatting layer ran in `formatOutbound()` host-side, channel-name-aware. v2 channels in the `channels` branch each have their own outbound formatting (per `docs/architecture.md` mention of platform capability differences).

**Risk:** double-sanitization (host strips formatting, then v2 channel re-applies its own logic). Or under-sanitization (v2 channel doesn't handle a case v1 did, e.g. `**bold**` → `*bold*` for Telegram).

**Action after stage 2 install:** send formatted test messages and visually check rendering. Apply `text-styles.ts` patch from v1 only if a regression appears.

### `add-second-brain` ↔ wiki container skill ↔ multi-agent routing

The wiki has two roles: curator (full write access) and contributor (sandbox-restricted). v1 enforced this via filesystem ACLs and pre-commit hooks.

**v2 plan:**
- Curator role: Mila (`groups/main/`) with full write to `groups/main/wiki/`.
- Contributor role: each specialist agent group has a `wiki-contributor` container skill loaded.
- Specialists access wiki via mounting `groups/main/wiki/` read-only, plus their own `groups/main/wiki/projects/<role>/` mounted read-write.

**Mount configuration:** v2 uses `/manage-mounts` skill to wire per-agent mounts. Set up read-only and per-role read-write mounts in stage 4.

### `add-reactions` ↔ Telegram inline-button handler ↔ admin-IPC callback parsing

If `add-reactions` is ever revived for Telegram, both reactions and admin-IPC use the `callback_query` handler. They must coexist without prefix collision.

Currently: admin-IPC uses `data` prefix `admin:`. Reactions (if added) should use `react:` or similar. **Document any new prefix here when added.**

### Telegram channel ↔ admin-IPC ↔ Telegram-scanner MCP

Three distinct Telegram-related code paths:
1. Main bot polling (v2 channel adapter): user messages, callback_query for admin decisions
2. Telegram-scanner MCP (host service, port 3002): userbot for publishing, large-file MTProto fallback, channel scraping
3. (Removed) Bot pool: was the swarm UX

After decision 1B, only paths 1 and 2 remain. They share the bot-side identity (`@AshotMila` or whatever the main bot is) for path 1, and a userbot account (`@ashot_ashirov_ai` per inventory) for path 2. No conflict — different accounts.

### OctoFunnel ↔ admin-IPC

`octofunnel-access` parks login-needed events in admin-IPC's `needs-claude/` queue (v1) or `needs_human` queue (v2). When admin resolves, the agent retries OctoFunnel ops.

**v2 carryover:** preserve the `needs_human` parking semantics. The action `octofunnel_login_needed` should remain in the executor's "needs-claude" classification (no auto-execution, no Telegram inline buttons; instead, a notification telling the admin to run a manual login flow).

### Web skills ↔ admin-IPC ↔ web-deploy gating

`web-deploy` is restricted to the `mila` (formerly `main`) agent group. Specialists request via admin-IPC.

**v2 enforcement:** the `web-deploy` action handler in admin-ipc-daemon checks `requesting_group` on the inbound row. If `requesting_group != 'mila'`, it auto-approves the request and runs deploy; if other agents (specialists) request, escalate to human.

Currently in v1 daemon: `web_deploy` is in the `auto: true` set. Adjust during stage 5 rewrite to gate on `requesting_group`.

### Lead-handler per-thread sessions ↔ wiki for leads

Each lead thread has its own session. The lead's history (notes, context, prior conversations) needs to be accessible from the agent.

**Plan:** put per-lead notes in `groups/lead-handler/leads/<thread_id>/wiki.md`. The lead-handler's CLAUDE.md instructs the agent to read this file at session start. New leads start with an empty file (or a template).

For migrating existing leads: each `tg_lead-*/CLAUDE.md` and any conversation history goes into `groups/lead-handler/leads/<thread_id>/`.

## Dedup / conflict scan checklist

Run after stage 5, before stage 6:

- [ ] Search `src/` and `scripts/` for any remaining `groups/global/admin-ipc/` filesystem references. Should be zero.
- [ ] Search `groups/*/CLAUDE.md` for references to `TELEGRAM_BOT_POOL` or `sender:` parameter. Strip them.
- [ ] Verify `src/channels/telegram.ts` has exactly one `callback_query` handler with all sub-handlers (`admin:` prefix, possibly future `react:` prefix) chained.
- [ ] Confirm no `agent-runner-src/` references remain in any group folder.
- [ ] Check for `package.json` deps that became orphaned: `sharp`, `openai`, `@composio/core` (if not used elsewhere). Remove orphans.
- [ ] Run `pnpm install && pnpm build` cleanly in the v2 worktree before stage 6 cutover.

## Surprise drawer

Things this guide can't fully predict — note them as discovered during the migration:

- _(empty for now; populate during execution if surprises appear)_
