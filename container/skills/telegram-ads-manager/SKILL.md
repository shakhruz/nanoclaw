---
name: telegram-ads-manager
description: Create and manage Telegram Ad campaigns via ads.telegram.org using agent-browser. Handles login, campaign creation, budget setup, creative upload, moderation tracking, and performance reporting. Use after telegram-ads-research and telegram-ads have produced a media plan and creatives.
---

# Telegram Ads Campaign Manager

Create and manage ad campaigns in the Telegram Ads cabinet (ads.telegram.org) via agent-browser. This is the execution layer — research and creatives should be ready before using this skill.

## Trigger

"запусти рекламу", "создай кампанию в телеграм", "telegram ads manager", "проверь рекламу", "статистика рекламы"

## Prerequisites

- `agent-browser` for web automation
- Media plan from `telegram-ads-research` skill
- Creatives from `telegram-ads` skill
- TON wallet funded (minimum 20 TON)

## Platform Reference

- **URL:** https://ads.telegram.org
- **Auth:** Telegram account login (phone + code)
- **Payment:** TON cryptocurrency
- **Min budget:** 20 TON (≈ $105)
- **Min CPM:** 0.1 TON
- **Moderation:** 24-48 hours
- **No API** — all actions through web UI

## Phase 1: Login & Session

### First time setup

```bash
agent-browser open "https://ads.telegram.org"
agent-browser snapshot -i
# Look for login button, click it
# Enter phone number → Telegram sends code → enter code
# Save session for reuse
agent-browser save-state /workspace/group/telegram-ads-auth.json
```

### Subsequent logins

```bash
agent-browser load-state /workspace/group/telegram-ads-auth.json
agent-browser open "https://ads.telegram.org"
agent-browser snapshot -i
# Verify we're logged in (dashboard visible)
# If session expired → re-login
```

### Check balance

After login, navigate to wallet/balance section:
```bash
agent-browser snapshot -i
# Find balance display → extract TON amount
# If balance < 5 TON → warn user: "Баланс X TON, рекомендуется пополнить"
```

## Phase 2: Create Campaign

Load the media plan: `wiki/entities/<client>-telegram-ads-mediaplan.md`

For each campaign (usually 1 per targeting type):

### Step 1: New campaign

```bash
# Navigate to campaign creation
agent-browser click "Create Campaign"  # or equivalent button
agent-browser snapshot -i
```

### Step 2: Set targeting

Based on media plan targeting type:

**Channel targeting:**
```bash
# Find channel targeting input
agent-browser fill "#channel-input" "@channel_username"
# Add each channel from the media plan
# Verify channels are accepted (1000+ subscribers)
```

**Bot targeting:**
```bash
# Find bot targeting input  
agent-browser fill "#bot-input" "@bot_username"
# Add each bot from the media plan
```

**Search phrase targeting:**
```bash
# Find keyword/search input
agent-browser fill "#keyword-input" "ключевая фраза"
# Add each phrase from the media plan
```

**Geo/language filters:**
```bash
# Set country: Uzbekistan (or as specified in media plan)
# Set language: Russian / Uzbek
```

### Step 3: Create ad

```bash
# Enter ad text (≤ 160 chars)
agent-browser fill "#ad-text" "<ad copy from media plan>"

# Enter CTA button text (≤ 30 chars)  
agent-browser fill "#cta-text" "<CTA text>"

# Set destination link
agent-browser fill "#destination" "https://t.me/<bot_or_channel>"

# Upload media if supported
agent-browser upload "#media-upload" "/workspace/group/telegram-ads/<client>/banner.jpg"
```

### Step 4: Set budget

```bash
# Daily budget or total budget
agent-browser fill "#budget" "<amount in TON>"

# CPM bid (start with minimum 0.1 TON, increase if needed)
agent-browser fill "#cpm-bid" "0.1"
```

### Step 5: Review & submit

```bash
agent-browser snapshot  # Full page screenshot for records
# Review all settings match the media plan
# Click submit/create
agent-browser click "Submit"
```

Save screenshot to `/workspace/group/telegram-ads/<client>/campaign-<date>-screenshot.png`

## Phase 3: Moderation Tracking

After submission, campaigns go through Telegram's moderation (24-48h).

### Manual check

```bash
agent-browser load-state /workspace/group/telegram-ads-auth.json
agent-browser open "https://ads.telegram.org"
agent-browser snapshot -i
# Navigate to campaigns list
# Check status: Pending / Approved / Rejected
```

### Report status

```
Статус кампаний Telegram Ads:
• Кампания "<name>": ✅ Одобрена / ⏳ На модерации / ❌ Отклонена
  Причина отклонения: <если есть>
```

If rejected:
1. Read rejection reason
2. Fix the issue (edit text, change image, adjust targeting)
3. Resubmit
4. Report to user what was changed

## Phase 4: Performance Reporting

After campaign runs for 48-72 hours:

```bash
agent-browser load-state /workspace/group/telegram-ads-auth.json
agent-browser open "https://ads.telegram.org"
# Navigate to campaign analytics
agent-browser snapshot  # Screenshot analytics page
```

Extract and report:

```
Отчёт по Telegram Ads: <Product>
Период: <dates>
━━━━━━━━━━━━━━━━━━━

Общие показатели:
• Показы: <N>
• Клики: <N>
• CTR: <X>%
• Расход: <X> TON (≈ $Y)
• CPC: <X> TON

По площадкам:
| Площадка | Показы | Клики | CTR | Расход |
|----------|--------|-------|-----|--------|
| @channel1 | 5000 | 75 | 1.5% | 2.5 TON |
| @channel2 | 3000 | 15 | 0.5% | 1.5 TON |

Рекомендации:
• Масштабировать: @channel1 (CTR 1.5% — выше среднего)
• Отключить: @channel2 (CTR 0.5% — ниже порога)
• Добавить: <новые площадки по аналогии с лидером>
```

Save to: `wiki/entities/<client>-telegram-ads-report-<date>.md`

## Phase 5: Optimization

Based on performance data:

### Scale winners
- Increase budget on placements with CTR > 1%
- Add similar channels (same niche, same audience profile)
- Test new creatives on winning placements

### Kill losers
- Pause placements with CTR < 0.3% after 1000+ impressions
- Don't immediately kill — wait for statistical significance

### Iterate creatives
- For winning placements: create 2-3 new text variants
- A/B test: different hooks, different CTAs, different pain points
- For media ads: test image vs video on same placement

### Expand targeting
- Run `telegram-ads-research` again with learnings
- Look for channels similar to top performers
- Add new search phrases based on converting ones

## Scheduled Monitoring

Set up recurring task for campaign monitoring:

```
prompt: "Check Telegram Ads performance. Login to ads.telegram.org via agent-browser,
check all active campaigns. If any campaign spent > 5 TON since last check,
report results. If any campaign has CTR < 0.3% after 2000+ impressions,
recommend pausing. If balance < 10 TON, warn about low balance."
schedule_type: cron
schedule_value: "0 10,18 * * *"  # twice daily, 10am and 6pm
context_mode: group
```

## Troubleshooting

- **Login fails**: Telegram may require fresh code. Ask user to check Telegram for login code.
- **Session expired**: Delete `telegram-ads-auth.json`, re-login from scratch.
- **Campaign rejected**: Read reason carefully. Common: text too long, misleading claims, wrong language.
- **Low impressions**: Increase CPM bid (try 0.2-0.5 TON), broaden targeting.
- **High spend low clicks**: Pause, review creative relevance to placement audience.
