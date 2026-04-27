# Container Skills

71 container skills under `container/skills/`. These are loaded inside agent containers at runtime — they're independent of the host runtime change (Node → Bun), independent of the channel architecture, independent of the session DB shape.

## Action: copy verbatim

```bash
cp -r ~/nanoclaw/nanoclaw/container/skills/ ~/nanoclaw/nanoclaw-v2/container/skills/
```

Then rebuild the agent container so the new skills are baked into the image:
```bash
cd ~/nanoclaw/nanoclaw-v2 && ./container/build.sh
```

## Skill clusters (for reference)

Detailed inventory in conversation; this is a quick map for the migration.

| Cluster | Count | Critical deps |
|---|---|---|
| Telegram Ads pipeline | 5 | telegram-scanner MCP (port 3002), Telegram Ads cookies, TON wallet |
| Instagram operations | 6 | Apify, Deepgram, Zernio, OpenRouter |
| Design / image generation | 8 | OPENROUTER, OPENAI (optional), ffmpeg, Pillow, rembg, system fonts |
| Sales & client lifecycle | 4 | client wiki, OctoFunnel, Zernio |
| OctoFunnel API | 5 | OctoFunnel platform secrets per platform |
| Zernio analytics | 4 | ZERNIO_API_KEY |
| Documents (KP, contracts, invoices) | 3 | Vercel, GitHub |
| Web publishing | 8 | Vercel CLI, gh CLI, Vercel token, GitHub token |
| Voice & audio | 6 | ELEVENLABS_API_KEY, ffmpeg, Remotion |
| YouTube & OLX | 5 | Apify, OPENROUTER, Zernio |
| Funnel building | 3 | OctoFunnel, Telegram Scanner, agent-browser |
| Wiki / second brain | 2 | git, optional GitHub |
| Admin / orchestration | 5 | admin-IPC protocol (DB-based after stage 5), agent-browser, MCP servers |
| Utility / formatting | 2 | none |

## Skills that depend on v1 internals — re-test after migration

These skills reference paths or protocols that the migration changes:

### `admin-ipc` (container skill, agent-side helper)

References file paths under `/workspace/global/admin-ipc/`. Stage 5 rewrite changes the protocol from file-write/poll to MCP tool call. Skill SKILL.md must be updated:

**v1 SKILL.md sample (typical pattern):**
```
echo '{"action":"...", "params":{...}}' > /workspace/global/admin-ipc/requests/req-XXX.json
# wait for response file
```

**v2 SKILL.md replacement:**
```
Use the `admin_request` MCP tool. The tool blocks until response arrives or 30-minute timeout.
admin_request({ action: "...", params: {...}, justification: "..." })
```

Edit `container/skills/admin-ipc/SKILL.md` after stage 5.

### `agent-browser`

Uses Puppeteer in container. Should work as-is since it doesn't touch host or DB. Verify Chrome/Chromium is in v2's container Dockerfile (it should be — same Dockerfile lineage).

### `telegram-channel-publisher`, `telegram-ads-research`, `funnel-tester`

Depend on telegram-scanner MCP at port 3002. The scanner runs on the host (not in a container) via Telethon. Make sure it's still running and reachable from new v2 containers via `host.containers.internal:3002` (Apple Container) or `host.docker.internal:3002`.

### `web-deploy`, `web-publish`, `web-asset-upload`, `web-client-doc`, `web-audit`, `web-logs`, `web-inventory`

Depend on `web-projects/` registry directory and `gh` + `vercel` CLI on the host. The `web` skill bundle pre-flights these. Should work unchanged after credentials are migrated to OneCLI vault (stage 3).

### `composio` (if present in container/skills/)

Composio MCP serves Gmail/Calendar OAuth. Decision 2: Gmail dropped. Check whether composio is referenced by any other skill (Calendar?). If yes, keep; if no, drop along with the `@composio/core` npm dep.

### `wiki`, `wiki-contributor`

Read/write `groups/<name>/wiki/` paths. Path scheme unchanged in v2. Should work as-is.

## Custom additions to verify

These skills were built specifically for this fork and have no upstream equivalent:

- All `octofunnel-*` (OctoFunnel platform integration)
- All `telegram-ads-*` (Telegram Ads platform pipeline)
- All `instagram-*` (Apify-based Instagram analytics)
- `humanizer-ru` (RU text humanization)
- `plaud-*` (PLAUD device transcription)
- `ai-news-digest` (Telegram + web news digest)

These are pure container skills with no host dependencies beyond the listed env vars / MCP servers. Copy-and-go.

## Cleanup candidates

Skills that may be obsolete by the time of migration — review and decide whether to drop:

- Old skill backups (any `*.backup-*.md` files — gitignore was added in `cf63185`, but some may still exist on disk; safe to delete)
- Skills that were experimental and never invoked: check `ai-news-digest` invocations in scheduled tasks; if no one schedules it, defer install

## Bun compatibility

v2 runs the agent-runner under Bun. Skills are SKILL.md + shell scripts; they don't import Node-specific APIs. Should be Bun-compatible by default. The only exception would be a skill that runs `node script.js` — search for any such pattern:

```bash
grep -r "^node " container/skills/ | grep -v "// " | head -20
```

If found, Bun likely handles `node` shebangs by aliasing, but verify on stage 1 by running one such skill end-to-end in a v2 test agent.
