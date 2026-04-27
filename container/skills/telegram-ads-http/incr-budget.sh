#!/usr/bin/env bash
# incr-budget.sh <ad_id> <delta_ton> [--confirm] — top up an ad's total budget by delta TON.
#
# Examples:
#   incr-budget.sh 36 0.5 --confirm     # add 0.5 TON to ad 36's budget
#   incr-budget.sh 36 -0.3 --confirm    # decrement (Telegram may reject negative — verify in JS first)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] || [ -z "${2:-}" ] && { echo "usage: incr-budget.sh <ad_id> <delta_ton> [--confirm]" >&2; exit 1; }
AD_ID="$1"; DELTA="$2"; CONFIRM="${3:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

BODY="method=incrAdBudget&ad_id=${AD_ID}&owner_id=${ADS_OWNER_ID}&delta=${DELTA}"

if [ "$CONFIRM" != "--confirm" ]; then
  jq -n --arg body "$BODY" --arg ref "$ADS_BASE/account/ad/$AD_ID" \
    '{dry_run: true, would_post: {referer: $ref, body: $body}}'
  exit 0
fi

ads_post "/account/ad/$AD_ID" "$BODY"; echo
