---
name: meta-ads
description: Manage and analyze Facebook + Instagram ads on Meta Marketing API. Lists, pauses, resumes, copies (boosts) campaigns and ads on the primary ad account. Reads access token from /workspace/group/config.json:meta_ads. Use when asked to check ads performance, boost an Instagram post, pause a campaign, see CTR/CPC/spend, or get a daily report.
---

# Meta Ads — Marketing API skill

Direct Graph API access (no Composio/MCP wrapper). Reads token + primary ad account from `/workspace/group/config.json:meta_ads`.

Token currently scopes: `ads_management`, `ads_read`, `read_insights`, `business_management`. NOT scoped: `instagram_basic`, `pages_show_list` — so we can't enumerate IG posts or page lists; we work with what's already in the ad account (existing campaigns/ads/creatives).

## Trigger

«статус рекламы», «meta ads», «фб реклама», «забусти этот пост», «паузни кампанию», «отчёт по рекламе», «CTR», «CPC», «сколько потратили на рекламу»

## Layout

| File | Purpose |
|---|---|
| `lib.sh` | Sourced by all scripts. Reads token, exports `meta_get`, `meta_post`, `meta_check_error`, `meta_token_warning`. |
| `status.sh` | Account balance, active campaigns, last 7d/30d account-level performance. |
| `list.sh [date_preset]` | All ads with their insights for the period, sorted by spend. |
| `insights.sh <id\|"account"> [preset] [breakdown]` | Detailed insights for one entity. |
| `pause.sh <campaign_id>` | Pause campaign. |
| `resume.sh <campaign_id>` | Resume (set ACTIVE). |
| `update-budget.sh <adset_id> <usd> [daily\|lifetime]` | Change ad set budget. |
| `boost.sh <source_ad_id> <usd> <days> [suffix]` | Deep-copy an existing ad as a new boost (PAUSED). |

All scripts read defaults from `/workspace/group/config.json` and exit non-zero on API error.

## Common workflows

### "Какой статус рекламы?"

```bash
bash /home/node/.claude/skills/meta-ads/status.sh
```

Shows balance, currency, active campaigns with their budget/dates, last 7d and 30d account performance (spend, impressions, CTR, CPC, conversions).

### "Покажи топ объявлений за неделю"

```bash
bash /home/node/.claude/skills/meta-ads/list.sh last_7d
```

### "Дай разбивку по полу/возрасту/гео для кампании X"

```bash
bash /home/node/.claude/skills/meta-ads/insights.sh <campaign_id> last_30d age
bash /home/node/.claude/skills/meta-ads/insights.sh <campaign_id> last_30d country
bash /home/node/.claude/skills/meta-ads/insights.sh <campaign_id> last_30d placement
```

Valid breakdowns: `age`, `gender`, `country`, `region`, `placement`, `device_platform`, `publisher_platform`, `impression_device`.

### "Забусти этот пост на $10 на 3 дня"

Without `instagram_basic` we can't pick an arbitrary IG post by URL; we work via duplication of an existing ad targeting that post.

1. Find an existing ad that promotes the same IG post:
   ```bash
   bash /home/node/.claude/skills/meta-ads/list.sh last_30d | grep -B1 "instagram.com/p/<SHORTCODE>"
   ```
2. Duplicate it with new budget:
   ```bash
   bash /home/node/.claude/skills/meta-ads/boost.sh <source_ad_id> 10.00 3 " — boost 25.04"
   ```
3. Review (it's PAUSED), then launch:
   ```bash
   bash /home/node/.claude/skills/meta-ads/resume.sh <new_campaign_id>
   ```

If no existing ad targets that IG post — say so. Manual setup via Ads Manager UI is required first to create the initial creative.

### "Паузни/возобнови кампанию"

```bash
bash /home/node/.claude/skills/meta-ads/pause.sh <campaign_id>
bash /home/node/.claude/skills/meta-ads/resume.sh <campaign_id>
```

### "Подними бюджет на $X"

```bash
bash /home/node/.claude/skills/meta-ads/update-budget.sh <adset_id> 5.00 daily
# or
bash /home/node/.claude/skills/meta-ads/update-budget.sh <adset_id> 50.00 lifetime
```

`adset_id` ≠ campaign_id. Get it: `meta_get "$CAMP_ID/adsets" --data-urlencode 'fields=id,name,daily_budget,lifetime_budget'` (or via `insights.sh` → копай из ad info).

## Recommended pre-boost check (Zernio synergy)

Before bursting budget on a post, validate organic engagement first via `zernio-analytics` skill — if the post hasn't earned organic traction (likes/saves/comments), boosting won't help. Workflow:

1. `zernio-analytics` → pull engagement for the IG post
2. If engagement_rate > 3% AND saves > 10 → safe to boost
3. Otherwise → suggest organic improvements first

## Daily report (scheduled task)

Set up:

```
prompt: |
  Run bash /home/node/.claude/skills/meta-ads/status.sh and bash /home/node/.claude/skills/meta-ads/list.sh last_7d.
  Format as a concise Telegram report:
  • Spend yesterday vs avg-7d
  • Top 3 ads by spend with CTR/CPC
  • Bottom ad (CTR < 1%) — recommend pause
  • Token expiry warning if < 7 days
schedule_type: cron
schedule_value: "0 9 * * *"   # 09:00 daily, owner timezone
context_mode: group
```

## Token renewal

Long-lived token expires every 60 days. To renew:

1. Open https://developers.facebook.com/tools/explorer
2. Select MILA GPT app (id `1186008359846081`)
3. Get user access token with scopes: `ads_management,ads_read,read_insights,business_management`
4. Exchange for long-lived: `GET /oauth/access_token?grant_type=fb_exchange_token&client_id=<APP_ID>&client_secret=<APP_SECRET>&fb_exchange_token=<SHORT_TOKEN>`
5. Update `meta_ads.access_token` and `meta_ads.token_expires_at` in `/workspace/group/config.json`

`status.sh` warns 7 days before expiry.

## Safety

- Token has full ads_management scope — destructive ops possible. Scripts default to PAUSED on creation; never auto-activate.
- `boost.sh` always creates as PAUSED — explicit `resume.sh` required to launch.
- Budget changes (`update-budget.sh`) take effect immediately. Confirm USD amount before running.
- Ad account `act_20259433` is real money. Each boost is real spend. Don't loop.
- Treat any change as visible to the audience — Meta has no "preview only" mode for active ads.

## Limitations (need scope upgrade)

To unlock these you'd need an App Review with extended permissions OR a Business System User:

- ❌ List Pages / IG accounts owned by the user (`pages_show_list`, `instagram_basic`)
- ❌ Pull organic IG metrics (followers, posts, comments) — use Zernio instead via `zernio-analytics`
- ❌ Publish IG posts via API — use Zernio (`zernio-publisher`) instead
- ❌ Read DM/comments under IG posts — use Zernio (`zernio-inbox`)

These blanks are filled by Zernio in our stack, so the gap is closed at the workflow level even though the scope is missing.
