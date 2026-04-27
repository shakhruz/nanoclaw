#!/bin/bash
# instagram-daily-report — pulls organic (Zernio) + ads (Meta + Apify filter)
# for @ashotaiexpert. Outputs Markdown to stdout. Mila wraps for chat.
#
# Sources:
#   - Zernio API ($ZERNIO_API_KEY env)        — organic IG
#   - Meta Graph API (config.json:meta_ads)   — paid ads
#   - Apify ($APIFY_TOKEN env)                — owner_username filter

set -e

CFG="${CFG:-/workspace/group/config.json}"
WD="${WD:-/workspace/group/instagram-daily-report}"
TARGET_USERNAME="${TARGET_USERNAME:-ashotaiexpert}"
PERMALINK_CACHE="${PERMALINK_CACHE:-$WD/permalink-cache.json}"
FOLLOWER_HISTORY="${FOLLOWER_HISTORY:-$WD/follower-history.jsonl}"

mkdir -p "$WD"

[ ! -f "$CFG" ] && { echo "config not found: $CFG" >&2; exit 1; }
[ -z "$ZERNIO_API_KEY" ] && { echo "ZERNIO_API_KEY not in env" >&2; exit 1; }
[ -z "$APIFY_TOKEN" ] && { echo "APIFY_TOKEN not in env" >&2; exit 1; }

META_TOKEN=$(jq -r '.meta_ads.access_token // empty' "$CFG")
META_ACT=$(jq -r '.meta_ads.primary_ad_account // empty' "$CFG")
[ -z "$META_TOKEN" ] && { echo "meta_ads.access_token missing in config" >&2; exit 1; }

today=$(date +%Y-%m-%d)
yest=$(python3 -c "import datetime;print((datetime.date.today()-datetime.timedelta(days=1)).isoformat())")
weekago=$(python3 -c "import datetime;print((datetime.date.today()-datetime.timedelta(days=7)).isoformat())")

echo "# 📊 Instagram daily report — @${TARGET_USERNAME}"
echo "_$today (Asia/Tashkent)_"
echo

# ───────────────────────────────────────────────────────────────
# Section A — Organic (Zernio)
# ───────────────────────────────────────────────────────────────
echo "## A. Organic (Zernio)"
echo

ZERNIO_BASE="https://zernio.com/api/v1"

# Pull analytics with bigger limit to get posts + accounts metadata in one call
ANALYTICS=$(curl -s "$ZERNIO_BASE/analytics?limit=30" -H "Authorization: Bearer $ZERNIO_API_KEY")

