# NanoClaw v1 → v2 Migration Guide (Tier 3)

**Generated:** 2026-04-27
**Base (merge-base with upstream):** `934f063a` (commit `934f063aff5c30e7b49ce58b53b41901d3472a3e`)
**HEAD at generation:** `fa905f35` (commit `fa905f35b8a685a93a0cd7be1e6fd6eae766ba36`)
**Upstream target:** `f8c3d023` (`upstream/main` at v2.0.14, fetched 2026-04-27)
**Strategy:** sibling-clone via `bash migrate-v2.sh ~/nanoclaw/nanoclaw` (data preserved, v1 untouched until manual swap)

## Scope

- 172 user commits ahead of base
- 460 upstream commits ahead — v2 is an architectural rewrite
- 18 groups, 71 container skills, 10 custom feature-skills, 2 upstream skill merges (`compact`, `apple-container`)
- ~26k LOC of customization (telegram channel +1217, container-runner +300, gmail +364, admin-IPC pipeline ~+250)

## Decisions (locked-in by user 2026-04-27)

| # | Decision | Effect |
|---|---|---|
| 1 | Swarm UX → **v2-native agent-to-agent** (no multi-bot pool) | Drop `add-telegram-swarm`. Mila orchestrates via `src/modules/agent-to-agent`. Specialists are separate `agent_groups`, communicate via DB destinations. |
| 2 | Gmail → **wait for upstream skill** | Drop custom `src/channels/gmail.ts` and `add-gmail` skill. Resume Gmail when `upstream/channels` ships it. |
| 3 | Admin-IPC → **rewrite on two-DB model** | Port `requests/decisions/responses/` file pipeline to `inbound.db`/`outbound.db` rows immediately, not later. |
| 4 | Group isolation → **mixed model**: Mila-shared / specialist per-agent / leads per-thread | See [07-groups.md](07-groups.md). |

## Files

| File | Purpose |
|---|---|
| [00-plan.md](00-plan.md) | Migration plan: ordering, staging, risk areas |
| [01-applied-skills.md](01-applied-skills.md) | Upstream skill branches re-merged (`compact`, `apple-container`) |
| [02-custom-skills.md](02-custom-skills.md) | 10 user-authored `.claude/skills/*` — drop / port / re-test |
| [03-channels.md](03-channels.md) | Telegram channel customizations to retain (minus swarm + gmail) |
| [04-orchestrator.md](04-orchestrator.md) | Mila-as-orchestrator design on v2 agent-to-agent |
| [05-admin-ipc.md](05-admin-ipc.md) | File-IPC → DB-IPC rewrite |
| [06-container-skills.md](06-container-skills.md) | 71 container skills inventory + copy plan |
| [07-groups.md](07-groups.md) | 18 groups → v2 entity model mapping |
| [08-scripts-services.md](08-scripts-services.md) | admin-ipc-daemon, admin-panel, migration scripts, launchd |
| [09-credentials.md](09-credentials.md) | OneCLI vault entries, env vars, Composio MCP |
| [10-skill-interactions.md](10-skill-interactions.md) | Inter-skill conflicts and dedup notes |

## Source-of-truth principle

This guide is the source of truth for the migration, not git diffs. If a code snippet here disagrees with the live v1 tree, treat the live tree as canonical and update this guide before proceeding. Re-extract via `/migrate-nanoclaw` if the gap is significant.
