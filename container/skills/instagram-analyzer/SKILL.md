---
name: instagram-analyzer
description: Deep Instagram profile analysis for business/expert positioning. Scrapes via Apify, analyzes images via OpenRouter vision, transcribes video via Deepgram, screenshots profile via browser, matches author face across posts, saves to wiki media catalog and Okto-ready JSON.
---

# Instagram Profile Analyzer

Analyze Instagram profiles for business positioning, content strategy, visual branding, and audience. Results feed into client profiles, wiki, and Okto funnel strategy.

## Prerequisites

- `$APIFY_TOKEN`, `$OPENROUTER_API_KEY` — container env vars
- Deepgram key: `DEEPGRAM_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.deepgram_api_key||c.deepgramApiKey||'')}catch{console.log('')}")`

## Trigger

When user asks to analyze an Instagram profile (`https://instagram.com/username`, `@username`, `username`, "проанализируй инстаграм").

## API Patterns

All APIs follow these base patterns — substitute `<PLACEHOLDERS>` per call:

**Apify:** `curl -s -X POST "https://api.apify.com/v2/acts/<ACTOR_ID>/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=<T>" -H "Content-Type: application/json" -d '<INPUT>'`

**OpenRouter (image):** `curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,<B64>"}},{"type":"text","text":"<PROMPT>"}]}]}'`

**OpenRouter (video):** Same endpoint, model `google/gemini-2.0-pro-exp-02-05`, content uses `{"type":"file","file":{"filename":"video.mp4","content_type":"video/mp4","data":"<B64>"}}`.

**Deepgram:** `curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" --data-binary @<FILE>`

## Apify Actors

| Purpose | Actor ID |
|---------|----------|
| Profile info | `apify~instagram-profile-scraper` |
| Posts | `apify~instagram-post-scraper` |
| Reels | `apify~instagram-reel-scraper` |
| Comments | `apify~instagram-comment-scraper` |

## Workflow

### Phase 0: Setup + Re-analysis Detection

```bash
export WD=/workspace/group/instagram-analysis/<username>
mkdir -p $WD/{images,videos,reels,screenshots,categories/{author,products,venue,social-proof,branding}}
```

If `$WD/okto-summary.json` exists: RE-ANALYSIS MODE — merge new data, filter posts by `date > PREV_DATE`.

**IMPORTANT:** `cd` does NOT persist between Bash calls. Always use `$WD/` absolute paths.

Send progress: "Начинаю анализ Instagram профиля @username..."

### Phase 1: Profile + Avatar Face Detection

Apify `apify~instagram-profile-scraper` with `{"usernames":["<USERNAME>"]}` → `$WD/raw-profile.json`.

Extract: fullName, biography, followersCount, followsCount, postsCount, externalUrl, isBusinessAccount, businessCategory, profilePicUrl.

Download avatar, analyze face via OpenRouter → `$WD/face-reference.json`:
```json
{"hasFace":true,"faceDescription":"woman, ~30, dark hair, oval face, warm smile","facePosition":"center","backgroundColors":["white","beige"]}
```

**Determine business type:** `services|products|venue|education|health|food|personal-brand`.

Send progress: "Профиль: <name>, <followers> подписчиков. Тип: <type>. Сканирую посты..."

### Phase 1.2: Website Analysis

Extract URLs from bio into `$WD/bio-urls.json`. Run the **website-analyzer** skill for each URL found.

### Phase 1.5: Profile Screenshots via Browser

```bash
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
agent-browser open "https://instagram.com/<username>"
agent-browser wait --timeout 5000
```

Handle login wall gracefully — skip screenshots if blocked.

Take screenshots: (1) full profile, (2) grid section (scroll 600px), (3) reels tab (click ref), (4) optionally business highlights. Analyze all via OpenRouter for visual branding and themes.

### Phase 2: Broad Post Scan + Smart Selection

Apify `apify~instagram-post-scraper` with `{"username":"<USERNAME>","resultsLimit":150}` → `$WD/raw-posts.json`.

Pre-filter with Node — score by business keywords (`narx|xizmat|kurs|chegirma|цен|услуг|курс|скидк|price|service|course|discount` etc.) + engagement. Save top 50 to `$WD/scored-posts.json`.

