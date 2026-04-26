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

python3 - "$ADS_INITIAL_HTML" <<'PY'
import json, re, sys
src = open(sys.argv[1], "r", encoding="utf-8").read()

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
items = (state.get("initialAdsList") or {}).get("items") or []

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
