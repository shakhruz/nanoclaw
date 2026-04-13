---
name: youtube-analyzer
description: Deep YouTube channel and video analysis for business/expert positioning. Scrapes channel data, videos, comments via Apify, extracts transcripts, analyzes video content, saves to wiki. Use when asked to analyze a YouTube channel, video, or when building a client profile.
---

# YouTube Channel & Video Analyzer

Analyze YouTube channels and individual videos to understand the business/expert's content, audience, and expertise. Results feed into client profiles and Okto funnel strategy.

## Prerequisites

- `$APIFY_TOKEN` — Apify API key (container env var)
- `$OPENROUTER_API_KEY` — OpenRouter API key (container env var)
- Deepgram key in `/workspace/group/config.json` (for videos without subtitles)

## Trigger

When user asks to analyze a YouTube channel or video. Accept:
- Channel: `https://youtube.com/@username`, `https://youtube.com/c/ChannelName`, `@username`
- Video: `https://youtube.com/watch?v=XXXXX`, `https://youtu.be/XXXXX`
- Playlist: `https://youtube.com/playlist?list=XXXXX`
- "проанализируй ютуб канал", "analyze YouTube"

## Apify Actors

| Purpose | Actor ID | Use |
|---------|----------|-----|
| Channel info + video list | `streamers~youtube-scraper` | Main scraper: channel data + all videos |
| Channel metadata | `streamers~youtube-channel-scraper` | Fast channel info (subs, description) |
| Transcripts | `pintostudio~youtube-transcript-scraper` | YouTube auto-captions extraction |
| Comments | `streamers~youtube-comments-scraper` | Video comments |

**Apify sync endpoint** (same as Instagram):
```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/<ACTOR_ID>/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=300" \
  -H "Content-Type: application/json" -d '<INPUT_JSON>'
```

## Workflow

### Phase 0: Setup

```bash
# Extract channel handle or video ID from input
export WD=/workspace/group/youtube-analysis/<channel-or-id>
mkdir -p $WD/{videos,thumbnails,transcripts,screenshots}
```

Detect input type:
- Channel URL → full channel analysis (all phases)
- Individual video URL(s) → skip to Phase 3 (direct video analysis)
- Playlist URL → extract video list, then Phase 3

Send progress: "Начинаю анализ YouTube канала..."

### Phase 1: Channel Profile

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/streamers~youtube-channel-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=120" \
  -H "Content-Type: application/json" \
  -d '{"channelUrls":["https://www.youtube.com/@<HANDLE>"]}' > $WD/raw-channel.json
```

Extract: channelName, subscriberCount, videoCount, description, thumbnailUrl, bannerUrl, country, joinedDate, links.

Download channel avatar:
```bash
AVATAR_URL=$(node -e "const d=JSON.parse(require('fs').readFileSync('$WD/raw-channel.json','utf8'));console.log(d[0]?.thumbnailUrl||'')")
curl -sL -o $WD/channel-avatar.jpg "$AVATAR_URL"
```

**Face detection** via OpenRouter (same as Instagram):
Analyze avatar → save to `$WD/face-reference.json`.

**Browser screenshot** (optional, if auth available):
```bash
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "https://www.youtube.com/@<HANDLE>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/screenshots/channel-page.png
```

Send progress: "Канал: <name>, <subs> подписчиков. Сканирую видео..."

### Phase 2: Broad Video Scan + Smart Selection

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/streamers~youtube-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=300" \
  -H "Content-Type: application/json" \
  -d '{"startUrls":[{"url":"https://www.youtube.com/@<HANDLE>"}],"maxResults":200}' > $WD/raw-videos.json
```

