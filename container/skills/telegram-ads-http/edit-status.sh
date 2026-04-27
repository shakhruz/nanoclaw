#!/usr/bin/env bash
# edit-status.sh <ad_id> <0|1> [--confirm] — toggle ad active status.
#
# active=1 → start the ad (move to Active / In Review)
# active=0 → pause the ad (move to On Hold)
#
# Requires --confirm flag for actual mutation. Without --confirm, prints what
# would be sent (dry-run).
#
# Output: server JSON to stdout

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

trap ads_cleanup EXIT

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "usage: edit-status.sh <ad_id> <0|1> [--confirm]" >&2
  exit 1
fi
AD_ID="$1"
ACTIVE="$2"
CONFIRM="${3:-}"

if [[ ! "$ACTIVE" =~ ^[01]$ ]]; then
  echo "active must be 0 or 1" >&2
  exit 1
fi

if ! ads_init; then
  echo '{"ok":false,"error":"init_failed"}'
  exit 1
fi

BODY="method=editAdStatus&ad_id=${AD_ID}&active=${ACTIVE}&owner_id=${ADS_OWNER_ID}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n \
    --arg url "$ADS_BASE/api?hash=$ADS_HASH" \
    --arg body "$BODY" \
    --arg ref "$ADS_BASE/account/ad/$AD_ID" \
    '{dry_run: true, would_post: {url: $url, referer: $ref, body: $body}}'
  exit 0
fi

ads_post "/account/ad/$AD_ID" "$BODY"
echo
