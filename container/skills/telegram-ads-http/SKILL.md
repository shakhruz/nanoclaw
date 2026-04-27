---
name: telegram-ads-http
description: HTTP/curl-based access to ads.telegram.org — replaces headless-browser pipeline that suffered from per-spawn device-fingerprint rejection. Reads campaign list/balance from /account, performs writes (editAdStatus, createAd, editAdCPM, editAdDailyBudget) via /api?hash=X. Cookies persist across all containers via main → MILA spawn-time sync. Use this for ALL telegram-ads operations going forward.
---

# Telegram Ads — HTTP API access

🎯 **Replaces the headless-browser stack** (`telegram-ads-manager` + `telegram-ads-session` + `telegram-ads-access`). Curl + cookie jar — no agent-browser, no fingerprint problems.

## Why this exists

The old browser-based pipeline failed predictably every few hours: cookies remained valid, but Telegram's server rejected the headless Chromium session because each container spawn = new device-fingerprint = "untrusted device" → forced re-2FA in the Telegram app.

**Curl bypasses this entirely.** Telegram trusts the cookies themselves; the missing piece for browser was the device-trust handshake (localStorage / IndexedDB / canvas fingerprint), which a JSON request doesn't need.

## Prerequisites

- Cookie file exists at `/home/node/.agent-browser/sessions/telegram-ads-default.json` (mounted from main; auto-synced on every spawn). Override with env `ADS_COOKIES_JSON=<path>` if needed.
- `jq`, `python3`, `curl` available (default in container).

## Files