**Pre-filter with Node:**
```bash
node -e "
const vids=JSON.parse(require('fs').readFileSync('$WD/raw-videos.json','utf8'));
const kw=/цен|прайс|стоимост|услуг|курс|урок|мастер.класс|отзыв|результат|продукт|обучени|вебинар|narx|xizmat|kurs|dars|price|service|course|lesson|masterclass|review|tutorial|webinar/i;
const s=vids.filter(v=>v.title).map((v,i)=>({
  idx:i, title:(v.title||'').slice(0,200), description:(v.description||'').slice(0,300),
  views:v.viewCount||0, likes:v.likes||0, date:v.date||v.uploadDate||'',
  duration:v.duration||'', url:v.url||'', thumbnailUrl:v.thumbnailUrl||'',
  hasKw:kw.test((v.title||'')+(v.description||'')),
  score:(kw.test((v.title||'')+(v.description||''))?50:0)+(v.viewCount||0)*0.0001+(v.likes||0)*0.01
}));
s.sort((a,b)=>b.score-a.score);
require('fs').writeFileSync('$WD/scored-videos.json',JSON.stringify(s.slice(0,50),null,2));
console.log('Total videos:',vids.length,'| Pre-filtered:',s.length);
"
```

**Smart selection:** Read `$WD/scored-videos.json`. Select 20-30 for analysis:
1. **Courses/lessons** — мастер-классы, уроки, обучающий контент
2. **Product/service demos** — обзоры, показ работы
3. **Client testimonials** — отзывы, кейсы
4. **Expert content** — где автор делится экспертизой
5. **High engagement** — аномально много просмотров/лайков
6. **Recent** — свежий контент показывает текущее направление

Skip: shorts без содержания, музыкальные видео, vlogs без бизнес-контента.

**Download thumbnails** of selected videos:
```bash
curl -sL -o $WD/thumbnails/video-<N>.jpg "<thumbnailUrl>"
```

Send progress: "Отобрано N видео для анализа. Извлекаю транскрипты..."

### Phase 3: Transcript Extraction

**Step 1 — Batch transcript extraction via Apify:**
```bash
# Extract transcripts for all selected videos at once
node -e "
const scored=JSON.parse(require('fs').readFileSync('$WD/scored-videos.json','utf8'));
const urls=scored.slice(0,30).map(v=>v.url).filter(Boolean);
console.log(JSON.stringify({urls:urls}));
" > /tmp/transcript-input.json

curl -s -X POST \
  "https://api.apify.com/v2/acts/pintostudio~youtube-transcript-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=300" \
  -H "Content-Type: application/json" \
  -d @/tmp/transcript-input.json > $WD/raw-transcripts.json
```

**Step 2 — For videos WITHOUT transcripts, use Deepgram:**
Check which videos returned empty transcripts. For top 3-5 of those:
```bash
# Download audio via yt-dlp or streamers/youtube-video-downloader
# Then extract audio and transcribe
DEEPGRAM_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.deepgram_api_key||c.deepgramApiKey||'')}catch{console.log('')}")

ffmpeg -i $WD/videos/video-<N>.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 $WD/transcripts/video-<N>.wav 2>/dev/null
curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" \
  --data-binary @$WD/transcripts/video-<N>.wav > $WD/transcripts/video-<N>-deepgram.json
```

**Step 3 — Compile all transcripts:**
Save consolidated `$WD/all-transcripts.json`:
```json
[{"videoId":"","title":"","transcript":"","source":"youtube|deepgram","language":""}]
```

Send progress: "Транскрипты получены для N видео. Анализирую контент..."

### Phase 4: Deep Video Analysis (top 5-8)

For the most important videos:

**4a. Visual analysis via OpenRouter** (video URL or thumbnail):
```
Prompt: "Analyze this YouTube video. Describe:
1) Who is presenting — appearance, style
2) Production quality (studio/home/outdoor, lighting, graphics)
3) Visual branding (colors, lower thirds, intro/outro)
4) Content format (talking head, screencast, presentation, interview)
5) Key visual elements (products shown, demonstrations, slides)"
```

**4b. Content analysis from transcript:**
For each transcribed video, analyze:
- Main topic and key points
- Services/products mentioned
- Prices/offers mentioned
- Calls to action
- Teaching style and expertise level
- Language and tone

