---
name: youtube-upload
description: Upload videos to YouTube via Zernio API. Generates SEO-optimized title, description, tags from conversation context. Handles presigned upload, thumbnail, scheduling. Use when asked to upload/publish a video to YouTube.
---

# YouTube Video Uploader (via Zernio)

Upload videos to YouTube with auto-generated metadata. Uses Zernio API for the upload — zero extra credentials needed.

## Prerequisites

- `$ZERNIO_API_KEY` — env var (injected by container-runner)

## Trigger

- "загрузи видео на ютуб", "опубликуй на youtube"
- "upload to youtube", "publish video"
- "выложи запись эфира", "залей видео"

## Zernio API Reference

```
Base: https://zernio.com/api/v1
Auth: -H "Authorization: Bearer $ZERNIO_API_KEY"
```

### Critical field names (verified against OpenAPI spec):

| What | Field | NOT |
|------|-------|----|
| Post body/description | `content` | ~~text~~ |
| Media attachments | `mediaItems` (array of objects) | ~~mediaUrls~~ |
| Target platforms | `platforms` (array of `{platform, accountId}`) | ~~["youtube"]~~ |
| YouTube title | `platformSpecificData.title` inside platform object | |
| YouTube visibility | `platformSpecificData.visibility` | ~~top-level visibility~~ |
| YouTube madeForKids | `platformSpecificData.madeForKids` | |

## Workflow

### Phase 0: Verify YouTube Account

```bash
curl -s "https://zernio.com/api/v1/accounts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > /tmp/zernio-accounts.json

node -e "
const d = JSON.parse(require('fs').readFileSync('/tmp/zernio-accounts.json','utf8'));
const yt = (d.accounts||d||[]).filter(a => a.platform === 'youtube');
if (!yt.length) { console.error('NO YOUTUBE ACCOUNT CONNECTED'); process.exit(1); }
yt.forEach(a => console.log('YouTube:', a.displayName || a.platformUsername, '| accountId:', a._id));
"
```

If no YouTube account — tell the user: "YouTube аккаунт не подключен к Zernio. Подключи на zernio.com -> Accounts -> Add YouTube."

Get profile ID:
```bash
curl -s "https://zernio.com/api/v1/profiles" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" | node -e "
const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
(d.profiles||d||[]).forEach(p => console.log('Profile:', p.name || p._id, '| profileId:', p._id));
"
```

### Phase 1: Locate Video File

The video file can be:
1. **Already downloaded** — user sent via Telegram, auto-downloaded to `/workspace/group/`
2. **Needs download** — use `download_attachment` MCP tool with file_id from the Telegram message
3. **On host filesystem** — mounted at `/workspace/extra/`

```bash
find /workspace -name "*.mp4" -o -name "*.mov" -o -name "*.avi" -o -name "*.webm" \
  -o -name "*.mkv" 2>/dev/null | head -20
ls -lh <VIDEO_PATH>
```

If video file not found, ask user: "Где находится видео? Отправь файл в чат или укажи путь."

**Size check:** Zernio supports up to 5GB. If file > 5GB, warn user.

### Phase 2: Generate Metadata

