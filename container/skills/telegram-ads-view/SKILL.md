---
name: telegram-ads-view
description: Read-only view of Telegram Ads — balance, active campaigns, metrics. Available to main + all MILA groups (channel-promoter, partner-recruitment, client-profiler, youtube-manager). Reads from shared cache; refreshes only if cache is stale. Use when asked about ad campaign status, balance, performance numbers.
---

# Telegram Ads View — read-only status

Show current Telegram Ads state — balance, active/review/declined campaigns, per-campaign metrics. **Read-only** — does NOT create/edit/pause campaigns (that's `telegram-ads-manager`).

## Trigger

- "статус рекламы", "telegram ads", "сколько кампаний", "баланс рекламы"
- "покажи что с рекламой", "как идёт реклама"
- Internal: utility called by `morning-brief`, `telegram-ads-analyze`, `telegram-ads-optimize`

## How it works

Two layers, both shared across MILA groups via `/workspace/global/telegram-ads/`:

1. **Cache** (`cache.json`) — last known dashboard state. Refreshed on demand if stale.
2. **Session** (`session.json`) — health of the cookie. Source of truth: `telegram-ads-session/check-session.sh`.

```
┌─ check-session.sh (cookie-only, ~50ms) ─┐
│                                          │
│  alive   → if cache fresh (<4h):  use it │
│           else: refresh via browser      │
│                                          │
│  expired → don't refresh; show cached    │
│            with "stale, session needs    │
│            re-auth" warning              │
│                                          │
│  unknown → "not authenticated yet"       │
└──────────────────────────────────────────┘
```

## Algorithm

```bash
HELP=/home/node/.claude/skills/telegram-ads-session
. $HELP/common.sh

# 1. Session health (no browser, ~50ms)
SESSION=$($HELP/check-session.sh)
SESSION_EXIT=$?

# 2. Cache freshness
if [ -f "$TG_ADS_CACHE_FILE" ]; then
  UPDATED_AT=$(node -e "try{console.log(require('$TG_ADS_CACHE_FILE').updated_at||'');}catch{console.log('');}" 2>/dev/null)
else
  UPDATED_AT=""
fi

# 3. Decide: use cache or refresh
NEED_REFRESH=true
if [ -n "$UPDATED_AT" ] && ! tg_ads_is_stale "$UPDATED_AT" 240; then
  NEED_REFRESH=false  # cache fresh (<4h)
fi

if [ "$SESSION_EXIT" != "0" ]; then
  NEED_REFRESH=false  # don't open browser if session not confirmed alive
fi

# 4. Refresh if needed
if [ "$NEED_REFRESH" = "true" ]; then
  $HELP/with-lock.sh agent-browser --session-name telegram-ads open "https://ads.telegram.org" >/dev/null 2>&1
  sleep 2
  $HELP/with-lock.sh agent-browser --session-name telegram-ads snapshot -i
  # Parse snapshot → extract balance + campaigns → write cache.json
  # Use Node one-liner OR Python — see Step 4 in old telegram-ads-status SKILL for parsing pattern
fi

# 5. Render
node -e "
  const fs = require('fs');
  const cache = JSON.parse(fs.readFileSync('$TG_ADS_CACHE_FILE'));
  const sess = JSON.parse(fs.readFileSync('$TG_ADS_SESSION_FILE'));
  // ... format markdown for chat
"
```

## Output format (Telegram markdown — single asterisks)

```
📢 *Telegram Ads*
Баланс: *X.XX TON* (~$X.XX)

Кампании:
• *Название* [active] — X.XX/Y.YY TON | Z.ZK показов | CTR X.XX%
• *Название* [review] — ждёт модерации
• *Название* [declined] — отклонена: причина
• (нет активных кампаний)

Потрачено всего: *X.XX TON*
Обновлено: ЧЧ:ММ по Ташкенту _(N часов назад)_
Сессия: ✅ alive (ещё N дней)
```

If cache is stale and refresh failed:
```
📢 *Telegram Ads*
_(данные устарели, обновление не удалось — сессия в порядке, но снапшот не получился)_
```

If session is expired/unknown:
```
📢 *Telegram Ads*
_(статус: <session_status> — для свежих данных нужна re-auth через telegram-ads-auth)_
Последний известный баланс: X.XX TON (на ЧЧ:ММ N дней назад)
```

## When NOT to use

- **Asked to create/pause/edit campaigns** → use `telegram-ads-manager` (write-capable, with lock)
- **Asked for trends or analysis** → use `telegram-ads-analyze` (consumes history)
- **Asked for recommendations** → use `telegram-ads-optimize`
- **Asked about creatives** → use `telegram-ads-generator`

## Available to

main + 4 MILA worker groups (channel-promoter, partner-recruitment, client-profiler, youtube-manager).
NOT available to public lead groups (filtered by `PUBLIC_LEAD_SKILLS` allowlist) or to `ashotai-experts` (filtered by `TELEGRAM_ADS_BLOCKED_FOLDERS`).

## History

| Дата | Что изменилось |
|------|---------------|
| 2026-04-22 | Создан как container-skill, заменяет per-group `telegram-ads-status` для MILA. Использует helpers из `telegram-ads-session`. Read-only — пишет только в cache, не дёргает Telegram cabinet. |
