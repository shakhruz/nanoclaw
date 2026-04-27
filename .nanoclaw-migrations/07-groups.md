# Groups → v2 Entity Model

Decision 4: mixed isolation model. Mila is shared director, specialists each get their own agent group, leads share a per-thread agent group.

## Source: 18 v1 group folders

```
_public-lead              → folded into lead-handler
_shared-products          → moved to groups/main/shared/ as a wiki/data dir, not an agent group
global                    → groups/main (the "Mila" / global agent group)
main                      → groups/main (merged with global)
telegram_ashotai-experts  → messaging_group, wired to mila
telegram_channel-promoter → messaging_group, wired to news-curator
telegram_client-profiler  → messaging_group, wired to mila
telegram_inbox            → messaging_group, wired to mila
telegram_instagram        → messaging_group, wired to mila
telegram_main             → messaging_group, wired to mila
telegram_octo             → messaging_group, wired to mila
telegram_partner-recruitment → messaging_group, wired to mila
telegram_youtube-manager  → messaging_group, wired to youtube-manager (or news-curator)
tg_lead-5753885263        → messaging_group, wired to lead-handler (per-thread)
tg_lead-8242423492        → messaging_group, wired to lead-handler (per-thread)
tg_lead-863350578         → messaging_group, wired to lead-handler (per-thread)
```

## Target: agent_groups

| name | folder | wiki | skills/ | session_mode |
|---|---|---|---|---|
| `mila` | `groups/main/` (merged from `global` + `main`) | yes | inherits | `shared` |
| `lead-handler` | `groups/lead-handler/` (new, seeded from `_public-lead` + tg_lead-* CLAUDE.mds) | no | from `groups/_public-lead/skills/` if any | `per-thread` |
| `marketolog` | `groups/spec-marketolog/` (new) | no | none — uses container skills | `shared` |
| `designer` | `groups/spec-designer/` (new) | no | none | `shared` |
| `copywriter` | `groups/spec-copywriter/` (new) | no | none | `shared` |
| `metodolog` | `groups/spec-metodolog/` (new) | no | none | `shared` |
| `targetolog` | `groups/spec-targetolog/` (new) | no | none | `shared` |
| `prodavec` | `groups/spec-prodavec/` (new) | no | none | `shared` |
| `voronshchik` | `groups/spec-voronshchik/` (new) | no | none | `shared` |
| `illustrator` | `groups/spec-illustrator/` (new) | no | none | `shared` |
| `octo-admin` | `groups/spec-octo-admin/` (new) | no | none | `shared` |
| `web-admin` | `groups/spec-web-admin/` (new) | no | none | `shared` |
| `news-curator` | `groups/spec-news-curator/` (new) | yes (relocate `groups/global/wiki/`?) | container skills `wiki`, `wiki-contributor` | `shared` |
| `youtube-manager` | `groups/spec-youtube-manager/` (new) — optional, can fold into news-curator | no | none | `shared` |

Total: ~13–14 agent groups vs the current 18 group folders. Reduction comes from collapsing chat-folders into messaging_group entries pointing at a smaller set of agent groups.

## Wiki disposition

The wiki currently lives in `groups/global/wiki/`. Two options:

**Option A (recommended): keep wiki in `groups/main/wiki/`** under Mila. All specialists read it via a2a "ask Mila to fetch wiki note X" or via shared `/workspace/wiki/` mount. Mila is the curator role from `add-second-brain`.

**Option B: move wiki to `news-curator`**. news-curator is the Karpathy curator. But this breaks the convention that the director controls the wiki.

Pick A.

For specialists who write to the wiki (the `wiki-contributor` role), the v1 pattern was: pre-commit hook restricts each contributor to their `projects/<role>/` subdir. This stays, just relocated.

## Other group-level wikis

