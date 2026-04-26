#!/usr/bin/env bash
# edit-title.sh <ad_id> <new_title> [--confirm] — rename ad.
# Title is internal label for organization, not shown in the ad itself.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] || [ -z "${2:-}" ] && { echo "usage: edit-title.sh <ad_id> <new_title> [--confirm]" >&2; exit 1; }
AD_ID="$1"; TITLE="$2"; CONFIRM="${3:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

# url-encode title via jq
TITLE_ENC=$(jq -rn --arg t "$TITLE" '$t|@uri')
BODY="method=editAdTitle&ad_id=${AD_ID}&owner_id=${ADS_OWNER_ID}&title=${TITLE_ENC}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/$AD_ID" --arg title "$TITLE" \
    '{dry_run: true, would_post: {referer: $ref, body: $body}, new_title: $title}'
  exit 0
fi

ads_post "/account/ad/$AD_ID" "$BODY"; echo
