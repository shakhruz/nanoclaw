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

Use `--profile <path>` with a path on the mounted group volume. This creates a persistent browser profile directory that survives container restarts (cookies, localStorage, IndexedDB, service workers all preserved).

```bash
# Ensure profile directory exists (once)
mkdir -p /workspace/group/browser-profiles/telegram-ads

# Open with persistent profile
agent-browser --session-name telegram-ads open "https://ads.telegram.org"
agent-browser --session-name telegram-ads snapshot -i

# First time: click login, enter phone, user sends code via Telegram, enter code
# Subsequent runs: already logged in, profile has the session
```

**Why `--profile` and NOT `--session-name` or `state save`:**
- `--session-name` saves inside the container — lost on every restart
- `state save/load` works but is a JSON file — doesn't capture everything (IndexedDB, service workers)
- `--profile` is a full browser profile directory on the mounted volume — most reliable persistence

### Subsequent logins

Just use the same `--profile` flag — session restored automatically:

```bash
agent-browser --session-name telegram-ads open "https://ads.telegram.org"
agent-browser --session-name telegram-ads snapshot -i
# Dashboard should appear immediately
```

If the page shows login (session expired on Telegram's side, usually after weeks), re-auth by following the first-time flow — the profile will be updated with fresh cookies.

### Force re-login

```bash
rm -rf /workspace/group/browser-profiles/telegram-ads
mkdir -p /workspace/group/browser-profiles/telegram-ads
# Then run the login flow fresh
```

### Check balance

After login, navigate to wallet/balance section:
```bash
agent-browser snapshot -i
# Find balance display → extract TON amount
# If balance < 5 TON → warn user: "Баланс X TON, рекомендуется пополнить"
```

## Cabinet Layout (as of April 2026)

The ads.telegram.org interface has:
- **Top bar**: "Telegram Ads" logo, Budget display (TON), Account selector dropdown, Avatar
- **Dashboard**: Table of ads — columns: AD TITLE, VIEWS, CLICKS, ACTIONS, CTR, CVR, CPM, CPC, BUDGET, TARGET, STATUS, DATE ADDED
- **Buttons**: "Manage budget", "Create a new ad"
- **Ad detail**: Tabs — Info, Budget, Statistics
- **Create ad page**: Fields on left, Preview on right, Targeting tabs (Search / Bots / Channels) on right

**Multiple accounts**: User may have several ad accounts (dropdown in top-right). Select the correct one before creating ads.

**Geo restrictions**: Ads will NOT be shown in Russia, Ukraine, Israel, Palestine.

## Phase 2: Create Ad

Load the media plan: `wiki/entities/<client>-telegram-ads-mediaplan.md`

Each ad = one targeting set. Create separate ads for channels, bots, and search phrases.

### Step 1: Navigate to create

```bash
agent-browser click "Create a new ad"
agent-browser snapshot -i
```

### Step 2: Fill ad details (left panel)

```bash
# Ad title (internal name, not shown to users)
agent-browser fill "Ad title" "<client> — <targeting_type> — <date>"

# Ad text (shown to users, ≤ 160 chars)
agent-browser fill "Ad text" "<ad copy from media plan>"

# URL to promote (bot, channel, or post link)
agent-browser fill "URL you want to promote" "https://t.me/<bot_or_channel>"

# Upload photo or video (optional but recommended)
# Click "Upload Photo or Video" button
agent-browser click "Upload Photo or Video"
agent-browser upload "<file-input>" "/workspace/group/telegram-ads/<client>/banner.jpg"

# CPM in Ton (minimum 0.1, start with 1.00 for reasonable reach)
agent-browser fill "CPM in Ton" "1.00"

# Initial budget in Ton
agent-browser fill "Initial budget in Ton" "5.00"

# Daily views limit per user: select 1 (conservative) or 2
agent-browser click "1"  # buttons: 1, 2, 3, 4

# Initial status: On Hold (review first) or Active
agent-browser click "On Hold"
```

### Step 3: Set targeting (right panel tabs)

Click the appropriate tab: **Search**, **Bots**, or **Channels**

**Channel targeting (tab: Channels):**
```bash
agent-browser click "Channels"
# Input field: "Target specific channels"
agent-browser fill "Target specific channels" "@channel_username"
# Press Enter to add, repeat for each channel
# Verify: green checkmarks appear for accepted channels
# Red = channel has < 1000 subscribers or is private
```

**Bot targeting (tab: Bots):**
```bash
agent-browser click "Bots"
# Similar input field for bot usernames
agent-browser fill "Target specific bots" "@bot_username"
```

**Search phrase targeting (tab: Search):**
```bash
agent-browser click "Search"
# Input field: "Target search queries"
agent-browser fill "Target search queries" "ключевая фраза"
# Add multiple phrases, one at a time
```

### Step 4: Review preview

The right panel shows a live preview of how the ad will look. Take a screenshot:
```bash
agent-browser snapshot
# Save to /workspace/group/telegram-ads/<client>/preview-<targeting>-<date>.png
```

### Step 5: Pre-submission compliance check (MANDATORY)

**Before clicking Submit — run the compliance checklist from `telegram-ads` skill.**

Critical pre-flight checks:

```bash
# 1. Ad text checks
AD_TEXT="<the text user is about to submit>"
echo "$AD_TEXT" | python3 -c '
import sys, re
text = sys.stdin.read().strip()
issues = []
if len(text) > 160: issues.append(f"Too long: {len(text)}/160 chars")
# Personal questions (5.4 violation — this killed our 2026-04-18 ad)
if re.search(r"(Как|Хочешь|Любишь|Нужн[оа])\s+(ты|вы|вам|тебе|вас)?.*\?", text, re.IGNORECASE):
    issues.append("Personal question detected (5.4 violation)")
# Profession/status targeting
for pattern in [r"для\s+предпринимател", r"для\s+мам", r"для\s+начинающ", r"для\s+всех\s+кто", r"если\s+ты", r"тво[йиея]"]:
    if re.search(pattern, text, re.IGNORECASE):
        issues.append(f"Personal targeting detected: /{pattern}/")
# Get-rich-quick
for word in ["заработай", "заработок", "$5000", "$10000", "пассивный доход", "легкие деньги"]:
    if word.lower() in text.lower():
        issues.append(f"Income claim: {word}")
# Absolute claims
for word in ["лучший", "лучшая", "самый", "самая", "№1", "гарантируем", "гарантия"]:
    if word.lower() in text.lower():
        issues.append(f"Absolute claim: {word}")
# Scare / urgency
for word in ["не пропусти", "последний шанс", "срочно!", "только сегодня"]:
    if word.lower() in text.lower():
        issues.append(f"Scare tactic: {word}")
# Caps abuse (>2 caps-only words)
caps_words = [w for w in text.split() if len(w) > 2 and w.isupper() and w.upper() != w.lower()]
if len(caps_words) > 2:
    issues.append(f"Too many all-caps words: {caps_words}")
# Excessive punctuation
if re.search(r"[!?]{2,}", text):
    issues.append("Excessive punctuation (!!! / ???)")
# Emoji count
emoji_count = len(re.findall(r"[\U0001F300-\U0001FAFF\U0001F000-\U0001F02F]", text))
if emoji_count > 2:
    issues.append(f"Too many emoji: {emoji_count}")

if issues:
    print("❌ COMPLIANCE ISSUES:")
    for i in issues: print(f"  - {i}")
    print("\\nFix before submitting. See telegram-ads skill Phase 5 for rewrites.")
    sys.exit(1)
else:
    print("✅ Ad text passes automated checks")
'

# 2. Destination check (bot)
BOT_URL="$URL_TO_PROMOTE"  # e.g., t.me/ashotaiuz_bot
if [[ "$BOT_URL" =~ t\.me/.*_bot$ ]]; then
  BOT_NAME=$(echo "$BOT_URL" | sed 's|.*/||')
  echo "⚠️ Bot destination: verify manually:"
  echo "  [ ] Profile image set (not default)"
  echo "  [ ] /about has ≥2 sentences"
  echo "  [ ] /start shows menu (not just a redirect URL)"
  echo "  [ ] ≥3 meaningful commands/buttons"
  echo "  Test: t.me/$BOT_NAME — open in Telegram, verify."
fi
```

If ANY issues — pause and fix before submitting. Telegram moderation is 24-48h per rejection, each round of changes delays launch.

### Step 6: Submit

```bash
# Scroll to bottom if needed
agent-browser click "Create"  # or "Submit" button
agent-browser snapshot  # Record confirmation
```

Ad goes to "In Review" status (24-48 hours).

Save screenshot to `/workspace/group/telegram-ads/<client>/campaign-<date>-screenshot.png`

## Phase 3: Moderation Tracking

After submission, campaigns go through Telegram's moderation (24-48h).

### Manual check

```bash
agent-browser --session-name telegram-ads open "https://ads.telegram.org"
agent-browser --session-name telegram-ads snapshot -i
# Navigate to campaigns list
# Check status: Pending / Approved / Rejected
```

If snapshot shows login form instead of dashboard → invoke `telegram-ads-auth` skill.

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
agent-browser --session-name telegram-ads open "https://ads.telegram.org"
# Navigate to campaign analytics
agent-browser --session-name telegram-ads snapshot  # Screenshot analytics page
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
- **Session expired**: Run `telegram-ads-auth` skill. If profile itself is corrupted, `rm -rf /workspace/group/browser-profiles/telegram-ads && mkdir -p /workspace/group/browser-profiles/telegram-ads`, then re-auth.
- **Campaign rejected**: Read reason carefully. Common: text too long, misleading claims, wrong language.
- **Low impressions**: Increase CPM bid (try 0.2-0.5 TON), broaden targeting.
- **High spend low clicks**: Pause, review creative relevance to placement audience.
- **Mila repeatedly says "session expired"**: Check `/workspace/group/store/telegram-ads-session.json`. If `consecutive_failures > 3` but profile dir has recent mtime, something else is broken (likely chromium version drift or host path not mounted). Ping Shakhruz.
