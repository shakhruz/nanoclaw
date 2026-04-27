#!/bin/bash
# Meta Ads — boost an existing Instagram post by duplicating an existing ad
#
# Why duplicate: without instagram_basic permission we can't enumerate IG media
# directly. But our ad account already has creatives referencing IG posts we
# previously boosted. Strategy: copy a working ad → swap the creative if needed
# → set new budget & duration → activate.
#
# Usage:
#   boost.sh <source_ad_id> <budget_usd> <days> [name_suffix]
#
#   source_ad_id: an existing ad to use as template (run list.sh to find one)
#   budget_usd:   lifetime budget in dollars (e.g. 10.00)
#   days:         duration in days from now
#   name_suffix:  optional suffix for new campaign name
#
# Output: new campaign_id, adset_id, ad_id (all PAUSED for review).

. "$(dirname "$0")/lib.sh"

SRC="${1:?source_ad_id required (use list.sh to find one)}"
BUDGET_USD="${2:?budget_usd required}"
DAYS="${3:?days required}"
SUFFIX="${4:- — boost $(date +%Y-%m-%d)}"

CENTS=$(python3 -c "print(int(round(float('$BUDGET_USD')*100)))")
START=$(date -u +%Y-%m-%dT%H:%M:%S+0000)
END=$(python3 -c "import datetime;print((datetime.datetime.utcnow()+datetime.timedelta(days=$DAYS)).strftime('%Y-%m-%dT%H:%M:%S+0000'))")

echo "Step 1/3: deep-copy ad $SRC..."
COPY=$(meta_post "$SRC/copies" "{\"deep_copy\":true,\"status_option\":\"PAUSED\",\"rename_options\":{\"rename_suffix\":\"$SUFFIX\"}}")
meta_check_error "$COPY" || exit 1

NEW_AD=$(echo "$COPY" | jq -r '.copied_ad_id // .ad_id // empty')
[ -z "$NEW_AD" ] && { echo "no copied_ad_id in response"; echo "$COPY" | jq .; exit 1; }
echo "  → new ad: $NEW_AD"

echo "Step 2/3: lookup adset_id and campaign_id of new ad..."
NEW_META=$(meta_get "$NEW_AD" --data-urlencode 'fields=adset_id,campaign_id')
NEW_ADSET=$(echo "$NEW_META" | jq -r .adset_id)
NEW_CAMP=$(echo "$NEW_META" | jq -r .campaign_id)
echo "  adset=$NEW_ADSET  campaign=$NEW_CAMP"

echo "Step 3/3: set lifetime_budget=\$$BUDGET_USD ($CENTS¢) and schedule $START → $END..."
UPD=$(meta_post "$NEW_ADSET" "{\"lifetime_budget\":$CENTS,\"start_time\":\"$START\",\"end_time\":\"$END\",\"daily_budget\":null}")
meta_check_error "$UPD" || exit 1

echo
echo "✅ Boost prepared (status=PAUSED for safety)."
echo "   new campaign: $NEW_CAMP"
echo "   new adset:    $NEW_ADSET"
echo "   new ad:       $NEW_AD"
echo "   budget:       \$$BUDGET_USD lifetime, $DAYS day(s)"
echo
echo "To launch:  $(dirname "$0")/resume.sh $NEW_CAMP"
