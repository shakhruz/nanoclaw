#!/usr/bin/env bash
# get-ad.sh <ad_id> — fetch a single ad's full details + extract owner_id needed for writes.
#
# Output: JSON to stdout
# {
#   "ok": true,
#   "ad_id": 36,
#   "owner_id": "<from form hidden field>",
#   "title": "...",
#   "text": "...",
#   "status": "On Hold",
#   "budget": 0.7,
#   ...
# }

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

trap ads_cleanup EXIT

if [ -z "${1:-}" ]; then
  echo '{"ok":false,"error":"missing_ad_id"}' >&2
  exit 1
fi
AD_ID="$1"

if ! ads_init; then
  echo '{"ok":false,"error":"init_failed"}'
  exit 1
fi

PAGE=$(mktemp)
trap "rm -f $PAGE; ads_cleanup" EXIT
ads_get "/account/ad/$AD_ID" > "$PAGE"

python3 - "$PAGE" "$AD_ID" <<'PY'
import json, re, sys
src = open(sys.argv[1], "r", encoding="utf-8").read()
ad_id = sys.argv[2]

# owner_id often is a hidden input or in Aj.init state
owner_id = None
om = re.search(r'name="owner_id"[^>]*value="([^"]+)"', src)
if om:
    owner_id = om.group(1)
else:
    om = re.search(r'"owner_id"\s*:\s*"?([A-Za-z0-9_=-]+)"?', src)
    if om:
        owner_id = om.group(1)

# Extract Aj.init state for this ad
m = re.search(r'\{"version":\d+,"apiUrl":', src)
state = None
if m:
    i = m.start(); depth = 0; j = i; in_str = False; esc = False
    while j < len(src):
        c = src[j]
        if in_str:
            if esc: esc = False
            elif c == '\\': esc = True
            elif c == '"': in_str = False
        else:
            if c == '"': in_str = True
            elif c == '{': depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    j += 1
                    break
        j += 1
    try:
        state = json.loads(src[i:j])
    except json.JSONDecodeError:
        state = None

ad_data = {}
if state:
    s = state.get("state") or {}
    ad_data = s.get("ad") or {}
    # Aj.init's "state" object on /account/ad/<id> exposes specific keys:
    # ownerId, adId, textMaxLength, previewData, mediaPhotoSizeLimit, mediaVideoSizeLimit, scheduleTpl
    ad_data.setdefault("preview", s.get("previewData"))
    ad_data.setdefault("schedule_tpl", s.get("scheduleTpl"))

# Decline reason — present in HTML when status == Declined
decline = None
dh = re.search(r'pr-decline-block-header[^>]*>([^<]+)', src)
dr = re.search(r'pr-decline-reason[^>]*>([^<]+)', src)
dd = re.search(r'pr-decline-reason-desc[^>]*>([^<]+)', src)
if dh or dr:
    decline = {
        "header": dh.group(1).strip() if dh else None,
        "reason": dr.group(1).strip() if dr else None,
        "description": dd.group(1).strip() if dd else None,
    }

# Status text in header
status = None
sm = re.search(r'pr-table-status[^>]*>([^<]+)', src)
if sm:
    status = sm.group(1).strip()

print(json.dumps({
    "ok": True,
    "ad_id": int(ad_id),
    "owner_id": owner_id,
    "status": status,
    "decline": decline,
    "ad": ad_data,
}, ensure_ascii=False, indent=2))
PY
