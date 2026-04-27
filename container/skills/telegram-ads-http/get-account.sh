#!/usr/bin/env bash
# get-account.sh — fetch account snapshot (campaigns + balance) as JSON.
#
# Output: JSON to stdout
# {
#   "ok": true,
#   "owner_name": "Shakhruz Ashot Ashirov",
#   "balance_ton": 12.40,
#   "currency_decimals": 2,
#   "currency_rate_usd": 1.12,
#   "campaigns": [{ ad_id, title, text, status, budget, spent, views, clicks, ctr, ... }]
# }

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

trap ads_cleanup EXIT

if ! ads_init; then
  echo '{"ok":false,"error":"init_failed","reason":"see stderr"}'
  exit 1
fi

# Pagination: /account inlines first batch, but if user has many ads we walk
# `getAdsList` with next_offset_id until exhausted.
ALL_ITEMS_FILE=$(mktemp); trap "rm -f $ALL_ITEMS_FILE; ads_cleanup" EXIT
echo "[]" > "$ALL_ITEMS_FILE"
NEXT_OFFSET="0"
PAGE_NUM=0
while [ -n "$NEXT_OFFSET" ] && [ "$PAGE_NUM" -lt 50 ]; do
  RESP=$(ads_post "/account" "method=getAdsList&owner_id=${ADS_OWNER_ID}&offset=${NEXT_OFFSET}")
  if ! echo "$RESP" | jq -e '.ok' >/dev/null 2>&1; then
    break  # API rejected, fall back to inline parse
  fi
  # Append items, set next offset
  jq -s '.[0] + .[1].items' "$ALL_ITEMS_FILE" <(echo "$RESP") > "${ALL_ITEMS_FILE}.tmp" && mv "${ALL_ITEMS_FILE}.tmp" "$ALL_ITEMS_FILE"
  NEXT_OFFSET=$(echo "$RESP" | jq -r '.next_offset_id // empty')
  PAGE_NUM=$((PAGE_NUM + 1))
  [ -z "$NEXT_OFFSET" ] && break
done

python3 - "$ADS_INITIAL_HTML" "$ALL_ITEMS_FILE" <<'PY'
import json, re, sys
src = open(sys.argv[1], "r", encoding="utf-8").read()
api_items = []
try:
    api_items = json.load(open(sys.argv[2])) or []
except Exception:
    api_items = []

# Find Aj.init({...}) — balanced brace scan
m = re.search(r'\{"version":\d+,"apiUrl":', src)
if not m:
    print(json.dumps({"ok": False, "error": "no_aj_init"}))
    sys.exit(0)
i = m.start()
depth, j = 0, i
in_str = False
escape = False
while j < len(src):
    c = src[j]
    if in_str:
        if escape:
            escape = False
        elif c == '\\':
            escape = True
        elif c == '"':
            in_str = False
    else:
        if c == '"':
            in_str = True
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                j += 1
                break
    j += 1
blob = src[i:j]
try:
    obj = json.loads(blob)
except json.JSONDecodeError as e:
    print(json.dumps({"ok": False, "error": f"json_parse: {e}", "blob_head": blob[:200]}))
    sys.exit(0)

state = obj.get("state", {})
inline_items = (state.get("initialAdsList") or {}).get("items") or []

# Prefer API-paginated full list; fall back to inline if API call failed
items = api_items if api_items else inline_items

# Owner name from page header
owner_name = None
nm = re.search(r'pr-header-account-name[^>]*>([^<]+)', src)
if nm:
    owner_name = nm.group(1).strip()

# Balance from currency block in header
balance = None
bm = re.search(r'💎</span>(\d+)<span class="amount-frac">\.(\d+)', src)
if bm:
    balance = float(f"{bm.group(1)}.{bm.group(2)}")

out = {
    "ok": True,
    "owner_name": owner_name,
    "balance_ton": balance,
    "currency_decimals": state.get("ownerCurrencyDecimals"),
    "currency_rate_usd": state.get("ownerCurrencyRate"),
    "campaigns": [
        {k: it.get(k) for k in (
            "ad_id", "title", "text", "trg_type", "target", "tme_path",
            "status", "budget", "spent", "daily_budget", "daily_spent",
            "views", "clicks", "actions", "ctr", "cvr", "cpm", "cpc", "cpa", "date"
        )}
        for it in items
    ],
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
