---
name: zernio-analytics
description: Analyze social media presence across all connected platforms via Zernio API. Pulls analytics (views, engagement, demographics, best time to post), content performance, follower growth for Instagram, YouTube, Facebook, LinkedIn, Twitter/X, Telegram. Use when asked to analyze social media analytics, check performance, or build a social media report.
---

# Zernio Social Media Analytics

Pull comprehensive analytics from all connected social media platforms via the Zernio API. Enriches client profiles and wiki with data that platform-specific scrapers (Apify) can't access — like Instagram demographics, YouTube watch time, and cross-platform comparisons.

## Prerequisites

- `$ZERNIO_API_KEY` — env var (container-runner injects it)
- Check: `echo $ZERNIO_API_KEY | head -c 10`

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

**2a. Post-level analytics (all platforms):**
```bash
curl -s "https://zernio.com/api/v1/analytics?limit=100" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/analytics-posts.json
```

**2b. Daily metrics (last 30 days):**
```bash
START=$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)
END=$(date +%Y-%m-%d)
curl -s "https://zernio.com/api/v1/analytics/daily-metrics?startDate=$START&endDate=$END" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/daily-metrics.json
```

**2c. Best time to post:**
```bash
curl -s "https://zernio.com/api/v1/analytics/best-time-to-post" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/best-time.json
```

**2d. Posting frequency vs engagement:**
```bash
curl -s "https://zernio.com/api/v1/analytics/posting-frequency" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/frequency.json
```

**2e. Follower stats (per account):**
For each account ID from Phase 1:
```bash
curl -s "https://zernio.com/api/v1/analytics/follower-stats?accountId=<ID>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" >> $WD/follower-stats.json
```

**2f. Platform-specific (if available on plan):**
```bash
# Instagram demographics (age, city, country, gender)
curl -s "https://zernio.com/api/v1/analytics/instagram-demographics?accountId=<IG_ID>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/ig-demographics.json

# Instagram account insights (reach, views, interactions)
curl -s "https://zernio.com/api/v1/analytics/instagram-account-insights?accountId=<IG_ID>&period=last_30_days" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/ig-insights.json

# YouTube daily views and watch time
curl -s "https://zernio.com/api/v1/analytics/youtube-daily-views?accountId=<YT_ID>&startDate=$START&endDate=$END" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/yt-views.json

# YouTube demographics
curl -s "https://zernio.com/api/v1/analytics/youtube-demographics?accountId=<YT_ID>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > $WD/yt-demographics.json
```

Note: some endpoints may require paid Zernio plans. If response is HTML instead of JSON, skip that endpoint.

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

Send via `send_message`:

```
*📊 АНАЛИТИКА СОЦИАЛЬНЫХ СЕТЕЙ*
*Период: последние 30 дней*

*Общие метрики:*
• Постов: <N>
• Просмотров: <N>
• Лайков: <N>
• Комментариев: <N>
• Средний engagement: <N>

*По платформам:*
| Платформа | Постов | Просмотров | Лайков | Top пост |
|-----------|--------|------------|--------|----------|
| YouTube | <N> | <N> | <N> | <title> |
| Instagram | <N> | <N> | <N> | <title> |
| ... | | | | |

*Лучшее время для публикации:*
<from best-time.json>

*Рост подписчиков:*
<from follower-stats>

*Демография (если доступно):*
<from ig-demographics / yt-demographics>

*Рекомендации:*
• <based on data — what to post more, when, on which platform>
```

### Phase 5: Save to Wiki

Create/update `wiki/entities/social-media-analytics.md`:
```yaml
---
title: "Social Media Analytics — <owner name>"
type: entity
subtype: social-analytics
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: ["[[people/shakhruz-ashot]]"]
tags: [analytics, social-media, zernio]
confidence: high
---
```

Sections: Connected Platforms, Overall Metrics, Per-Platform Breakdown, Top Performing Content, Best Time to Post, Audience Demographics, Follower Growth, Recommendations.

Update wiki index + log + git commit.

### Phase 6: Merge with Client Data

If analyzing for a specific client (not yourself):
- Merge Zernio data into `client-profiles/<name>/profile.json`
- Add cross-platform engagement metrics to client-prep briefing
- Compare with Apify data (Zernio may have newer metrics)

## For Client Analysis

When analyzing a client's socials (not your own accounts):
1. Client must connect their accounts to Zernio first
2. Or: use Zernio only for YOUR accounts, use Apify for client's public data
3. Best: use both — Apify for content scraping, Zernio for analytics/demographics

## Error Handling

- **HTML response instead of JSON:** Endpoint requires higher Zernio plan. Skip, note as unavailable.
- **Empty analytics:** Account recently connected, data not synced yet. Wait or use Apify data.
- **Account not found:** Verify account ID from Phase 1.

## Cost

Zero external API cost — Zernio analytics included in subscription.
