#!/bin/bash
# Meta Ads — update budget on an ad set
# Usage: update-budget.sh <adset_id> <amount_usd> [daily|lifetime]
#   amount_usd: new budget in dollars (e.g. 5.00)
#   mode: 'daily' (default) or 'lifetime'
. "$(dirname "$0")/lib.sh"

ADSET="${1:?adset_id required}"
AMOUNT="${2:?amount in USD required}"
MODE="${3:-daily}"

CENTS=$(python3 -c "print(int(round(float('$AMOUNT')*100)))")
case "$MODE" in
  daily)    BODY="{\"daily_budget\":$CENTS}";;
  lifetime) BODY="{\"lifetime_budget\":$CENTS}";;
  *) echo "mode must be 'daily' or 'lifetime'" >&2; exit 1;;
esac

RESP=$(meta_post "$ADSET" "$BODY")
meta_check_error "$RESP" || exit 1
echo "✅ adset $ADSET → $MODE budget = \$$AMOUNT ($CENTS cents)"
echo "$RESP"
