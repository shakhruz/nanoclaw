#!/bin/bash
# Meta Ads — quick status: balance, active campaigns, last 7d/30d performance
. "$(dirname "$0")/lib.sh"

meta_token_warning

echo "## Meta Ads — статус ($META_ACT)"
echo

ACC=$(meta_get "$META_ACT" --data-urlencode "fields=name,balance,amount_spent,currency,account_status,disable_reason,timezone_name")
meta_check_error "$ACC" || exit 1

echo "$ACC" | jq -r '
  "Аккаунт: \(.name)",
  "Валюта: \(.currency)",
  "Статус: \(if .account_status==1 then "✅ active" else "⚠️ status=\(.account_status), reason=\(.disable_reason)" end)",
  "Lifetime spend: $\((.amount_spent|tonumber)/100)",
  "Timezone: \(.timezone_name)"'

echo
echo "### Активные кампании"
CAMP=$(meta_get "$META_ACT/campaigns" \
  --data-urlencode 'fields=id,name,objective,daily_budget,lifetime_budget,start_time,stop_time,created_time' \
  --data-urlencode 'effective_status=["ACTIVE"]' \
  --data-urlencode 'limit=50')
meta_check_error "$CAMP" || exit 1

COUNT=$(echo "$CAMP" | jq '.data | length')
echo "Найдено: $COUNT"
echo "$CAMP" | jq -r '.data | sort_by(.created_time) | reverse | .[] |
  "• [\(.id)] \(.name)\n   objective=\(.objective)  budget=\(if .daily_budget then "$\((.daily_budget|tonumber)/100)/day" elif .lifetime_budget then "$\((.lifetime_budget|tonumber)/100) lifetime" else "—" end)  start=\(.start_time // "—")  stop=\(.stop_time // "—")"'

echo
for PRESET in last_7d last_30d; do
  echo "### Performance — $PRESET"
  INS=$(meta_get "$META_ACT/insights" \
    --data-urlencode 'fields=spend,impressions,reach,clicks,ctr,cpc,cpm,frequency,actions' \
    --data-urlencode "date_preset=$PRESET")
  meta_check_error "$INS" || continue
  echo "$INS" | jq -r '.data[0] // {} |
    if . == {} then "нет данных" else
      "spend=$\(.spend)  impressions=\(.impressions)  reach=\(.reach)  clicks=\(.clicks)  CTR=\(.ctr)%  CPC=$\(.cpc)  CPM=$\(.cpm)  freq=\(.frequency)\n  actions: " +
      (([.actions[]? | "\(.action_type)=\(.value)"]) | join(", "))
    end'
  echo
done
