---
name: youtube-analyzer
description: Deep YouTube channel and video analysis for business/expert positioning. Scrapes channel data, videos, comments via Apify, extracts transcripts, analyzes video content, saves to wiki. Use when asked to analyze a YouTube channel, video, or when building a client profile.
---

# YouTube Channel & Video Analyzer

Analyze YouTube channels and videos to understand business/expert content, audience, and expertise. Results feed into client profiles and Okto funnel strategy.

## Prerequisites

- `$APIFY_TOKEN`, `$OPENROUTER_API_KEY` — container env vars
- Deepgram key in `/workspace/group/config.json` (for videos without subtitles)

## Trigger

When user asks to analyze a YouTube channel or video. Accept: channel URLs (`@username`, `/c/Name`), video URLs (`watch?v=`, `youtu.be/`), playlist URLs, "проанализируй ютуб канал", "analyze YouTube".

## Apify Actors

| Purpose | Actor ID |
|---------|----------|
| Channel info + videos | `streamers~youtube-scraper` |
| Channel metadata | `streamers~youtube-channel-scraper` |
| Transcripts | `pintostudio~youtube-transcript-scraper` |
| Comments | `streamers~youtube-comments-scraper` |

**Apify sync endpoint:**
```bash
curl -s -X POST "https://api.apify.com/v2/acts/<ACTOR_ID>/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=<T>" -H "Content-Type: application/json" -d '<INPUT>'
```

## Workflow

### Phase 0: Setup

```bash
export WD=/workspace/group/youtube-analysis/<channel-or-id>
mkdir -p $WD/{videos,thumbnails,transcripts,screenshots}
```

Detect input type: Channel URL → full analysis | Video URL(s) → skip to Phase 3 | Playlist → extract list, then Phase 3.

### Phase 1: Channel Profile

Apify `streamers~youtube-channel-scraper` with `{"channelUrls":["https://www.youtube.com/@<HANDLE>"]}` → `$WD/raw-channel.json`.

Extract: channelName, subscriberCount, videoCount, description, thumbnailUrl, bannerUrl, country, joinedDate, links. Download avatar.

**Face detection** via OpenRouter (same as Instagram) → `$WD/face-reference.json`.

**Browser screenshots:**
```bash
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "https://www.youtube.com/@<HANDLE>"
agent-browser wait --timeout 5000
agent-browser screenshot --full $WD/screenshots/channel-full.png
```
Also capture Videos tab and Playlists tab (if exists).

Send progress: "Канал: <name>, <subs> подписчиков. Сканирую видео..."

### Phase 2: Broad Video Scan + Smart Selection

Apify `streamers~youtube-scraper` with `{"startUrls":[{"url":"https://www.youtube.com/@<HANDLE>"}],"maxResults":200}` → `$WD/raw-videos.json`.

Pre-filter with Node — score by business keywords (`цен|прайс|услуг|курс|урок|мастер.класс|отзыв|результат|narx|xizmat|kurs|price|service|course|review|tutorial|webinar` etc.) + views/likes. Save top 50 to `$WD/scored-videos.json`.

**Smart-select 20-30 videos:** courses/lessons, product/service demos, client testimonials, expert content, high engagement, recent. Skip: empty shorts, music videos, non-business vlogs.

Download thumbnails: `curl -sL -o $WD/thumbnails/video-<N>.jpg "<thumbnailUrl>"`

### Phase 3: Transcript Extraction

**Batch extraction** via Apify `pintostudio~youtube-transcript-scraper` for all selected video URLs → `$WD/raw-transcripts.json`.

Videos without YouTube auto-captions: skip, note count in summary.

Save consolidated `$WD/all-transcripts.json`: `[{"videoId":"","title":"","transcript":"","source":"youtube|deepgram","language":""}]`

### Phase 4: Deep Video Analysis (top 5-8)

**Visual analysis via OpenRouter:**
```
Prompt: "Analyze this YouTube video. Describe: 1) Presenter appearance/style 2) Production quality 3) Visual branding 4) Content format 5) Key visual elements"
```

**Content analysis from transcript:** Main topic, key points, services/products mentioned, pricing, CTAs, teaching style, language/tone.

### Phase 5: Comments (top 5 videos)

Apify `streamers~youtube-comments-scraper` with `{"videoUrls":["<URL>"],"maxComments":50}`. Extract: FAQ patterns, pain points, testimonials, objections.

### Phase 6: Individual Videos (by URL, including unlisted)

When user provides specific URLs: scrape via `streamers~youtube-scraper` + get transcript. These often contain the most valuable content (paid courses, private lessons) — prioritize.

### Phase 7: Wiki + Media Catalog Ingest

**7a.** Copy media to `wiki/media/youtube/<channel>/{thumbnails,screenshots}`.

**7b.** Create `catalog.md`.

**7c.** Create wiki entity at `wiki/entities/<channel>.md` with frontmatter (`type: entity`, `subtype: youtube-channel`, related, tags). Sections: Overview, Channel Metrics, Content Strategy, Top Videos, Audience, Teaching Style, Services & Products, Video Assets.

**7d. Ingest transcripts as wiki sources (CRITICAL):** For top 10-15 videos, create `wiki/sources/YYYY-MM-DD-yt-<slug>.md` with frontmatter, key points, services mentioned, notable quotes, and full transcript. This makes 150K+ chars searchable through wiki queries.

**7e.** Add `.gitignore` for media, update index, git commit.

### Phase 8: Summary + okto-summary merge

Save `$WD/channel-summary.json`:
```json
{
  "channelName":"","handle":"","subscribers":0,"videoCount":0,"description":"","country":"","links":[],
  "topVideos":[{"title":"","views":0,"transcript":"...","url":""}],
  "contentTopics":[],"teachingStyle":"","tone":"","language":"",
  "services":[],"pricing":[],"audienceFAQ":[],
  "thumbnailStyle":"","productionQuality":"",
  "funnelAssets":{"videoLessons":[],"testimonials":[],"demos":[]},
  "analyzedAt":""
}
```

If Instagram analysis exists for same person → merge into existing `okto-summary.json` with `youtube` section and cross-references.

Send final summary + key thumbnails via `send_file`.
