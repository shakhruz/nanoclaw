#!/usr/bin/env bash
# delete-ad.sh <ad_id> [--confirm] — permanently remove a draft / paused ad.
# Telegram only allows delete on Draft / On Hold ads. Active ads must be paused first.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] && { echo "usage: delete-ad.sh <ad_id> [--confirm]" >&2; exit 1; }
AD_ID="$1"; CONFIRM="${2:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

BODY="method=deleteAd&ad_id=${AD_ID}&owner_id=${ADS_OWNER_ID}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/$AD_ID" --arg id "$AD_ID" \
    '{dry_run: true, would_delete_ad: $id, would_post: {referer: $ref, body: $body}}'
  exit 0
fi

ads_post "/account/ad/$AD_ID" "$BODY"; echo