### Phase 5: Comments (top 5 videos by engagement)

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/streamers~youtube-comments-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=120" \
  -H "Content-Type: application/json" \
  -d '{"videoUrls":["https://www.youtube.com/watch?v=<ID>"],"maxComments":50}' >> $WD/raw-comments.json
```

Extract: FAQ patterns, audience pain points, testimonials, objections.

### Phase 6: Individual Videos (by URL, including unlisted)

When user provides specific video URLs (e.g. unlisted master classes):

```bash
# Apify handles individual URLs directly
curl -s -X POST \
  "https://api.apify.com/v2/acts/streamers~youtube-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=120" \
  -H "Content-Type: application/json" \
  -d '{"startUrls":[{"url":"<VIDEO_URL>"}]}' > $WD/video-<id>.json

# Get transcript
curl -s -X POST \
  "https://api.apify.com/v2/acts/pintostudio~youtube-transcript-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=120" \
  -H "Content-Type: application/json" \
  -d '{"urls":["<VIDEO_URL>"]}' >> $WD/raw-transcripts.json
```

These videos often contain the most valuable content (paid courses, private lessons) — prioritize their analysis.

### Phase 7: Wiki + Media Catalog Ingest

**7a. Copy media to wiki:**
```bash
MEDIA_DIR=/workspace/group/wiki/media/youtube/<channel>
mkdir -p $MEDIA_DIR/{thumbnails,screenshots}
cp $WD/thumbnails/* $MEDIA_DIR/thumbnails/ 2>/dev/null
cp $WD/channel-avatar.jpg $MEDIA_DIR/ 2>/dev/null
cp $WD/screenshots/* $MEDIA_DIR/screenshots/ 2>/dev/null
```

**7b. Create media catalog** at `wiki/media/youtube/<channel>/catalog.md`

**7c. Create wiki entity page** at `wiki/entities/<channel>.md`:
```yaml
---
title: "YouTube — @<channel>"
type: entity
subtype: youtube-channel
created: YYYY-MM-DD
related: ["[[entities/<instagram-username>]]"]
tags: [youtube, video, content-analysis]
confidence: high
---
```

Sections: Overview, Channel Metrics, Content Strategy (topics, formats, frequency), Top Videos (with transcripts), Audience (from comments), Teaching Style, Services & Products Mentioned, Video Assets for Funnels.

**7d. Ingest transcripts as wiki sources:**
Each major video transcript → `wiki/sources/YYYY-MM-DD-yt-<title-slug>.md`
This makes video content searchable in wiki queries.

**7e. .gitignore for media, update index + log + git commit.**

### Phase 8: Summary + okto-summary merge

Save `$WD/channel-summary.json`:
```json
{
  "channelName":"", "handle":"", "subscribers":0, "videoCount":0,
  "description":"", "country":"", "links":[],
  "topVideos":[{"title":"","views":0,"transcript":"...","url":""}],
  "contentTopics":[], "teachingStyle":"", "tone":"", "language":"",
  "services":[], "pricing":[], "audienceFAQ":[],
  "thumbnailStyle":"", "productionQuality":"",
  "funnelAssets":{"videoLessons":[],"testimonials":[],"demos":[]},
  "analyzedAt":""
}
```

If Instagram analysis exists for the same person → merge into existing `okto-summary.json`:
- Add `youtube` section
- Cross-reference video content with Instagram services

Send final summary + key thumbnails via `send_file`.

## Error Handling
- **Apify timeout:** reduce maxResults, retry
- **No transcripts available:** fall back to Deepgram (download audio first)
- **Deepgram unavailable:** analyze title + description + comments only
- **Private video without URL:** ask user for link
- **Channel not found:** report to user

## Cost
~$0.30-0.80 per channel: Apify ~$0.20-0.50, Deepgram ~$0.05-0.20, OpenRouter ~$0.05-0.15.
