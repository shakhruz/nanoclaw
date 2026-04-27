#!/bin/bash
# instagram-competitor-tracker — daily monitor of watched IG competitors via Apify
#
# Reads watchlist from /workspace/group/competitor-tracker/watchlist.txt (one IG username
# per line, # for comments). For each username, fetches latest 12 posts via
# apify~instagram-profile-scraper, computes engagement rate, detects viral content
# (>= 5x median ER), produces Markdown summary + per-competitor JSON snapshots.
#
# Usage:
#   tracker.sh                  — full daily report
#   tracker.sh --alert-only     — print only viral alerts (for cron summary mode)
#
# Env (auto from container):
#   APIFY_TOKEN                 — required
#   WATCHLIST                   — override watchlist path
#   DATA_DIR                    — where to save daily snapshots (default: /workspace/group/competitor-tracker/data)
#   REPORT_DIR                  — where to save reports (default: same dir / reports)
#   VIRAL_THRESHOLD             — multiplier vs median to flag viral (default: 5)

set -e

WATCHLIST="${WATCHLIST:-/workspace/group/competitor-tracker/watchlist.txt}"
DATA_DIR="${DATA_DIR:-/workspace/group/competitor-tracker/data}"
REPORT_DIR="${REPORT_DIR:-/workspace/group/competitor-tracker/reports}"
VIRAL_THRESHOLD="${VIRAL_THRESHOLD:-5}"

[ -z "$APIFY_TOKEN" ] && { echo "APIFY_TOKEN not in env" >&2; exit 1; }
[ ! -f "$WATCHLIST" ] && { echo "watchlist not found: $WATCHLIST" >&2; echo "Create it (one username per line). See SKILL.md" >&2; exit 1; }

mkdir -p "$DATA_DIR" "$REPORT_DIR"

today=$(date +%Y-%m-%d)
yest=$(python3 -c "import datetime;print((datetime.date.today()-datetime.timedelta(days=1)).isoformat())")

# Parse watchlist (strip blanks and # comments)
USERNAMES=$(grep -vE '^\s*(#|$)' "$WATCHLIST" | awk '{print $1}' | head -25)
USER_COUNT=$(echo "$USERNAMES" | wc -l | tr -d ' ')
[ "$USER_COUNT" = "0" ] && { echo "watchlist empty" >&2; exit 1; }

echo "Tracking $USER_COUNT competitors via Apify..." >&2

# Fetch all profiles in one Apify call (efficient)
PAYLOAD=$(echo "$USERNAMES" | jq -R . | jq -s '{usernames: ., resultsType: "posts", resultsLimit: 12}')
RESULT=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~instagram-profile-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=240" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Save per-user snapshots
echo "$RESULT" | jq -c '.[]?' | while IFS= read -r PROFILE; do
  USER=$(echo "$PROFILE" | jq -r '.username // empty')
  [ -z "$USER" ] && continue
  mkdir -p "$DATA_DIR/$USER"
  echo "$PROFILE" > "$DATA_DIR/$USER/$today.json"
done

# Build report
REPORT_FILE="$REPORT_DIR/$today.md"

python3 - "$DATA_DIR" "$today" "$yest" "$VIRAL_THRESHOLD" > "$REPORT_FILE" <<'PYEOF'
import json, sys
from pathlib import Path

data_dir, today, yest, thresh_s = sys.argv[1:5]
THRESH = float(thresh_s)

print(f"# Competitor tracker — {today}\n")
print(f"Apify-полученные данные по watchlist. Viral threshold: {THRESH}x median ER.\n")
print("---\n")

viral_alerts = []
rows = []

for user_dir in sorted(Path(data_dir).iterdir()):
    if not user_dir.is_dir(): continue
    today_file = user_dir / f"{today}.json"
    if not today_file.exists(): continue

    profile = json.loads(today_file.read_text())
    user = profile.get('username') or user_dir.name
    followers = profile.get('followersCount', 0) or 0
    posts = profile.get('latestPosts') or []

    # Followers delta vs yesterday
    delta_str = ""
    yest_file = user_dir / f"{yest}.json"
    if yest_file.exists():
        try:
            yp = json.loads(yest_file.read_text())
            yf = yp.get('followersCount', 0) or 0
            d = followers - yf
            if d != 0:
                sign = "+" if d > 0 else ""
                delta_str = f"{sign}{d}"
        except Exception:
            pass

    if not posts or followers == 0:
        rows.append((user, followers, 0, "(нет постов)", delta_str))
        continue

    # Compute ER per post
    enriched = []
    for p in posts:
        likes = p.get('likesCount') or 0
        comments = p.get('commentsCount') or 0
        er = (likes + comments) / followers * 100
        enriched.append({
            'er': er,
            'caption': (p.get('caption') or '').replace('\n', ' ')[:80],
            'url': p.get('url', ''),
            'likes': likes,
            'comments': comments,
            'type': p.get('type') or p.get('productType') or '?',
            'timestamp': p.get('timestamp', ''),
        })

    # Median
    ers = sorted([x['er'] for x in enriched])
    median = ers[len(ers)//2] if ers else 0

    # Viral detection
    for x in enriched:
        if median > 0 and x['er'] / median >= THRESH:
            viral_alerts.append({
                'user': user,
                'multiplier': x['er'] / median,
                'er': x['er'],
                'caption': x['caption'],
                'url': x['url'],
                'likes': x['likes'],
                'comments': x['comments'],
                'type': x['type'],
            })

    top = max(enriched, key=lambda y: y['er'])
    rows.append((user, followers, median, f"{top['er']:.2f}% ER ({top['type']})", delta_str))

# Viral alerts FIRST (most actionable)
if viral_alerts:
    print(f"## 🚨 Viral alerts ({len(viral_alerts)})\n")
    for v in sorted(viral_alerts, key=lambda z: -z['multiplier']):
        print(f"- **@{v['user']}** — {v['multiplier']:.1f}x median, {v['er']:.2f}% ER, {v['likes']:,}❤ {v['comments']:,}💬 ({v['type']})")
        if v['caption']:
            print(f"  > {v['caption']}")
        if v['url']:
            print(f"  {v['url']}")
        print()
    print("**Action:** изучить hook/формат победителя, адаптировать в свой контент-план.\n")
else:
    print("## ✓ No viral alerts today\n")

# Competitor table
print("---\n\n## Competitor snapshot\n")
print("| Competitor | Followers | Δ yest | Median ER | Top recent |")
print("|---|---|---|---|---|")
for user, fol, med, top, delta in sorted(rows, key=lambda r: -r[1]):
    print(f"| @{user} | {fol:,} | {delta or '—'} | {med:.2f}% | {top} |")

print("\n---\n")
print(f"_Snapshots saved → `{data_dir}/<user>/{today}.json`_")
PYEOF

echo "✅ Report: $REPORT_FILE" >&2

if [ "$1" = "--alert-only" ]; then
  awk '/^## 🚨/,/^---/' "$REPORT_FILE"
else
  cat "$REPORT_FILE"
fi
