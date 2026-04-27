#!/bin/bash
# Meta Ads — insights for a specific entity
# Usage: insights.sh <entity_id> [date_preset] [breakdown]
#   entity_id: campaign / adset / ad ID, or "account" for ad account
#   date_preset: today | yesterday | last_3d | last_7d | last_14d | last_30d | last_90d | this_month | last_month  (default: last_7d)
#   breakdown: age | gender | country | placement | device_platform | publisher_platform  (optional)
. "$(dirname "$0")/lib.sh"

ENTITY="${1:?entity_id required (or 'account')}"
PRESET="${2:-last_7d}"
BREAKDOWN="${3:-}"

[ "$ENTITY" = "account" ] && ENTITY="$META_ACT"

ARGS=(
  --data-urlencode 'fields=spend,impressions,reach,clicks,ctr,cpc,cpm,frequency,actions,cost_per_action_type'
  --data-urlencode "date_preset=$PRESET"
)
[ -n "$BREAKDOWN" ] && ARGS+=( --data-urlencode "breakdowns=$BREAKDOWN" )

INS=$(meta_get "$ENTITY/insights" "${ARGS[@]}")
meta_check_error "$INS" || exit 1

echo "## Insights — $ENTITY ($PRESET${BREAKDOWN:+, breakdown=$BREAKDOWN})"
echo "$INS" | jq .