| Group | Wiki path | Disposition |
|---|---|---|
| `groups/telegram_instagram/wiki` | exists | move to `groups/spec-marketolog/wiki/` (Instagram is marketolog's domain) |
| `groups/telegram_main/wiki` | exists | merge into `groups/main/wiki/` |
| `groups/tg_lead-8242423492/wiki` | exists | move to `groups/lead-handler/leads/8242423492/` (lead-specific notes) |

## Per-group `skills/` directories

`groups/telegram_main/skills/` and `groups/telegram_octo/skills/` exist. Inspect contents — these are likely small group-specific helpers.

In v2: per-group `skills/` directories still work (loaded by the agent at session start). Move them:
- `groups/telegram_main/skills/` → `groups/main/skills/` (merging if any name collisions)
- `groups/telegram_octo/skills/` → keep at `groups/main/skills/` since telegram_octo is wired to mila in v2

## CLAUDE.md disposition

Each surviving agent group folder gets a CLAUDE.md fragment. v2 composes the shared base + this fragment at runtime.

| New folder | Source CLAUDE.md (extract relevant sections) |
|---|---|
| `groups/main/CLAUDE.md` | merge `groups/global/CLAUDE.md` + `groups/main/CLAUDE.md` + Mila orchestrator section from `groups/telegram_main/CLAUDE.md` and `groups/telegram_octo/CLAUDE.md` (the wave-orchestration logic) |
| `groups/lead-handler/CLAUDE.md` | `groups/_public-lead/CLAUDE.md` + commonalities from `groups/tg_lead-*/CLAUDE.md` |
| `groups/spec-<name>/CLAUDE.md` | extract role section from telegram_octo / telegram_main + container skill references |

Strip from CLAUDE.md when migrating:
- Sections about the bot pool / swarm UX (decision 1B)
- Sections about file-based admin-IPC paths (decision 3A)
- Anything about per-group `agent-runner-src/` overlays (gone in v2)

## Lead-handler per-thread mapping

Three existing leads (`tg_lead-5753885263`, `tg_lead-8242423492`, `tg_lead-863350578`) need their conversation history preserved.

In v2's per-thread model:
- One agent group `lead-handler`
- Three messaging_groups, each with its own thread_id (the chat ID)
- Each gets its own session under `data/v2-sessions/lead-handler/<session_id>/`

If v1 kept conversation history in SQLite, you'll want to bring it across. If v1 used filesystem markdown logs in `groups/tg_lead-*/`, copy them to `groups/lead-handler/leads/<thread_id>/` so lead-handler can load them as wiki/context on first run.

New incoming leads: messaging_groups gets a new row when the channel adapter forwards an unknown thread; v2's auto-registration creates the per-thread session automatically. No manual intervention needed.

## Shared products / public lead

`_shared-products/` — likely a catalog of offers. Move to `groups/main/shared-products/` as a data folder; reference from sales / voronshchik specialists' CLAUDE.md.

`_public-lead/` — was the public-lead funnel template. Source for `lead-handler/CLAUDE.md`. After extracting, delete the folder.

## Copy commands (for stage 3 of migration)

```bash
V1=~/nanoclaw/nanoclaw
V2=~/nanoclaw/nanoclaw-v2

# direct copy (no transformation)
cp -r "$V1/groups/global/wiki" "$V2/groups/main/wiki"
cp -r "$V1/groups/main/skills" "$V2/groups/main/skills"
cp -r "$V1/_shared-products" "$V2/groups/main/shared-products"

# specialist CLAUDE.md extraction is manual — see [04-orchestrator.md](04-orchestrator.md) for source mapping
mkdir -p "$V2/groups/spec-marketolog" "$V2/groups/spec-designer" \
         "$V2/groups/spec-copywriter" "$V2/groups/spec-metodolog" \
         "$V2/groups/spec-targetolog" "$V2/groups/spec-prodavec" \
         "$V2/groups/spec-voronshchik" "$V2/groups/spec-illustrator" \
         "$V2/groups/spec-octo-admin" "$V2/groups/spec-web-admin" \
         "$V2/groups/spec-news-curator" "$V2/groups/lead-handler"

# leads
mkdir -p "$V2/groups/lead-handler/leads"
for L in tg_lead-5753885263 tg_lead-8242423492 tg_lead-863350578; do
  TID=${L#tg_lead-}
  cp -r "$V1/groups/$L" "$V2/groups/lead-handler/leads/$TID"
done
```
