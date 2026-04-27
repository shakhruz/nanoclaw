---
name: zernio-analytics
description: Analyze social media presence across all connected platforms via Zernio API. Pulls analytics (views, engagement, demographics, best time to post), content performance, follower growth for Instagram, YouTube, Facebook, LinkedIn, Twitter/X, Telegram. Use when asked to analyze social media analytics, check performance, or build a social media report.
---

# Zernio Social Media Analytics

Pull comprehensive analytics from all connected social media platforms via the Zernio API. Enriches client profiles and wiki with data that platform-specific scrapers (Apify) can't access — like Instagram demographics, YouTube watch time, and cross-platform comparisons.

## Prerequisites

- `$ZERNIO_API_KEY` — env var (container-runner injects it)

## API Base

```
Base URL: https://zernio.com/api/v1
Auth: -H "Authorization: Bearer $ZERNIO_API_KEY"
```

## Trigger

- "аналитика соцсетей", "social media analytics"
- "покажи статистику", "performance report"
- "как дела в соцсетях", "zernio analytics"
- Called from client-prep for cross-platform stats

## Workflow

### Phase 0: Setup

```bash
export WD=/workspace/group/zernio-analytics
mkdir -p $WD
```

### Phase 1: List Connected Accounts

```bash
curl -s "https://zernio.com/api/v1/accounts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/accounts.json
```

Parse and display:
```bash
node -e "
const d=JSON.parse(require('fs').readFileSync('$WD/accounts.json','utf8'));
(d.accounts||[]).forEach(a=>console.log(a.platform, '|', a.displayName||a.platformUsername, '| id:', a._id));
"
```

Send progress: "Подключено N платформ: <list>"

### Phase 2: Pull Analytics

**API pattern** — all endpoints use the same base and auth header. Save each response to `$WD/<name>.json`:

```bash
# Template:
curl -s "https://zernio.com/api/v1/analytics/<ENDPOINT>?<PARAMS>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/<name>.json
```

**Endpoints to pull:**

| Endpoint | Params | Output file |
|----------|--------|-------------|
| `analytics?limit=100` | — | `analytics-posts.json` |
| `analytics/daily-metrics` | `startDate=$START&endDate=$END` | `daily-metrics.json` |
| `analytics/best-time-to-post` | — | `best-time.json` |
| `analytics/posting-frequency` | — | `frequency.json` |
| `analytics/follower-stats` | `accountId=<ID>` (per account) | `follower-stats.json` |
| `analytics/instagram-demographics` | `accountId=<IG_ID>` | `ig-demographics.json` |
| `analytics/instagram-account-insights` | `accountId=<IG_ID>&period=last_30_days` | `ig-insights.json` |
| `analytics/youtube-daily-views` | `accountId=<YT_ID>&startDate=$START&endDate=$END` | `yt-views.json` |
| `analytics/youtube-demographics` | `accountId=<YT_ID>` | `yt-demographics.json` |

Date range setup:
```bash
START=$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)
END=$(date +%Y-%m-%d)
```

Note: platform-specific endpoints (instagram-*, youtube-*) may require paid Zernio plans. If response is HTML instead of JSON, skip that endpoint.

### Phase 3: Analyze & Aggregate

```bash
node -e "
const data=JSON.parse(require('fs').readFileSync('$WD/analytics-posts.json','utf8'));
const posts=data.posts||[];
const platforms={};
let totalViews=0,totalLikes=0,totalComments=0,totalShares=0;
posts.forEach(p=>{
  const pl=p.platform||'unknown';
  if(!platforms[pl])platforms[pl]={count:0,views:0,likes:0,comments:0,shares:0,topPost:null,topViews:0};
  platforms[pl].count++;
  const v=p.analytics?.views||0, l=p.analytics?.likes||0, c=p.analytics?.comments||0, s=p.analytics?.shares||0;
  platforms[pl].views+=v; platforms[pl].likes+=l; platforms[pl].comments+=c; platforms[pl].shares+=s;
  if(v>platforms[pl].topViews){platforms[pl].topViews=v; platforms[pl].topPost=p.content?.slice(0,60);}
  totalViews+=v; totalLikes+=l; totalComments+=c; totalShares+=s;
});
const result={totalPosts:posts.length,totalViews,totalLikes,totalComments,totalShares,platforms,
  avgEngagement:posts.length>0?((totalLikes+totalComments+totalShares)/posts.length).toFixed(1):0};
require('fs').writeFileSync('$WD/summary.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));
"
```

### Phase 4: Generate Report

Send via `send_message` — include: period (last 30 days), total metrics (posts/views/likes/comments/engagement), per-platform table (platform | posts | views | likes | top post), best time to post, follower growth, demographics (if available), and 2-3 data-driven recommendations.

### Phase 5: Save to Wiki

Create/update `wiki/entities/social-media-analytics.md` with frontmatter (`type: entity`, `subtype: social-analytics`, tags, related links). Sections: Connected Platforms, Overall Metrics, Per-Platform Breakdown, Top Content, Best Time, Demographics, Follower Growth, Recommendations.

Update wiki index + log + git commit.

### Phase 6: Merge with Client Data

If analyzing for a specific client (not yourself):
- Merge Zernio data into `client-profiles/<name>/profile.json`
- Add cross-platform engagement metrics to client-prep briefing
- Compare with Apify data (Zernio may have newer metrics)

## For Client Analysis

When analyzing a client's socials (not your own): client must connect to Zernio first, OR use Zernio for YOUR accounts + Apify for client's public data. Best: use both — Apify for content scraping, Zernio for analytics/demographics.

## Error Handling

- **HTML response instead of JSON:** endpoint requires higher Zernio plan — skip and note as unavailable.
- **Empty analytics or account not found:** verify account ID from Phase 1; account may not be synced yet.
