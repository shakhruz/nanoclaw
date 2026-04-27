# Mila-as-Orchestrator on v2 agent-to-agent

Decision 1B: drop multi-bot pool, build the swarm on v2's native `src/modules/agent-to-agent/` module. This file describes how the orchestration model maps onto v2's entity model.

## Concept

```
                       ┌─────────────────────────────────┐
                       │   Telegram chat (one bot face)  │
                       └────────────────┬────────────────┘
                                        │
                                        ▼
                       ┌──────────────────────────────────┐
                       │   Mila (agent_group: "mila")     │
                       │   Director / Orchestrator        │
                       └──┬───────────┬───────────┬───────┘
                          │           │           │           ...
              a2a routing │ a2a       │ a2a       │ a2a
                          ▼           ▼           ▼
                   ┌────────────┐ ┌────────────┐ ┌────────────┐
                   │ Маркетолог │ │ Дизайнер   │ │ Копирайтер │  …
                   │ agent_group│ │ agent_group│ │ agent_group│
                   └────────────┘ └────────────┘ └────────────┘
                          ▲           ▲           ▲
                          │           │           │
                          └───── a2a ─┴───── a2a ─┘
                          (specialists may DM each other when wave-orchestrated)
```

## Entity model

### `agent_groups`

Each row = one specialist or director. Folder under `groups/<name>/`. Has its own CLAUDE.md, optional `skills/`, optional wiki pointer, container with shared agent-runner.

| name | folder | role |
|---|---|---|
| `mila` | `groups/main/` | Director. Sees user, dispatches to specialists. |
| `marketolog` | `groups/spec-marketolog/` | (new folder) — specialist |
| `designer` | `groups/spec-designer/` | specialist |
| `copywriter` | `groups/spec-copywriter/` | specialist |
| `metodolog` | `groups/spec-metodolog/` | specialist |
| `targetolog` | `groups/spec-targetolog/` | specialist |
| `prodavec` | `groups/spec-prodavec/` | specialist (sales) |
| `voronshchik` | `groups/spec-voronshchik/` | specialist (funnels — replaces `funnel-strategist` skill calls) |
| `illustrator` | `groups/spec-illustrator/` | specialist |
| `octo-admin` | `groups/spec-octo-admin/` | specialist (octofunnel ops) |
| `web-admin` | `groups/spec-web-admin/` | specialist (deploy/publish) |
| `news-curator` | `groups/spec-news-curator/` | specialist (ai-news-digest, wiki) |
| `lead-handler` | `groups/lead-handler/` | per-thread agent for leads (`tg_lead-*` rolls into this) |

The current `groups/telegram_*` folders that mirror specialist chats stop being agent groups; they become messaging groups (or are merged into the specialist's folder if the chat is the specialist's home).

### `messaging_groups`

Each Telegram chat = one row. Wired to an agent_group via `messaging_group_agents`.

| messaging_group | wired agent_group | session_mode | rationale |
|---|---|---|---|
| Telegram chat with user (private) | `mila` | `shared` | One ongoing conversation |
| `@telegram_octo` group | `mila` | `shared` | Mila orchestrates wave-based work, relays specialist replies |
| `@telegram_main` group | `mila` | `shared` | Same |
| `@telegram_ashotai-experts` | `mila` | `shared` | Same |
| `@telegram_channel-promoter` | `news-curator` | `shared` | Specialist owns this surface directly |
| `@telegram_client-profiler` | `mila` | `shared` | Mila routes to client-prep |
| `@telegram_inbox` | `mila` | `shared` | inbox watching |
| `@telegram_instagram` | `mila` | `shared` | IG ops orchestrator |
| `@telegram_partner-recruitment` | `mila` | `shared` | partner outreach |
| `@telegram_youtube-manager` | `news-curator` (or new `youtube-manager` agent) | `shared` | content publishing |
| `tg_lead-*` (3 currently, more will arrive) | `lead-handler` | `per-thread` | new lead = new session, same agent group's workspace |

### `agent_destinations`

Routing ACL — who can a2a-message whom. Decision 4 + decision 1B drive this.

**Bidirectional (Mila ↔ all specialists):**

```
(mila, "marketolog", agent, marketolog)
(marketolog, "mila", agent, mila)
… repeat for each specialist
```

**Specialist-to-specialist (only where wave orchestration in CLAUDE.md implies):**

