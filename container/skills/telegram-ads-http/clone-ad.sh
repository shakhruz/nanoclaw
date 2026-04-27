#!/usr/bin/env bash
# clone-ad.sh <src_ad_id> [--confirm] — create a Draft copy of an existing ad.
#
# Useful for A/B testing: clone a successful campaign and modify one factor
# (text / cpm / targeting). Result is a new On Hold draft you can edit, then
# activate via edit-status.sh <new_id> 1 --confirm.
#
# Telegram requires a two-step confirm flow (returns confirm_hash on first call,
# expects same call with confirm_hash on second). We auto-handle that under
# --confirm.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] && { echo "usage: clone-ad.sh <src_ad_id> [--confirm]" >&2; exit 1; }
SRC_AD_ID="$1"; CONFIRM="${2:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

BODY="method=createDraftFromAd&ad_id=${SRC_AD_ID}&owner_id=${ADS_OWNER_ID}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/$SRC_AD_ID" --arg id "$SRC_AD_ID" \
    '{dry_run: true, would_clone_from_ad: $id, would_post: {referer: $ref, body: $body}}'
  exit 0
fi

# First call — may return confirm_hash if Telegram requires confirmation
RESP1=$(ads_post "/account/ad/$SRC_AD_ID" "$BODY")
CONFIRM_HASH=$(echo "$RESP1" | jq -r '.confirm_hash // empty')
if [ -n "$CONFIRM_HASH" ]; then
  # Second call with confirm_hash
  RESP2=$(ads_post "/account/ad/$SRC_AD_ID" "${BODY}&confirm_hash=${CONFIRM_HASH}")
  echo "$RESP2"
else
  echo "$RESP1"
fi
echo
