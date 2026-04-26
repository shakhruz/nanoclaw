#!/usr/bin/env bash
# edit-cpm.sh <ad_id> <cpm_ton> [--confirm] — change ad's CPM bid.
#
# Telegram Ads CPM is in TON (e.g. 0.6 = 0.6 TON per 1000 views).
# Min ~0.6, max no formal cap but pricing scales.
#
# Output: server JSON
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] || [ -z "${2:-}" ] && { echo "usage: edit-cpm.sh <ad_id> <cpm_ton> [--confirm]" >&2; exit 1; }
AD_ID="$1"; CPM="$2"; CONFIRM="${3:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

BODY="method=editAdCPM&ad_id=${AD_ID}&owner_id=${ADS_OWNER_ID}&cpm=${CPM}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/$AD_ID" \
    '{dry_run: true, would_post: {referer: $ref, body: $body}}'
  exit 0
fi

ads_post "/account/ad/$AD_ID" "$BODY"; echo
