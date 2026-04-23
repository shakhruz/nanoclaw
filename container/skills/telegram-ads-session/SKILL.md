---
name: telegram-ads-session
description: Foundation skill for all telegram-ads-* skills. Provides the authoritative session check (cookie-only, no browser, ~50ms), live URL-based probe, flock-based write lock, and shared state dir helpers. Use when you need to verify the ads.telegram.org session state, acquire a lock for write operations, or write to the shared state dir.
---

# Telegram Ads — Session Foundation

All other `telegram-ads-*` skills depend on the helpers here. This is the **single source of truth** for "is the session alive?" — no more false-positive `⚠️ сессия истекла` alerts when the real cookies are valid until 2027.

## Why this exists

Previously three overlapping detectors disagreed:
- A legacy `*/30min` task using an old agent-browser workaround
- A `0 7,11,15,19` task that trusted a stale telemetry file and alerted without verifying
- Inline `grep` on browser snapshots matching "Log in" in page footer links

The authoritative signal is **one cookie** — `stel_ssid` on `ads.telegram.org` — stored in `~/.agent-browser/sessions/telegram-ads-default.json`. Everything else is cache.

## Helpers

### `check-session.sh` — cookie-only check (fast, no browser)

```bash
/home/node/.claude/skills/telegram-ads-session/check-session.sh
```

**Exit:** `0=alive`, `1=expired`, `2=unknown` (file missing).
**Stdout:** `{"status":"alive","expires_at":"2027-04-20T...","days_left":363,"cookie_file":"..."}`

Call this at the start of any telegram-ads-* flow. Takes ~50ms. If it says `alive` — trust it; open the browser only for the actual work, not to re-verify.

### `session-probe.sh` — live URL-based probe (slow, uses browser)

```bash
/home/node/.claude/skills/telegram-ads-session/session-probe.sh
```

**Exit:** `0=logged_in`, `1=logged_out`, `3=probe_error`.
**Stdout:** `{"status":"logged_in","final_url":"https://ads.telegram.org/account"}`

Uses URL pattern matching (not snapshot text) — robust against footer links. Call this **only** when you need to reconcile a suspicious `check-session.sh` result (e.g., cookie file was just synced but might be stale).

### `with-lock.sh` — serialize write operations

```bash
/home/node/.claude/skills/telegram-ads-session/with-lock.sh <command> [args...]
# Example — create campaign under lock:
with-lock.sh agent-browser --session-name telegram-ads click "text=Create Ad"
```

Acquires exclusive flock on `/workspace/global/telegram-ads/.lock`, waits up to 120s. Exit 75 on timeout.

Use for **any** write operation that touches `agent-browser --session-name telegram-ads` or the cookie file (create/pause/edit campaign, keepalive click). Read operations (fetching data to cache.json) don't need the lock.

### `common.sh` — shared bash helpers (source it)

```bash
. /home/node/.claude/skills/telegram-ads-session/common.sh

# Variables available after sourcing:
#   TG_ADS_STATE_DIR      = /workspace/global/telegram-ads
#   TG_ADS_SESSION_FILE   = /workspace/global/telegram-ads/session.json
#   TG_ADS_CACHE_FILE     = /workspace/global/telegram-ads/cache.json
#   TG_ADS_HISTORY_DIR    = /workspace/global/telegram-ads/history

tg_ads_init_state           # mkdir -p the whole tree
tg_ads_write_session alive telegram-ads-view       # update session.json atomically
STATUS=$(tg_ads_read_status)                       # alive | expired | unknown | missing
tg_ads_is_stale "$iso_ts" 15 && echo "refresh needed"
```

## Shared state dir — `/workspace/global/telegram-ads/`

Writable from main + all MILA groups (channel-promoter, partner-recruitment, client-profiler, youtube-manager). NOT mounted into public lead groups.