Handle carousel posts: download up to 4 images per carousel. Smart-select 30 posts covering product/service shots, client results, expert content, high engagement, recent. In RE-ANALYSIS mode, filter already-analyzed posts.

Download images: `curl -sL -o $WD/images/post-<N>.jpg "<imageUrl>"`

Send progress: "Отобрано 30 постов. Сканирую рилсы..."

### Phase 3: Broad Reel Scan + Smart Selection + Transcription

Apify `apify~instagram-reel-scraper` with `{"username":"<USERNAME>","resultsLimit":80}` → `$WD/raw-reels.json`. Pre-filter and smart-select 15 reels using same scoring.

**IMMEDIATELY download top 5 videos** — Apify URLs expire quickly!

Extract audio and transcribe:
```bash
ffmpeg -i $WD/reels/reel-<N>.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 $WD/reels/reel-<N>.wav 2>/dev/null
```
Then Deepgram transcription. Video analysis via OpenRouter Gemini Pro for top reels.

Send progress: "Рилсы обработаны. Анализирую комментарии..."

### Phase 4: Comments on Top 5 Posts

Apify `apify~instagram-comment-scraper` with `{"postUrls":["<URL>"],"resultsLimit":50}` per post.

Extract: FAQ patterns, audience pain points, testimonials, objections, language distribution.

### Phase 5: Vision Analysis + Face Matching + Photo Classification

For each image, OpenRouter analysis with face reference:
```
Prompt: "Analyze this Instagram post image. The account owner looks like: <faceDescription>.
Return JSON: {'content','colors':[],'style':'professional|casual|luxury|minimal|bright','hasOwnerFace':bool,'category':'author|products|venue|social-proof|branding|lifestyle','quality':'high|medium|low','funnelUse':'hero|trust|offer|education|social-proof|none'}"
```

**Category priorities by business type:** services→author,social-proof,venue | products→products,branding,social-proof | venue→venue,branding,social-proof | education→author,social-proof,branding | health→author,social-proof,venue | food→products,venue,branding | personal-brand→author,branding,social-proof

Copy classified images: `cp $WD/images/post-<N>.jpg $WD/categories/<category>/`

### Phase 6: Present Photos to User via send_file

Send best photos from each category grouped with brief descriptions of why each works for funnels.

### Phase 7: Wiki Media Catalog Ingest

**7a.** Copy media to `wiki/media/instagram/<username>/{posts,reels,screenshots}`.

**7b.** Create `catalog.md` with tables of all media, categories, quality, funnel use.

**7c.** Update `wiki/media/media-index.json` with entry for this profile.

**7d.** Create wiki entity page at `wiki/entities/<username>.md` with frontmatter (`type: entity`, `subtype: instagram-profile`, tags) and sections: Overview, Profile Metrics, Content Strategy, Visual Branding, Top Posts, Audience Insights, Services & Products, Media Assets.

**7e.** Add `.gitignore` for `*.jpg *.png *.mp4 *.wav` in media dir.

**7f.** In RE-ANALYSIS mode: MERGE into existing wiki entity page and catalog.

**7g.** `cd /workspace/group/wiki && git add -A && git commit -m "instagram-analyzer: @<username> $(date +%Y-%m-%d)"`

Send progress: "Wiki обновлена. Формирую итоговый отчёт..."

### Phase 8: Okto-Ready Output

Save `$WD/okto-summary.json`:
```json
{
  "username":"","fullName":"","businessType":"","followers":0,"following":0,"postsCount":0,
  "biography":"","externalUrl":"","websites":[],"contentTopics":[],"visualStyle":"","tone":"","languages":[],
  "services":[],"pricing":[],"audienceFAQ":[],
  "topPosts":[{"url":"","caption":"","likes":0,"category":"","funnelUse":"","selected":false}],
  "topReels":[{"url":"","caption":"","transcript":"","views":0}],
  "mediaCategories":{"author":[],"products":[],"venue":[],"social-proof":[],"branding":[]},
  "faceReference":{"hasFace":false,"description":""},
  "profileScreenshots":["profile-full.png","profile-grid.png","reels-grid.png"],
  "analyzedAt":"<ISO timestamp>"
}
```

In RE-ANALYSIS mode: MERGE into existing file. Preserve `"selected": true` choices. Add new posts/reels, update metrics.

Send final summary with key findings and selected media.
