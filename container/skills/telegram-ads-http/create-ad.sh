#!/usr/bin/env bash
# create-ad.sh <params.json> [--confirm] — create a new ad campaign.
#
# params.json is a JSON object with fields matching the createAd API:
# {
#   "title":        "internal label",         // required, your tracking name
#   "text":         "ad text ≤160 chars",     // required
#   "promote_url":  "https://t.me/channel",   // required for channel/bot/post target
#   "button":       "Join",                   // optional, default "Join"
#   "cpm":          0.6,                      // bid in TON, min ~0.6
#   "budget":       1.0,                      // total budget TON, min 0.5
#   "daily_budget": 0,                        // 0 = no daily cap
#   "active":       1,                        // 1 = submit for review immediately, 0 = save as draft
#   "target_type":  "channels",               // "channels" | "bots" | "search"
#   "channels":     "ashotonline,otherchan",  // for target_type=channels
#   "bots":         "...",                    // for bots
#   "search_queries": "ai,chatgpt",           // for search
#   "langs":        "ru,en",                  // optional language filter
#   "topics":       "tech,business",          // optional topic filter
#   "device":       0,                        // 0=any, 1=mobile, 2=desktop
#   "exclude_politic": 1,                     // recommended for safety
#   "exclude_crypto": 1
# }
#
# Without --confirm: prints body that would be sent.
# With --confirm: actually creates ad. Returns server JSON {ok:true, ad_id, redirect_to}.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] && { echo "usage: create-ad.sh <params.json> [--confirm]" >&2; exit 1; }
PARAMS_FILE="$1"; CONFIRM="${2:-}"

[ -f "$PARAMS_FILE" ] || { echo "params file not found: $PARAMS_FILE" >&2; exit 1; }

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

# Build URL-encoded body from JSON. Inject sensible defaults if missing.
BODY=$(python3 - "$PARAMS_FILE" "$ADS_OWNER_ID" <<'PY'
import json, sys, urllib.parse
params = json.load(open(sys.argv[1]))
owner_id = sys.argv[2]

# Defaults required by the form (the JS submit reads these even when blank)
defaults = {
    "button":          "Join",
    "placement":       "feed",
    "device":          "0",       # 0 = any
    "active":          "1",       # 1 = submit for review immediately
    "use_schedule":    "0",
    "views_per_user":  "1",
    "exclude_politic": "1",       # safety on by default — flip to 0 if needed
    "exclude_crypto":  "1",
    "confirmed":       "1",       # acknowledges Telegram's pre-submit checkbox
}
# If a media id is supplied, picture must be 1
if params.get("media") and not params.get("picture"):
    params["picture"] = "1"

merged = {**defaults, **params}
parts = ["method=createAd", f"owner_id={urllib.parse.quote(owner_id)}"]
for k, v in merged.items():
    if v is None or v == "":
        continue
    if isinstance(v, bool):
        v = "1" if v else "0"
    parts.append(f"{urllib.parse.quote(str(k))}={urllib.parse.quote(str(v))}")
print("&".join(parts))
PY
)

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/new" \
    '{dry_run: true, would_post: {referer: $ref, body_truncated: ($body[:500] + "...")}}'
  exit 0
fi

ads_post "/account/ad/new" "$BODY"; echo
