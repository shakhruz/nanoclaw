# Custom Feature Skills

10 user-authored skills in `.claude/skills/`. Each has a v2 disposition.

## Drop entirely (v2 covers natively)

### `add-image-vision`
- **What it did:** Sharp-resize WhatsApp images, send as multimodal blocks.
- **Why drop:** v2 SDK sends image content blocks natively. No code path needed.
- **Side effects to clean:** dependencies (`sharp`) — drop from package.json on v2 if not used elsewhere.

### `add-pdf-reader`
- **What it did:** poppler-utils CLI extraction of WhatsApp PDF attachments.
- **Why drop:** v2 SDK accepts PDFs directly via Files API.
- **Side effects to clean:** `container/Dockerfile` no longer needs `poppler-utils` install line — but skip cleanup, harmless leftover.

### `add-gmail`
- **What it did:** Full Gmail channel adapter (`src/channels/gmail.ts`, 364 LOC) + GCP OAuth setup + Composio MCP.
- **Why drop (decision 2):** v2 hasn't shipped Gmail in `channels` branch yet. Wait for upstream rather than maintain a fork-specific adapter.
- **What we keep:** Composio API key in OneCLI vault (used by `composio` skill on container side, see [09-credentials.md](09-credentials.md)). Gmail OAuth tokens in `~/.gmail-mcp/` stay on disk for future use.
- **Action when v2 ships it:** `claude /add-gmail` and re-pair.

## Drop entirely (decision 1: switch UX model)

### `add-telegram-swarm`
- **What it did:** `TELEGRAM_BOT_POOL` + `TELEGRAM_BOT_POOL_ROLES` env vars, `initBotPool()`, `sendPoolMessage()`, callback parsing for swarm-aware routing.
- **Why drop:** Decision 1B switches to v2-native agent-to-agent. Specialists no longer need their own Telegram bot identities. Mila is the single bot face; specialist conversations happen in DB via `agent_destinations`.
- **What this means for users:** in Telegram, you only see Mila. When a specialist responds, Mila relays it (e.g. "Маркетолог: ..."). Wave-based orchestration in `telegram_octo` is preserved but expressed in Mila's prose, not as separate-bot messages.
- **Migration of existing pool tokens:** retire the extra bots in BotFather (or leave them dormant; they cost nothing). `TELEGRAM_BOT_POOL` and `TELEGRAM_BOT_POOL_ROLES` env vars are removed from launchd plist.

## Re-install via upstream (decision 2 partial overlap)

None at this time. All channel adapters are either dropped (gmail) or installed via upstream skills (telegram).

## Keep as-is, copy + re-test on v2

### `add-compact`
- **What it does:** Slash `/compact` for manual context compaction in long sessions.
- **v2 plan:** Verify whether v2 ships this natively. If not, copy the skill verbatim into v2's `.claude/skills/`. Likely needs the underlying code (src/session-commands.ts) re-applied as well — but check v2 first; session model may have changed.

### `add-reactions`
- **What it does:** WhatsApp reaction storage in SQLite, send-reaction MCP tool.
- **v2 plan:** WhatsApp not in active use — defer. If WhatsApp gets re-installed later, copy the skill, re-apply the schema migration to v2's session DB shape, re-test.

### `add-second-brain`
- **What it does:** Karpathy-style wiki scaffolding (curator + contributor roles, weekly lint cron, Obsidian config), container skill `wiki` + `wiki-contributor`.
- **v2 plan:** Container skills `wiki` and `wiki-contributor` already in `container/skills/` and copy verbatim. Wiki data lives in `groups/global/wiki/` and copies as part of Stage 3. The cron task needs re-registration in v2's task scheduler.
- **Re-test:** schedule the lint task, confirm `wiki-contributor` agent can append to inbox without writing outside its sandbox.

### `add-voice-transcription`
- **What it does:** OpenAI Whisper API for WhatsApp voice notes; produces `[Voice: <transcript>]` prefix.
- **v2 plan:** WhatsApp not active. If revived, copy `src/transcription.ts` + WhatsApp adapter integration. v2 may eventually ship voice support natively.

### `channel-formatting`
- **What it does:** `parseTextStyles()` + `parseSignalStyles()`, channel-aware Markdown sanitization in `formatOutbound()`.
- **v2 plan:** v2 channels (Telegram, WhatsApp, etc.) handle formatting per-adapter inside the `channels` branch. Verify after `/add-telegram` install: send `**bold**` and `*italic*`, check if Telegram renders correctly. If not, port `text-styles.ts` and inject into `formatOutbound`.

### `use-local-whisper`
- **What it does:** Replace OpenAI Whisper API with whisper.cpp local model.
- **v2 plan:** Tied to `add-voice-transcription`. Revive together if WhatsApp comes back.

## Custom files associated with these skills

These files exist in v1 src/ because skills patched them. After install of v2 baseline:

| File | Origin | v2 disposition |
|---|---|---|
| `src/session-commands.ts` (+163 LOC) | `add-compact` | Re-apply if v2 lacks `/compact`. |
| `src/session-commands.test.ts` (+247 LOC) | `add-compact` | Re-apply with above. |
| `src/image.ts` | `add-image-vision` | Drop. v2 has native multimodal. |
| `src/transcription.ts` | `add-voice-transcription` | Drop unless WhatsApp comes back. |
| `src/text-styles.ts` | `channel-formatting` | Re-apply only if v2 Telegram doesn't sanitize Markdown correctly. |
| `src/credential-proxy.ts` + test | (unclear; pre-OneCLI fallback) | Drop — OneCLI is mandatory in v2. |
| `src/status-tracker.ts` + test | `add-reactions` | Drop unless reactions are re-installed. |
