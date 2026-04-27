# Credentials and Secrets

v2 mandates OneCLI Agent Vault as the only credential path. Containers never see raw API keys. Decision: stay with OneCLI (already in use on v1).

## Migration approach

OneCLI vault is **host-level state**, separate from the repo. Migrating from v1 to v2 doesn't touch the vault — v2 just talks to the same OneCLI service.

```bash
onecli list           # before stage 3 — record this
onecli list           # after stage 6 — should match
```

If anything is missing post-cutover, re-add via `onecli add <name> --value <secret>`.

## Expected vault entries

Compiled from container skill SKILL.md frontmatter and the .env.example evolution:

| Vault entry | Used by |
|---|---|
| `Anthropic` (or default OneCLI Anthropic key) | Claude SDK in agent-runner |
| `Telegram` (main bot token) | Telegram channel adapter |
| `Apify` | Instagram analyzer, IG competitor tracker, YouTube analyzer, OLX research |
| `OpenRouter` | Design skills (Nano Banana, Gemini 3 Pro, GPT Image 2), Instagram expert, illustrator |
| `OpenAI` (optional) | Whisper API (if `add-voice-transcription` is revived); some image gen models |
| `ElevenLabs` | TTS, music, voice clone, voice-message, audio-lesson, media-maker |
| `Zernio` | Zernio analytics, inbox, monitor, publisher; YouTube upload; Instagram daily report |
| `Composio` | Composio MCP (Gmail / Calendar / Telegram-Scanner orchestration if used) |
| `MetaAds` | Instagram daily report (paid ads), meta-ads skill |
| `Vercel` | web-deploy, web-publish (CLI uses VERCEL_TOKEN) |
| `GitHub` | web-publish, doc-* (gh CLI for repo writes) |
| `OctoFunnel-AshotAI` (and per-platform variants) | octofunnel-* skills |
| `TelegramScanner-Telethon` | telegram-channel-publisher, ai-news-digest |
| `Deepgram` | youtube-analyzer (transcript extraction) |

Run `onecli list` to compare against this list and add any missing.

## .env entries to drop in v2

`TELEGRAM_BOT_POOL` and `TELEGRAM_BOT_POOL_ROLES` — decision 1B. Remove from launchd plist `EnvironmentVariables` and from any `.env` file.

## .env entries to keep

| Var | Why it stays |
|---|---|
| `TIMEZONE` (Asia/Tashkent) | Used by task scheduler for "daily morning" cron firing in local time |
| `DEEPGRAM_API_KEY`, etc. | If any keys are still in `.env` rather than OneCLI, migrate them. v2 prefers vault. |
| Skill-specific paths | e.g. wiki root, second-brain repo, web-projects registry |

Audit `.env` during stage 3:
```bash
diff ~/nanoclaw/nanoclaw/.env ~/nanoclaw/nanoclaw-v2/.env.example
```

For each var in v1 `.env` that's not in v2 example, decide: vault (preferred) or `.env` (only if vault doesn't fit, e.g. paths).

## Composio MCP

The `@composio/core` npm dep was added in v1 for managed Gmail/Calendar OAuth + Telegram Scanner orchestration. Decision 2 drops Gmail. Calendar usage:

Check whether any container skill or src/ code references Composio for non-Gmail purposes:
```bash
grep -r "composio\|Composio" ~/nanoclaw/nanoclaw/container/skills/ ~/nanoclaw/nanoclaw/src/ | head -20
```

If only Gmail uses it: drop the dep from package.json on v2, drop the OneCLI entry.
If Calendar / Telegram Scanner orchestration uses it: keep.

## OAuth tokens on disk

`~/.gmail-mcp/credentials.json` and `~/.gmail-mcp/token.json` — Gmail OAuth tokens persisted on host. Stay on disk. When v2 ships `add-gmail`, the same tokens will be picked up.

## Telegram bot tokens

The fork has multiple bot tokens (the swarm pool). After decision 1B:
- Keep the **main bot token** in OneCLI vault entry `Telegram`.
- Pool bot tokens (4–5 of them) can be retired in BotFather, or kept dormant. Not used in v2.

## Audit checklist for stage 3

- [ ] `onecli list` snapshot saved before stage 3
- [ ] All container skills' env-var requirements present in vault
- [ ] No raw API keys remain in `.env` for things vault can host
- [ ] `~/.gmail-mcp/` preserved for future Gmail revival
- [ ] Telethon MCP service still running on port 3002
- [ ] launchd plist `EnvironmentVariables` block cleaned of pool vars