# Find IG account (should be exactly 1)
IG_DATA=$(echo "$ANALYTICS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ig = next((a for a in d.get('accounts', []) if a.get('platform') == 'instagram'), None)
if ig:
    print(json.dumps({
        'id': ig['_id'],
        'displayName': ig.get('displayName'),
        'username': ig.get('username'),
        'followers': ig.get('followersCount'),
        'lastSync': ig.get('followersLastUpdated'),
    }))
else:
    print('null')
")

if [ "$IG_DATA" = "null" ]; then
  echo "⚠️ Instagram аккаунт не найден в Zernio. Подключи в zernio.com → Accounts."
else
  IG_ID=$(echo "$IG_DATA" | jq -r '.id')
  IG_USERNAME=$(echo "$IG_DATA" | jq -r '.username')
  IG_FOLLOWERS=$(echo "$IG_DATA" | jq -r '.followers')
  IG_SYNC=$(echo "$IG_DATA" | jq -r '.lastSync')

  echo "**Подписчики:** $IG_FOLLOWERS (@$IG_USERNAME)"
  echo "  _последний sync Zernio: $IG_SYNC_"

  # Append to follower history (one snapshot per day max)
  TODAY_RECORDED=$(grep -l "$today" "$FOLLOWER_HISTORY" 2>/dev/null || true)
  if [ -z "$TODAY_RECORDED" ] || ! grep -q "\"$today\"" "$FOLLOWER_HISTORY" 2>/dev/null; then
    echo "{\"date\":\"$today\",\"followers\":$IG_FOLLOWERS}" >> "$FOLLOWER_HISTORY"
  fi

  # Compute deltas from history
  DELTAS=$(python3 -c "
import json, sys, datetime
from pathlib import Path
hist_file = Path('$FOLLOWER_HISTORY')
if not hist_file.exists():
    print('{}')
    sys.exit()
hist = {}
for line in hist_file.read_text().strip().split('\n'):
    if not line: continue
    r = json.loads(line)
    hist[r['date']] = r['followers']
today = '$today'
curr = $IG_FOLLOWERS
yest = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
weekago = (datetime.date.today() - datetime.timedelta(days=7)).isoformat()
out = {}
if yest in hist:
    out['day'] = curr - hist[yest]
if weekago in hist:
    out['week'] = curr - hist[weekago]
print(json.dumps(out))
")

  DAY_DELTA=$(echo "$DELTAS" | jq -r '.day // empty')
  WEEK_DELTA=$(echo "$DELTAS" | jq -r '.week // empty')
  if [ -n "$DAY_DELTA" ]; then
    SIGN=$([ "$DAY_DELTA" -ge 0 ] && echo "+" || echo "")
    echo "  • за сутки: ${SIGN}${DAY_DELTA}"
  else
    echo "  • за сутки: _нет данных_ (history накапливается, ждать сутки)"
  fi
  if [ -n "$WEEK_DELTA" ]; then
    SIGN=$([ "$WEEK_DELTA" -ge 0 ] && echo "+" || echo "")
    echo "  • за неделю: ${SIGN}${WEEK_DELTA}"
  fi

  echo

  # Posting frequency + engagement rate
  FREQ=$(curl -s "$ZERNIO_BASE/analytics/posting-frequency" -H "Authorization: Bearer $ZERNIO_API_KEY")
  IG_FREQ=$(echo "$FREQ" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ig = next((f for f in d.get('frequency', []) if f.get('platform') == 'instagram'), None)
if ig:
    print(f\"posts/week={ig.get('posts_per_week', '?')}  engagement_rate={ig.get('avg_engagement_rate', 0):.2f}%  avg_engagement={ig.get('avg_engagement', 0)}\")
")
  [ -n "$IG_FREQ" ] && echo "**Активность:** $IG_FREQ"

  echo
  # Top-3 posts last 7d (filter by IG platform + date)
  echo "**Топ-3 поста за неделю (по reach/views):**"
  echo "$ANALYTICS" | python3 -c "
import sys, json, datetime
d = json.load(sys.stdin)
posts = [p for p in d.get('posts', [])
         if p.get('platform') == 'instagram'
         and p.get('publishedAt', '') >= '$weekago']
posts.sort(key=lambda p: -(p.get('analytics', {}).get('reach') or p.get('analytics', {}).get('views') or 0))
if not posts:
    print('  _(нет постов на IG за последние 7 дней)_')
else:
    for p in posts[:3]:
        a = p.get('analytics', {}) or {}
        reach = a.get('reach') or a.get('views') or 0
        likes = a.get('likes', 0)
        saves = a.get('saves', 0)
        comments = a.get('comments', 0)
        text = (p.get('content') or '').replace('\n', ' ')[:60].strip() or '(no caption)'
        url = p.get('platformPostUrl', '')
        print(f'  • {reach} reach / {likes} ❤ / {saves} 🔖 / {comments} 💬 — {text}')
        if url: print(f'     {url}')
"
fi

echo
echo "---"
echo

# ───────────────────────────────────────────────────────────────
# Section B — Paid Ads (Meta + Apify filter)
# ───────────────────────────────────────────────────────────────
echo "## B. Paid Ads (Meta — only @${TARGET_USERNAME})"
echo

API="https://graph.facebook.com/v21.0"

ADS=$(curl -sG "$API/$META_ACT/ads" \
  --data-urlencode 'fields=id,name,status,effective_status,creative{id,instagram_permalink_url},insights.date_preset(yesterday){spend,impressions,clicks,ctr,cpc,actions}' \
  --data-urlencode 'effective_status=["ACTIVE","PAUSED"]' \
  --data-urlencode 'limit=100' \
  --data-urlencode "access_token=$META_TOKEN")

ERR=$(echo "$ADS" | jq -r '.error.message // empty')
if [ -n "$ERR" ]; then
  echo "⚠️ Meta API: $ERR"
else
  PERMALINKS=$(echo "$ADS" | jq -r '[.data[]?.creative.instagram_permalink_url] | map(select(. != null)) | unique | .[]')

  [ -f "$PERMALINK_CACHE" ] || echo '{}' > "$PERMALINK_CACHE"

  UNRESOLVED=()
  while IFS= read -r URL; do
    [ -z "$URL" ] && continue
    OWNER=$(jq -r --arg u "$URL" '.[$u] // empty' "$PERMALINK_CACHE")
    [ -z "$OWNER" ] && UNRESOLVED+=("$URL")
  done <<< "$PERMALINKS"

  if [ ${#UNRESOLVED[@]} -gt 0 ]; then
    echo "_резолвлю ${#UNRESOLVED[@]} новых permalink через Apify..._" >&2
    PAYLOAD=$(printf '%s\n' "${UNRESOLVED[@]}" | jq -R . | jq -s '{username: .}')
    RESULT=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~instagram-post-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=180" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD")
    echo "$RESULT" | jq --slurpfile cache "$PERMALINK_CACHE" 'reduce .[] as $i ($cache[0]; .[$i.url] = $i.ownerUsername)' > "${PERMALINK_CACHE}.tmp"
    mv "${PERMALINK_CACHE}.tmp" "$PERMALINK_CACHE"
  fi

  FILTERED=$(echo "$ADS" | jq --slurpfile cache "$PERMALINK_CACHE" --arg u "$TARGET_USERNAME" '
    .data
    | map(select(
        (.creative.instagram_permalink_url // "") as $url
        | $cache[0][$url] == $u
      ))
  ')

  COUNT=$(echo "$FILTERED" | jq 'length')
  ACTIVE_COUNT=$(echo "$FILTERED" | jq '[.[] | select(.effective_status == "ACTIVE")] | length')

  echo "**Кампании (наш аккаунт):** $COUNT всего, $ACTIVE_COUNT активных"
  echo

  if [ "$COUNT" = "0" ]; then
    echo "📭 На @$TARGET_USERNAME платная реклама **не запускалась** через этот ad account за последние 30 дней."
    echo
    echo "Все активные ads на ${META_ACT} ведут на другие IG-аккаунты (см. \`meta-ads/list.sh\` для полной картины)."
    echo
    echo "💡 Если хочешь стартовать paid promotion @$TARGET_USERNAME — Таргетолог может подготовить план кампании. Скажи."
  else
    YEST_SPEND=$(echo "$FILTERED" | jq '[.[].insights.data[0].spend // "0" | tonumber] | add')
    echo "**Расход вчера:** \$$YEST_SPEND"
    echo
    echo "**Активные ads — yesterday:**"
    echo "$FILTERED" | jq -r '.[] | select(.effective_status == "ACTIVE") |
      "  • [\(.id)] \(.name[0:50])\n     spend=$\(.insights.data[0].spend // "0")  CTR=\(.insights.data[0].ctr // "0")%  CPC=$\(.insights.data[0].cpc // "0")  clicks=\(.insights.data[0].clicks // "0")"'
  fi
fi

echo
echo "---"
echo

# ───────────────────────────────────────────────────────────────
# Section C — Synthesis (Mila adds in chat)
# ───────────────────────────────────────────────────────────────
echo "## C. Что делать сегодня"
echo
echo "_(Mila синтезирует на основе данных выше + контекста; см. CLAUDE.md → секция «Дневной отчёт»)_"