| File | Purpose |
|---|---|
| `lib.sh` | Shared helpers — `ads_init`, `ads_get`, `ads_post`, `ads_extract_state`, sets `$ADS_HASH`, `$ADS_OWNER_ID`. Source from any script. |
| `get-account.sh` | Read snapshot: balance, owner name, all campaigns with status/budget/spent/views/clicks. |
| `get-ad.sh <ad_id>` | Read single ad detail + extract `ownerId`, `adId`, currency context. |
| `edit-status.sh <ad_id> <0\|1> [--confirm]` | Toggle ad Active ↔ On Hold. |
| `edit-cpm.sh <ad_id> <cpm_ton> [--confirm]` | Change ad's CPM bid. |
| `edit-daily-budget.sh <ad_id> <daily_ton> [--confirm]` | Set per-day cap (0 = remove cap). |
| `edit-title.sh <ad_id> <title> [--confirm]` | Rename internal label. |
| `incr-budget.sh <ad_id> <delta_ton> [--confirm]` | Top up an ad's total budget. |
| `create-ad.sh <params.json> [--confirm]` | Create new ad (full targeting params). |
| `delete-ad.sh <ad_id> [--confirm]` | Delete a draft / On Hold ad. |
| `clone-ad.sh <src_id> [--confirm]` | Duplicate an ad as new Draft (A/B testing — handles confirm_hash flow). |
| `upload-media.sh <file_path> [target]` | Upload photo/video to Telegram. Returns `media` id to pass into create-ad. `target` = `ad_media` (default) or `promote_photo`. |
| `balance-deposit.sh [<amount_ton>]` | Get TON deposit URL/address (top-up cannot be automated — needs Шахруз's TON wallet sig). |

All write helpers default to dry-run; pass `--confirm` to execute.

## Quick recipes

### List all campaigns
```bash
bash /home/node/.claude/skills/telegram-ads-http/get-account.sh \
  | jq '.campaigns[] | {ad_id, title, status, budget, spent, views, ctr}'
```

### Pause an ad
```bash
bash /home/node/.claude/skills/telegram-ads-http/edit-status.sh 36 0 --confirm
```

### Activate ads in bulk (e.g., 9 In-Review campaigns)
```bash
bash /home/node/.claude/skills/telegram-ads-http/get-account.sh \
  | jq -r '.campaigns[] | select(.status=="On Hold") | .ad_id' \
  | while read id; do
      bash /home/node/.claude/skills/telegram-ads-http/edit-status.sh "$id" 1 --confirm
    done
```

## Anatomy — how `/api?hash=X` works

Telegram Ads uses jQuery + a session-bound `Aj.apiUrl`:

```js
Aj.init({"version":1119,"apiUrl":"\/api?hash=57ddbc999993745965", ...})
function apiRequest(method, data) {
  $.ajax(Aj.apiUrl, { type:'POST', data:$.extend(data, {method}), ... })
}
```

Every page load returns the same hash for the session. POSTing to `/api?hash=<X>` with body `method=<methodName>&...params` invokes that method.

**Critical constraint:** Telegram validates the `Referer` header against the method. POSTing `editAdStatus` with `Referer: /account` returns `{"error":"Access denied"}`; the same call with `Referer: /account/ad/<ad_id>` succeeds. The skill's `ads_post` takes a `referer_path` arg — use the page where the form would normally live.

| Method | Referer path | Helper |
|---|---|---|
| `editAdStatus` | `/account/ad/<ad_id>` | `edit-status.sh` |
| `editAdCPM` | `/account/ad/<ad_id>` | `edit-cpm.sh` |
| `editAdDailyBudget` | `/account/ad/<ad_id>` | `edit-daily-budget.sh` |
| `editAdTitle` | `/account/ad/<ad_id>` | `edit-title.sh` |
| `incrAdBudget` | `/account/ad/<ad_id>` | `incr-budget.sh` |
| `createAd` | `/account/ad/new` | `create-ad.sh` |
| `deleteAd` | `/account/ad/<ad_id>` | `delete-ad.sh` |
| `createDraftFromAd` | `/account/ad/<ad_id>` | TODO (clone helper) |
| `getSimilarChannels` | `/account/ad/<ad_id>` | (used in research) |
| `getSimilarBots` | `/account/ad/<ad_id>` | (used in research) |
| `getAdsList` | `/account` | NOT USABLE via curl — use page-scrape via `get-account.sh` instead |

## Aj.init state extraction

The first `Aj.init({...})` call on each page contains useful state inline:

| Page | State keys | Usage |
|---|---|---|
| `/account` | `initialAdsList.items[]` | Full campaigns list (no extra API call needed) |
| `/account/ad/<id>` | `ownerId`, `adId`, `ownerCurrency`, `previewData` | Owner ID for write methods, currency formatting |

Use `ads_extract_state` (in `lib.sh`) or `python3` balanced-brace parser pattern in `get-account.sh`.

## owner_id

`owner_id` for write methods = the `stel_adowner` cookie value (also exposed as `ownerId` in page state). `ads_init` sets `$ADS_OWNER_ID` for use in your POST body.

## Migration from old skills

| Old (browser) | New (HTTP) |
|---|---|
| `telegram-ads-access/access.sh` | `telegram-ads-http/get-account.sh` (returns `ok:true` if login works) |
| `telegram-ads-session/check-session.sh` | check `ads_init` exit code (0 = ok, 2 = auth issue) |
| `telegram-ads-session/session-probe.sh` | `get-account.sh \| jq .ok` |
| `telegram-ads-manager` (campaign actions) | `edit-status.sh`, `create-ad.sh` (TODO), direct `ads_post` |
| `telegram-ads-access/keepalive.sh` | NOT NEEDED — cookies don't decay; no browser session to keep warm |

## Anti-patterns

❌ Don't open agent-browser for ads.telegram.org — fingerprint check breaks.
❌ Don't pass empty `Referer` header — Telegram returns Access denied.
❌ Don't hardcode the `apiUrl` hash — it's per-session, regenerated when cookies refresh. Always extract from a fresh `/account` fetch.
❌ Don't run `editAdStatus` without `--confirm` — every helper that writes has a dry-run mode for a reason.
❌ Don't write to multiple ads in a tight loop without spacing — Telegram may rate-limit (insert `sleep 1` between calls).

## Lifecycle quick-reference

```bash
# Inspect
bash get-account.sh | jq '.campaigns | length'   # 19 total
bash get-account.sh | jq '.balance_ton'          # 12.4
bash get-ad.sh 36 | jq                           # full ad details

# Mutate (always pass --confirm for real)
bash edit-status.sh 36 1 --confirm               # activate
bash edit-status.sh 36 0 --confirm               # pause
bash edit-cpm.sh 36 0.7 --confirm                # change bid to 0.7 TON
bash edit-daily-budget.sh 36 0.5 --confirm       # cap daily spend
bash incr-budget.sh 36 1.0 --confirm             # add 1 TON to total
bash edit-title.sh 36 "new label" --confirm
bash delete-ad.sh 36 --confirm                   # only Draft/On Hold

# Clone for A/B
bash clone-ad.sh 36 --confirm                 # → returns new draft ad_id

# Image upload + create-ad with media
MEDIA_ID=$(bash upload-media.sh /workspace/group/banner.jpg ad_media | jq -r .media)
cat > /tmp/new.json <<EOF
{"title":"...","text":"...","promote_url":"https://t.me/ashotonline",
 "cpm":0.6,"budget":1.0,"target_type":"channels","channels":"ashotonline",
 "media":"${MEDIA_ID}","picture":1,
 "exclude_politic":1,"exclude_crypto":1,"active":1}
EOF
bash create-ad.sh /tmp/new.json --confirm

# Text-only ad (no media)
cat > /tmp/text-ad.json <<EOF
{"title":"...","text":"...","promote_url":"https://t.me/ashotonline",
 "cpm":0.6,"budget":1.0,"target_type":"channels","channels":"ashotonline",
 "exclude_politic":1,"exclude_crypto":1,"active":1}
EOF
bash create-ad.sh /tmp/text-ad.json --confirm

# Balance top-up (cannot be automated — get instructions for Шахруз)
bash balance-deposit.sh 5
```

## Status (2026-04-26)

✅ **Read** working — get-account/get-ad parse live state cleanly.
✅ **POST infrastructure** confirmed (`getSimilarBots` returned ok).
🟡 **Write helpers** built and dry-run-tested; live mutation not yet confirmed. Validate with a benign pause→resume on a non-spending ad before using on production campaigns.
❌ **Balance top-up** — Telegram has no API for this; needs manual TON wallet sign by owner.

## Migration from old skills (deprecated 2026-04-26)

| Old skill | Action |
|---|---|
| `telegram-ads-access` | DELETED — use `get-account.sh` (returns `ok:true` if alive). |
| `telegram-ads-session` | DELETED — no browser session to keep warm. |
| `telegram-ads-manager` | DELETED — fully replaced by helpers above. |
| `telegram-ads-analyze` | DELETED — query `get-account.sh` output via jq. |
| `telegram-ads-view` | DELETED — `get-account.sh` is the read path. |
| `telegram-ads` (creative gen) | KEPT — separate concern, generates ad copy + banners. |
| `telegram-ads-research` | KEPT — channel/audience discovery. |
| `telegram-ads-generator` | KEPT — moderation-safe ad text gen. |
