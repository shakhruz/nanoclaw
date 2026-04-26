#!/bin/bash
# Meta Ads — list ads with insights, ranked by spend
# Usage: list.sh [date_preset]   default: last_7d
. "$(dirname "$0")/lib.sh"

PRESET="${1:-last_7d}"

ADS=$(meta_get "$META_ACT/ads" \
  --data-urlencode 'fields=id,name,status,effective_status,creative{id,instagram_permalink_url,object_type},insights.date_preset('"$PRESET"'){spend,impressions,clicks,ctr,cpc,cpm,reach,actions}' \
  --data-urlencode 'effective_status=["ACTIVE","PAUSED"]' \
  --data-urlencode 'limit=100')
meta_check_error "$ADS" || exit 1

echo "## Ads — $PRESET (отсортировано по spend)"
echo
echo "$ADS" | jq -r '
  .data
  | map(. + {_spend: ((.insights.data[0].spend // "0") | tonumber)})
  | sort_by(-._spend)
  | .[]
  | select(._spend > 0 or .effective_status == "ACTIVE")
  | "• [\(.id)] \(.name) — \(.effective_status)" +
    (if .insights.data[0] then
      "\n   spend=$\(.insights.data[0].spend)  impr=\(.insights.data[0].impressions)  clicks=\(.insights.data[0].clicks)  CTR=\(.insights.data[0].ctr)%  CPC=$\(.insights.data[0].cpc)"
     else "\n   (нет данных)" end) +
    (if .creative.instagram_permalink_url then "\n   IG: \(.creative.instagram_permalink_url)" else "" end)
'
