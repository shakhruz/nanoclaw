---
name: zernio-publisher
description: Publish and schedule content across all social media platforms via Zernio API. Create posts for YouTube, Instagram, Facebook, LinkedIn, Twitter/X, Telegram simultaneously. Use when asked to publish, schedule, or plan social media content.
---

# Zernio Social Media Publisher

Publish content across all connected platforms in one command via Zernio API. Schedule posts, manage queue, bulk upload from CSV.

## Prerequisites

- `$ZERNIO_API_KEY` — env var

## API Base

```
Base URL: https://zernio.com/api/v1
Auth: -H "Authorization: Bearer $ZERNIO_API_KEY"
```

## Trigger

- "опубликуй пост", "publish post", "запланируй пост"
- "контент-план", "расписание публикаций"
- "пост на все платформы"

## Workflow

### Phase 1: Get Accounts & Profile

```bash
curl -s "https://zernio.com/api/v1/accounts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > /tmp/zernio-accounts.json

curl -s "https://zernio.com/api/v1/profiles" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > /tmp/zernio-profiles.json
```

Extract profile ID and account IDs per platform for posting.

### Phase 2: Create & Publish Post

**Immediate publish:**
```bash
curl -s -X POST "https://zernio.com/api/v1/posts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "profileId": "<PROFILE_ID>",
    "text": "<POST_TEXT>",
    "platforms": ["youtube", "instagram", "facebook", "linkedin", "twitter"],
    "publishNow": true
  }'
```

**Scheduled publish:**
```bash
curl -s -X POST "https://zernio.com/api/v1/posts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "profileId": "<PROFILE_ID>",
    "text": "<POST_TEXT>",
    "platforms": ["youtube", "instagram"],
    "scheduledFor": "2026-04-15T09:00:00.000Z"
  }'
```

**With media (image/video):**
```bash
# Step 1: Get presigned upload URL
UPLOAD=$(curl -s "https://zernio.com/api/v1/media/upload?size=<BYTES>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY")
# Extract uploadUrl and fileUrl from response

# Step 2: Upload file to presigned URL
curl -s -X PUT "<uploadUrl>" \
  -H "Content-Type: <mime-type>" \
  --data-binary @<FILE>

# Step 3: Create post with media
curl -s -X POST "https://zernio.com/api/v1/posts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "profileId": "<PROFILE_ID>",
    "text": "<POST_TEXT>",
    "platforms": ["instagram", "facebook"],
    "mediaUrls": ["<fileUrl>"],
    "publishNow": true
  }'
```

### Phase 3: Platform-Specific Adaptations

When publishing to multiple platforms, adapt content:

| Platform | Max Length | Media | Notes |
|----------|-----------|-------|-------|
| Instagram | 2200 chars | Required (image/video) | Hashtags at end |
| YouTube | 5000 description | Video required | Title separate |
| Twitter/X | 280 chars | Optional | Short + link |
| LinkedIn | 3000 chars | Optional | Professional tone |
| Facebook | 63,206 chars | Optional | Can be longer |
| Telegram | 4096 chars | Optional | Markdown formatting |

**IMPORTANT:** Always confirm with user before publishing. Show draft:
```
*Готов к публикации:*

📝 *Текст:* <text>
📷 *Медиа:* <description>
📱 *Платформы:* YouTube, Instagram, LinkedIn
⏰ *Время:* сейчас / <scheduled time>

Публикуем?
```
Use inline buttons: ✅ Публикуем / ❌ Отмена / ✏️ Редактировать

### Phase 4: Bulk Content from CSV

```bash
# Upload CSV with columns: text, platforms, scheduledFor, mediaUrl
curl -s -X POST "https://zernio.com/api/v1/posts/bulk-upload" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@content-plan.csv" \
  -F "profileId=<PROFILE_ID>"
```

### Phase 5: Queue Management (Auto-Scheduling)

Set up posting queue — Zernio automatically schedules next posts:

```bash
# Create queue (e.g. post at 9:00 and 18:00 daily)
curl -s -X POST "https://zernio.com/api/v1/queue?profileId=<PROFILE_ID>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Daily content",
    "slots": [
      {"day": "monday", "times": ["09:00", "18:00"]},
      {"day": "tuesday", "times": ["09:00", "18:00"]},
      {"day": "wednesday", "times": ["09:00", "18:00"]},
      {"day": "thursday", "times": ["09:00", "18:00"]},
      {"day": "friday", "times": ["09:00", "18:00"]}
    ],
    "timezone": "Asia/Tashkent"
  }'

# Preview upcoming slots
curl -s "https://zernio.com/api/v1/queue/preview?profileId=<PROFILE_ID>&count=10" \
  -H "Authorization: Bearer $ZERNIO_API_KEY"
```

### Phase 6: Content Adaptation Helper

When user provides one piece of content, adapt it for each platform:

1. **Original** (long form) → LinkedIn, Facebook
2. **Short** (280 chars) → Twitter/X  
3. **Visual** (with image + hashtags) → Instagram
4. **Video description** → YouTube
5. **Compact** (with emoji) → Telegram

Example:
```
User: "Опубликуй про наш новый мастер-класс по воронкам"

→ LinkedIn: "🚀 Запускаем новый мастер-класс: «Как создать автоворонку с ИИ за 30 минут»..."
→ Instagram: "🔥 Мастер-класс по автоворонкам! ИИ создает воронку за 30 мин...\n\n#автоворонка #ии #бизнес..."
→ Twitter: "🚀 Новый мастер-класс: автоворонка с ИИ за 30 мин. Регистрация: ashotai.uz"
→ Telegram: "🚀 *Мастер-класс*: Автоворонка с ИИ за 30 мин..."
```

## Safety Rules

- **NEVER publish without explicit user confirmation** — always show draft first
- **NEVER delete published posts** without confirmation
- **Show preview** of how post will look on each platform
- For scheduled posts — show summary: "Запланировано N постов на эту неделю"

## Error Handling

- **Post failed on one platform:** report which platform failed, offer retry
- **Media upload failed:** check file size (max 5GB), format compatibility
- **Rate limit:** wait and retry

## Cost

Zero additional cost — included in Zernio subscription.