`groups/telegram_octo/CLAUDE.md` defines a 6-role wave (Wave 1 → 5 + Review). Wire those:

```
(marketolog, "metodolog", agent, metodolog)
(metodolog, "marketolog", agent, marketolog)
(metodolog, "copywriter", agent, copywriter)
(copywriter, "designer", agent, designer)
(copywriter, "metodolog", agent, metodolog)
(designer, "copywriter", agent, copywriter)
(targetolog, "marketolog", agent, marketolog)
(marketolog, "targetolog", agent, targetolog)
… etc., per the actual wave dependencies
```

**Lead-handler ↔ Mila** (escalation): when `lead-handler` needs human approval (e.g. closing a sale), it routes through Mila who routes through admin-IPC.

## How specialists are created

In v2, agents can call the `create_agent` delivery action. So in principle Mila could spin up specialists on demand. But for stable identities (consistent persona, consistent wiki access, etc.), we pre-create them at migration time:

```bash
# Pseudo-code for stage 4 in 00-plan.md — actual SQL via v2's CLI tool
nanoclaw agent create --name mila --folder groups/main
nanoclaw agent create --name marketolog --folder groups/spec-marketolog
… for each specialist
nanoclaw agent destination add --from mila --to marketolog --as marketolog
nanoclaw agent destination add --from marketolog --to mila --as mila
… for each pair
```

(Replace with whatever the actual v2 CLI / setup skill provides — likely `/manage-channels` and the `init-first-agent` skill cover most of this; check on first install.)

## CLAUDE.md per specialist

Each specialist's CLAUDE.md is **focused on their craft**, not on orchestration. Mila's CLAUDE.md is **focused on orchestration and persona**, not on craft.

Source the specialist personalities from existing CLAUDE.md files:

| New specialist | Source CLAUDE.md (extract role section) |
|---|---|
| `marketolog` | `groups/telegram_octo/CLAUDE.md` (Маркетолог section) + `groups/telegram_main/CLAUDE.md` |
| `designer` | same + container skill `design-*` references |
| `copywriter` | same + container skill `humanizer-ru` |
| `metodolog` | same |
| `targetolog` | same + `meta-ads`, `telegram-ads-*` skills |
| `prodavec` | container skill `sales` SKILL.md is canonical |
| `voronshchik` | container skill `funnel-strategist` SKILL.md |
| `octo-admin` | container skills `octofunnel-*` |
| `web-admin` | container skills `web-*` |
| `news-curator` | container skills `ai-news-digest`, `wiki`, `wiki-contributor` |
| `lead-handler` | `groups/_public-lead/CLAUDE.md` + `tg_lead-*` shared patterns |

These are **fragments** in v2 (per `e64bdb3 refactor(claude-md): split shared base into module fragments`). Each specialist's `groups/<name>/CLAUDE.md` is just their persona + craft instructions; v2 injects the shared base automatically.

## How user requests flow

1. User messages Telegram `@AshotMila` (or whichever bot face).
2. Telegram adapter wakes Mila's session.
3. Mila reads the request, decides which specialist(s) to involve.
4. Mila a2a-sends a structured task to specialist(s) — XML or markdown, per CLAUDE.md template.
5. Specialist's session wakes, processes, replies via a2a back to Mila.
6. (Optional) Specialist a2a-messages another specialist for hand-off.
7. Mila composes final user-facing message (with role prefixes for transparency: `*Маркетолог:*\n…`), sends via Telegram adapter.

## Session mode rationale

- **`shared`** for most: each chat has its own session, but agents share workspace/memory across sessions of the same agent group. So Mila's memory persists across all her chats.
- **`per-thread`** for leads: each new lead = new session under `lead-handler` agent group. Lead-handler's wiki/skills/credentials are shared, but conversations stay independent.
- **`agent-shared`** is NOT used anywhere — we don't need cross-channel-merged sessions for Mila. (If at some point you want a single thread merging Telegram + Email + WhatsApp, that's the mode for it.)

## Goals & contexts (the user's "teams + cели" idea)

In v2's model, a "goal context" maps to a session. Each new initiative (e.g. "launch workshop X", "Q3 partner recruitment push") becomes a new session under whichever agent group owns it. Specialists are pulled in via a2a as the session needs them. Old sessions remain active in their own contexts; new ones don't lose memory because the agent group's workspace is shared.

This is exactly the systematized, sustained-focus model the user described — and v2 supports it without custom code. Just create a new chat / new thread to start a new goal-context.