Based on conversation context (user's message, wiki, previous analysis), generate:

**Title** (max 100 chars, Cyrillic):
- Include 1-2 keywords for SEO
- Emotional hook or number if relevant
- NO clickbait — accurate to content
- Examples: "Как запустить ИИ-воронку за 30 минут | Пошаговый разбор"

**Description** (up to 5000 chars):
```
[1-2 sentence hook — повтор title с деталями]

В этом видео:
[00:00] Вступление
[MM:SS] Тема 1
...

---
Полезные ссылки:
- Бесплатный воркшоп: https://ashotai.uz
- Telegram: https://t.me/ashotaiexpert
- Instagram: https://instagram.com/ashotaiexpert

---
#ashotai #ии #бизнес
```

**Tags** (array, 5-15 tags):
- Mix of broad ("бизнес", "ИИ") and specific ("автоворонка", "OctoFunnel")
- Include Russian AND English versions
- Include "ashotai" branded tag

**Category:**
| ID | Name | When to use |
|----|------|-------------|
| 22 | People & Blogs | Default for vlogs, streams |
| 27 | Education | Tutorials, workshops, courses |
| 28 | Science & Technology | AI/tech demos |

Default: `"27"` (Education) for AshotAI content.

### Phase 3: Thumbnail (Optional)

If user provides a thumbnail — use it directly. Otherwise, offer to generate via design-youtube-thumbnail skill. Upload thumbnail via presign:

```bash
curl -s -X POST "https://zernio.com/api/v1/media/presign" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"filename":"thumbnail.png","contentType":"image/png"}' > /tmp/thumb-presign.json

# Upload to presigned URL, get publicUrl for use in post
```

### Phase 4: Upload Video to Zernio

**Step 1 — Get presigned upload URL via `POST /v1/media/presign`:**
```bash
FILE_PATH="<path to video>"
FILE_SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null || stat -f%z "$FILE_PATH")
FILE_NAME=$(basename "$FILE_PATH")

# Detect MIME type
case "${FILE_NAME##*.}" in
  mp4) MIME="video/mp4" ;;
  mov) MIME="video/quicktime" ;;
  avi) MIME="video/x-msvideo" ;;
  webm) MIME="video/webm" ;;
  *) MIME="video/mp4" ;;
esac

curl -s -X POST "https://zernio.com/api/v1/media/presign" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILE_NAME\",\"contentType\":\"$MIME\",\"size\":$FILE_SIZE}" \
  > /tmp/upload-presign.json

node -e "
const d = JSON.parse(require('fs').readFileSync('/tmp/upload-presign.json','utf8'));
console.log('UPLOAD_URL=' + d.uploadUrl);
console.log('PUBLIC_URL=' + d.publicUrl);
console.log('EXPIRES_IN=' + d.expiresIn + 's');
"
```

Response: `{ "uploadUrl": "<presigned S3 PUT URL>", "publicUrl": "<CDN URL>", "key": "...", "expiresIn": 3600 }`

**Step 2 — Upload file (can take minutes for large videos):**

Notify user before long upload: "Загружаю видео (SIZE МБ), это может занять несколько минут..."

```bash
curl -X PUT "<uploadUrl>" \
  -H "Content-Type: $MIME" \
  --data-binary @"$FILE_PATH" \
  --max-time 1800 -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s"
```

Must return HTTP 200. If timeout — retry with `--max-time 3600`.

### Phase 5: Create YouTube Post

**Show draft to user before publishing:**
```
*Готово к публикации на YouTube:*

*Название:* <title>
*Описание:* <first 200 chars>...
*Теги:* <tags>
*Видимость:* публичное / скрытое / по ссылке
*Обложка:* [сгенерирована / от пользователя / стандартная]

Публикуем?
```

Use inline buttons: `Публикуем` / `По ссылке сначала` / `Отмена`

**Publish via `POST /v1/posts`:**

```bash
# Build payload with CORRECT field names
python3 << 'EOF' > /tmp/yt-payload.json
import json
payload = {
    "profileId": "<PROFILE_ID>",
    "content": "<DESCRIPTION>",          # NOT "text"!
    "platforms": [
        {
            "platform": "youtube",
            "accountId": "<YT_ACCOUNT_ID>",
            "platformSpecificData": {
                "title": "<TITLE max 100 chars>",
                "visibility": "public",   # or "unlisted" / "private"
                "madeForKids": False
            }
        }
    ],
    "mediaItems": [                       # NOT "mediaUrls"!
        {
            "type": "video",
            "url": "<PUBLIC_URL from presign>",
            "filename": "<FILE_NAME>",
            "mimeType": "video/mp4",
            "size": <FILE_SIZE_BYTES>
        }
    ],
    "tags": ["tag1", "tag2"],
    "publishNow": True
}
print(json.dumps(payload, ensure_ascii=False))
EOF

curl -s -X POST "https://zernio.com/api/v1/posts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/yt-payload.json > /tmp/publish-result.json
```

Response: `post.platforms[0].status` = `"uploading"` initially → `"published"` after Zernio transfers to YouTube (1-5 min for large files).

**Scheduled publish** (user says "выложи завтра в 9 утра"):
```bash
# Replace publishNow with scheduledFor (convert Tashkent UTC+5 to UTC)
"scheduledFor": "2026-04-19T04:00:00.000Z"
```

### Phase 6: Monitor Upload & Confirm

Poll status every 30 seconds until `published` or `failed`:

```bash
curl -s "https://zernio.com/api/v1/posts/<POST_ID>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" | node -e "
const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
const post = d.post || d;
const yt = (post.platforms||[]).find(p => p.platform === 'youtube');
console.log('Status:', yt?.status, '| URL:', yt?.platformPostUrl || 'processing...');
"
```

Send confirmation when published:
```
*Видео опубликовано на YouTube!*

*Название:* <title>
*Ссылка:* <youtube_url>

YouTube обрабатывает HD качество — доступно через 15-60 мин.
```

### Phase 7: Update Metadata (if needed post-publish)

Use `POST /v1/posts/{postId}/update-metadata` to fix title/description/tags without re-uploading:

```bash
curl -s -X POST "https://zernio.com/api/v1/posts/<POST_ID>/update-metadata" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "platform": "youtube",
    "title": "<new title>",
    "description": "<new description>",
    "tags": ["tag1", "tag2"],
    "categoryId": "27",
    "privacyStatus": "public",
    "thumbnailUrl": "<URL>",
    "madeForKids": false,
    "playlistId": "<playlist ID>"
  }'
```

Also works for videos not published through Zernio — use `_` as postId + pass `videoId` and `accountId`.

### Phase 7b: Wiki Ingest (MANDATORY for published videos)

Every published video MUST be ingested into the wiki so it can be recommended to clients, referenced in content plans, and searched later.

**Two destinations must be synced — both mandatory, both via main agent (curator):**

| Destination | Used by | What goes there |
|---|---|---|
| `/workspace/global/wiki/sources/<date>-yt-<slug>.md` | main, channel-promoter, youtube-manager (read) | Full transcript + source-summary frontmatter + entity/concept back-refs |
| `/workspace/global/wiki/entities/ashotai-youtube.md` | same | Video row in the channel catalog (title, URL, views, duration, date) |
| **`groups/_shared-products/videos.md`** | **public-lead Мила** via `/workspace/products` readonly mount | Curated client-facing entry with funnel stage + "Рекомендуй когда..." trigger. This is the ONLY place public-lead can read from — if it's missing, Мила can't reference the video in client chats. |

**Why `_shared-products/videos.md` matters:** public-lead containers have `isPublic=true` → they get only `/workspace/products` (read-only) as their shared surface, NOT `/workspace/global`. Skipping this sync means the video is invisible to Мила when talking to leads from Telegram Ads.

**Funnel-stage classification (required for videos.md entry):**

| Stage | Use for | Example trigger |
|---|---|---|
| Cold | awareness content, pain identification | "лид не понимает с чего начать" |
| Qualifying | clarifying intent | "лид думает что нужна большая аудитория" |
| Interested | how-to / demo | "хочет увидеть как работает OctoFunnel" |
| Hot | decision support / pricing | "серьёзно рассматривает, нужен roadmap" |
| Education | deep dives / recordings | "хочет увидеть изнутри", "полный разбор" |
| Partner | B2B for resellers/agencies | "делает SMM/таргет для других" |

Delegate to main Mila via a scheduled once-task (she is the wiki curator — per global/CLAUDE.md rule):

```bash
NEXT_RUN=$(python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) + timedelta(seconds=60)).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")
TASK_ID="task-$(date +%s)-wiki-ingest-$(basename $VIDEO_FILE .mp4)"
NOW=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")

# Prompt tells main to:
# 1. Create /workspace/global/wiki/sources/YYYY-MM-DD-yt-<slug>.md with frontmatter + full transcript
# 2. Update /workspace/global/wiki/entities/ashotai-youtube.md — add video to list
# 3. Update related concepts (nanoclaw, second-brain, octofunnel, etc.) with back-refs
# 4. Update index.md + log.md
# 5. Git commit

sqlite3 store/messages.db <<EOF
INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode)
VALUES ('$TASK_ID', 'telegram_main', '<main_jid>', '<full ingest prompt>', 'once', '$NEXT_RUN', '$NEXT_RUN', 'active', '$NOW', 'group');
EOF
```

**Wiki source frontmatter format** (follow existing yt-*.md pattern):
```yaml
---
title: "<video title>"
type: source-summary
source: youtube
channel: ashotaiexpert
video_id: <YT video ID>
video_url: https://www.youtube.com/watch?v=<id>
duration: <HH:MM:SS>
date: <record date>
created: <ingest date>
telegram_post: https://t.me/ashotonline/<msg_id>  # if cross-posted
related: ["[[entities/ashotai-youtube]]", "[[entities/octofunnel]]", ...]
tags: [youtube, transcript, <topic tags>]
---
```

**Sections:**
- Overview / Key topics
- Timestamps
- Mentioned products/concepts (with wiki-links)
- Full transcript (for searchability — can be 100KB+)

**Why mandatory:**
- Mila can recommend specific videos to clients ("посмотри разбор от 17 апреля")
- Content planner can reference past videos to avoid duplication
- Wiki queries find precise moments in transcripts (e.g. "когда Ашот говорил про Telegram Ads?")
- Cross-links with `entities/*` build a knowledge graph

### Phase 8: Cross-Post (Optional)

If user wants to announce the video on other platforms:
```bash
curl -s -X POST "https://zernio.com/api/v1/posts" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "profileId": "<PROFILE_ID>",
    "content": "<SHORT_ANNOUNCEMENT + YOUTUBE_LINK>",
    "platforms": [
      {"platform": "telegram", "accountId": "<TG_ID>"},
      {"platform": "instagram", "accountId": "<IG_ID>"}
    ],
    "publishNow": true
  }'
```

Always ask before cross-posting: "Хочешь анонсировать видео в Telegram/Instagram?"

**Update wiki** — log the upload:
```bash
echo "- $(date +%Y-%m-%d) | YouTube upload: \"<TITLE>\" | <YOUTUBE_URL>" \
  >> /workspace/group/wiki/log.md
```

## Live Stream Recording Notes

For recorded live streams (the primary use case):
- Title format: "ТЕМА | Запись эфира от DD.MM.YYYY"
- Description: include timestamp markers if known
- Tags: include "запись эфира", "стрим", "live"
- If transcript exists, use it to generate accurate tайм-коды

## Safety Rules

- **NEVER publish without user confirmation** — always show draft
- **Default to "unlisted"** — offer to change to "public" after user reviews
- **Large files (>1GB):** warn about upload time before starting
- **Verify YouTube account is connected** before attempting upload

## Error Handling

- **Upload timeout:** retry with `--max-time 3600` for very large files
- **"Account not connected":** direct user to zernio.com settings
- **"Quota exceeded":** YouTube has 10,000 unit daily quota — try again tomorrow
- **Post creation failed:** check response body, report exact error
- **Metadata update available:** use `/update-metadata` to fix without re-uploading

## Cost

Zero additional — included in Zernio subscription.