```
/workspace/global/telegram-ads/
├── session.json       ← canonical session health (alive/expired/unknown + expires_at + days_left)
├── cache.json         ← campaigns snapshot + balance (TTL ~4h, refreshed by view skill)
├── history/           ← daily snapshots for trend analysis
│   └── 2026-04-22.json
├── creatives/         ← saved ad copy + generated images/videos
├── research/          ← media plan research output
└── .lock              ← flock target for write serialization
```

## Typical decision tree

```
1. check-session.sh                → {"status":"alive","days_left":363}
   ├─ alive  → proceed with the actual task
   ├─ expired → session-probe.sh (live check)
   │     ├─ logged_in  → cookie file was stale; fix session.json; proceed
   │     └─ logged_out → alert user ONCE (dedupe by date), suggest /telegram-ads-auth
   └─ unknown → log it, skip silently (no alarm)
```

**Never** send `⚠️ сессия истекла` based on `check-session.sh` alone — always live-probe first. Cookie-file writes aren't atomic (even with our `mv` dance) and can briefly look empty during another container's shutdown.

## Если cookie повреждён, но в main живой (MILA-группы)

Если ты работаешь в MILA-группе (channel-promoter, partner-recruitment, client-profiler, youtube-manager), и видишь, что `telegram-ads-default.json` содержит:
- `stel_ssid.expires == -1.0` **или** `stel_ssid.session == true`,

— это **НЕ истечение сессии**. Это race-condition: твой agent-browser открыл `ads.telegram.org`, Telegram переотправил cookie без `Max-Age`, Chrome понизил его до session-cookie, agent-browser перезаписал файл.

В main-группе cookie остаётся живым (expires далеко в будущем, session=false). Поэтому правильная реакция:

1. **НЕ шли ⚠️-алерт.**
2. **НЕ проси `/telegram-ads-auth`.**
3. **Отправь сообщение в main через `mcp__nanoclaw__send_message`:**
   ```
   Cookie в MILA-<твоя-группа> сломан (session=-1). Нужен rebuild контейнера
   чтобы пересинкать из main. Запустишь `launchctl kickstart -k gui/$(id -u)/com.nanoclaw`?
   ```
4. Main-сессия жива — restart контейнера → sync main→MILA перезапишет повреждённый файл (non-main всегда получает свежий cookie при spawn, начиная с container-runner 2026-04-23).

Проверка, что ты в корректном состоянии:
```bash
jq '.cookies[] | select(.name=="stel_ssid") | {expires, session}' \
  /home/node/.agent-browser/sessions/telegram-ads-default.json
```
Ожидаемо: `{"expires": <big-number-~1808220032>, "session": false}`.

## For schedule-based tasks

Any cron prompt that checks session status MUST:
1. Call `check-session.sh` first (cheap, reliable)
2. Only run live-probe on `expired`
3. Only send an alert if live-probe confirms `logged_out` AND no alert has been sent today
4. Track "last alert date" in `session.json` — `last_alert_ts` field

See the canonical scheduled prompts in `telegram-ads-view/SKILL.md` and the consolidated `0 9 * * *` keepalive.

## First-time login / manual re-auth

If `check-session.sh` returns `unknown` (file missing) — the user has never authenticated. Invoke the full auth flow:
- Read `/home/node/.claude/skills/telegram-ads-auth/SKILL.md` (main-group override — owns phone number + SMS code flow)
- Run `telegram-ads-auth` end-to-end
- After success, `check-session.sh` should return `alive`

## DO / DON'T

**DO:**
- Call `check-session.sh` at the start of every telegram-ads-* flow
- Wrap writes in `with-lock.sh`
- Read from `/workspace/global/telegram-ads/cache.json` before opening the browser — data may be fresh
- Update `session.json` via `tg_ads_write_session` (atomic, keeps history)

**DON'T:**
- Don't grep `"log in"` on snapshots — use URL-based `session-probe.sh`
- Don't trust `session.json.status` without checking `last_check` freshness (> 10 min = stale)
- Don't send `⚠️` alerts without live probe confirmation
- Don't write cookies manually — only agent-browser should touch `~/.agent-browser/sessions/`
