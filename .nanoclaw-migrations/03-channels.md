# Channel Customizations

Approach: install channels through upstream `/add-<channel>` skills, then layer fork-specific overrides only where v2 base is insufficient.

## Telegram

`/add-telegram` from `upstream/channels` ships polling adapter, pairing flow, Markdown v1 sanitization, inline button callbacks, reply context, file attachments up to 20MB.

### Drop (covered by v2 base or other decisions)

- **Bot pool / swarm routing** — decision 1B. See [02-custom-skills.md](02-custom-skills.md) `add-telegram-swarm` and [04-orchestrator.md](04-orchestrator.md).
- **`TELEGRAM_BOT_TOKEN` env handling** — v2 reads from OneCLI vault, not raw `.env`. Already true in v1 if OneCLI was set up properly; ensure `Telegram` secret entry points to the main bot token.
- **Custom `formatOutbound` per-channel switch** — try v2 base first. Apply only if rendering breaks.
- **Per-call `setMyName()`** — gone with the pool.

### Keep / re-apply on v2

#### MTProto fallback for files >20MB

**Intent:** Telegram Bot API is capped at 20MB downloads. The fork uses a local Telethon MCP server (`telegram-scanner` on port 3002) as a fallback for larger media (voice, video, PDFs from leads).

**Files in v1:**
- `src/channels/telegram.ts` — added `downloadLargeFileViaMTProto(fileId)` helper invoked when `getFile` returns a 20MB error
- `.mcp.json` — was empty in commit, but the MCP server config lives in container scope

**How to apply on v2:**
1. After `/add-telegram` succeeds in v2:
2. Open `src/channels/telegram.ts` (in `nanoclaw-v2`) — find the file-download path. v2 may have a different shape than v1.
3. Wrap the existing download in a try-catch; if Bot API errors with `file is too big`, call out to the local Telethon MCP at `http://host.containers.internal:3002/mcp` (Apple Container) or `http://host.docker.internal:3002/mcp` (Docker).
4. Telethon MCP request shape: `{ method: "tools/call", params: { name: "download_media", arguments: { file_id: "..." } } }`. Returns base64 in `content[0].data`.
5. Save to `outbox/<message_id>/<filename>` so the agent receives it as a normal attachment.

**Dependencies:** Telethon MCP must be running. See [09-credentials.md](09-credentials.md).

#### Inline-button handler for admin-IPC decisions

**Intent:** when admin-IPC escalates to human approval, Telegram message has ✅ / ❌ buttons. Callback writes the decision somewhere the daemon picks up.

**v1 implementation:** `callback_query` handler parses `data` matching `^admin:(approve|deny):(.+)$`, writes `groups/global/admin-ipc/decisions/<reqId>.json`, edits the message to show ✅/❌.

**v2 implementation (decision 3A):** same parsing, but instead of writing a file, INSERT a row into the global session's `inbound.db` (or a dedicated `admin_decisions` table). See [05-admin-ipc.md](05-admin-ipc.md) for the full schema.

**Files to touch on v2:**
- `src/channels/telegram.ts` (in `nanoclaw-v2`, after `/add-telegram` is applied) — extend `callback_query` handler.

#### Persona prefix in outbound messages (replaces swarm UX)

**Intent:** With swarm dropped (decision 1B), Mila relays specialist responses inline. Format like: `*Маркетолог:*\n<their message>`. Make this part of how Mila composes — not a code change in the channel adapter.

**Where this lives:** in Mila's CLAUDE.md (`groups/main/CLAUDE.md` or whichever group is wired as Mila), instruct her to prefix specialist relays with the role name in italics.

**No code change needed in the Telegram channel.**

## Gmail

Decision 2: drop until upstream ships it. See [02-custom-skills.md](02-custom-skills.md).

## WhatsApp

Not in active use. Skip the install. If revived later: `/add-whatsapp` + re-apply `add-reactions`, `add-voice-transcription`, `add-pdf-reader` (the latter may be redundant on v2).

## Slack / Discord / iMessage / Signal / etc.

Not in active use. Skip.
