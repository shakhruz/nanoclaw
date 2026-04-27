#!/usr/bin/env bash
# edit-daily-budget.sh <ad_id> <daily_ton> [--confirm] — set per-day spending cap.
#
# Pass 0 to remove the daily cap entirely.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] || [ -z "${2:-}" ] && { echo "usage: edit-daily-budget.sh <ad_id> <daily_ton> [--confirm]" >&2; exit 1; }
AD_ID="$1"; DAILY="$2"; CONFIRM="${3:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

BODY="method=editAdDailyBudget&ad_id=${AD_ID}&owner_id=${ADS_OWNER_ID}&daily_budget=${DAILY}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/$AD_ID" \
    '{dry_run: true, would_post: {referer: $ref, body: $body}}'
  exit 0
fi

ads_post "/account/ad/$AD_ID" "$BODY"; echo
