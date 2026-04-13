---
name: instagram-analyzer
description: Deep Instagram profile analysis for business/expert positioning. Scrapes via Apify, analyzes images via OpenRouter vision, transcribes video via Deepgram, screenshots profile via browser, matches author face across posts, saves to wiki media catalog and Okto-ready JSON.
---

# Instagram Profile Analyzer

Analyze Instagram profiles to understand business positioning, content strategy, visual branding, and audience. Results feed into client profiles, wiki knowledge base, and Okto funnel strategy.

## Prerequisites

- `$APIFY_TOKEN` — Apify API key (container env var)
- `$OPENROUTER_API_KEY` — OpenRouter API key (container env var)
- Deepgram key in `/workspace/group/config.json`:
  ```bash
  DEEPGRAM_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.deepgram_api_key||c.deepgramApiKey||'')}catch{console.log('')}")
  ```

## Trigger

When user asks to analyze an Instagram profile. Accept:
- `https://instagram.com/username`, `@username`, `username`
- "проанализируй инстаграм", "analyze Instagram profile"

## API Helpers

**Apify sync endpoint:**
```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/<ACTOR_ID>/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=300" \
  -H "Content-Type: application/json" -d '<INPUT_JSON>'
```

**OpenRouter (image analysis):**
```bash
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,<B64>"}},{"type":"text","text":"<PROMPT>"}]}]}'
```

**OpenRouter (video analysis):**
```bash
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-pro-exp-02-05","messages":[{"role":"user","content":[{"type":"file","file":{"filename":"video.mp4","content_type":"video/mp4","data":"<B64>"}},{"type":"text","text":"<PROMPT>"}]}]}'
```

**Deepgram transcription:**
```bash
curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" \
  --data-binary @<AUDIO_FILE>
```

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

Check for existing analysis:
```bash
if [ -f "$WD/okto-summary.json" ]; then
  # RE-ANALYSIS MODE: merge new data, don't overwrite
  PREV_DATE=$(node -e "const d=JSON.parse(require('fs').readFileSync('$WD/okto-summary.json','utf8'));console.log(d.analyzedAt||'')")
  echo "Re-analysis detected. Previous run: $PREV_DATE. Will filter new posts only."
fi
```

**IMPORTANT:** `cd` does NOT persist between Bash calls. Always use `$WD/` absolute paths everywhere.

Send progress: "Начинаю анализ Instagram профиля @username..."

### Phase 1: Profile + Avatar Face Detection

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/apify~instagram-profile-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=120" \
  -H "Content-Type: application/json" \
  -d '{"usernames":["<USERNAME>"]}' > $WD/raw-profile.json
```

Extract: fullName, biography, followersCount, followsCount, postsCount, externalUrl, isBusinessAccount, businessCategory, profilePicUrl.

**Download and analyze avatar:**
```bash
AVATAR_URL=$(node -e "const d=JSON.parse(require('fs').readFileSync('$WD/raw-profile.json','utf8'));console.log(d[0]?.profilePicUrlHD||d[0]?.profilePicUrl||'')")
curl -sL -o $WD/avatar.jpg "$AVATAR_URL"
```

Analyze face via OpenRouter, save to `$WD/face-reference.json`:
```json
{"hasFace":true,"faceDescription":"woman, ~30, dark hair, oval face, warm smile","facePosition":"center","backgroundColors":["white","beige"]}
```

**Determine business type** from profile data — one of: `services`, `products`, `venue`, `education`, `health`, `food`, `personal-brand`.

Send progress: "Профиль: <name>, <followers> подписчиков. Тип: <type>. Сканирую посты..."

### Phase 1.2: Website Analysis

Extract URLs from bio:
```bash
node -e "
const d=JSON.parse(require('fs').readFileSync('$WD/raw-profile.json','utf8'))[0]||{};
const urls=new Set();
if(d.externalUrl) urls.add(d.externalUrl);
const bioUrls=(d.biography||'').match(/https?:\/\/[^\s)]+/g)||[];
bioUrls.forEach(u=>urls.add(u));
require('fs').writeFileSync('$WD/bio-urls.json',JSON.stringify([...urls],null,2));
console.log('Found',urls.size,'URLs');
"
```

Run the **website-analyzer** skill workflow for each URL found.

### Phase 1.5: Profile Screenshots via Browser

```bash
# Load all available auth sessions
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done

agent-browser open "https://instagram.com/<username>"
agent-browser wait --timeout 5000
```

Handle login wall gracefully — if Instagram blocks with a login popup, skip screenshots and note it.

**Screenshot 1:** Full profile page
```bash
agent-browser screenshot --full $WD/screenshots/profile-full.png
```

**Screenshot 2:** Grid section (scroll down)
```bash
agent-browser evaluate "window.scrollBy(0, 600)"
agent-browser wait --timeout 3000
agent-browser screenshot $WD/screenshots/profile-grid.png
```

**Screenshot 3:** Reels tab
```bash
agent-browser snapshot -i ref
# Click the Reels tab link
agent-browser click --ref <reels-tab-ref>
agent-browser wait --timeout 5000
# Verify reels loaded before capturing
agent-browser screenshot $WD/screenshots/reels-grid.png
```

**Screenshot 4 (optional):** If business-relevant highlights exist, click into them and screenshot.

Analyze all screenshots via OpenRouter for visual branding, layout, and content themes.

### Phase 2: Broad Post Scan + Smart Selection

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/apify~instagram-post-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=300" \
  -H "Content-Type: application/json" \
  -d '{"username":"<USERNAME>","resultsLimit":150}' > $WD/raw-posts.json
```

**Pre-filter with Node:**
```bash
node -e "
const posts=JSON.parse(require('fs').readFileSync('$WD/raw-posts.json','utf8'));
const kw=/narx|xizmat|kurs|chegirma|mahsulot|natija|цен|услуг|курс|скидк|продукт|результат|price|service|course|discount|product|result/i;
const scored=posts.filter(p=>p.caption||p.imageUrl).map((p,i)=>({
  idx:i, caption:(p.caption||'').slice(0,300), type:p.type||'image',
  likes:p.likesCount||0, comments:p.commentsCount||0,
  date:p.timestamp||'', url:p.url||'', imageUrl:p.imageUrl||'',
  imageUrls:p.imageUrls||[], isCarousel:!!p.imageUrls?.length,
  hasKw:kw.test(p.caption||''),
  score:(kw.test(p.caption||'')?50:0)+(p.likesCount||0)*0.01+(p.commentsCount||0)*0.1
}));
scored.sort((a,b)=>b.score-a.score);
require('fs').writeFileSync('$WD/scored-posts.json',JSON.stringify(scored.slice(0,50),null,2));
console.log('Total:',posts.length,'| Scored:',scored.length);
"
```

**Handle carousel posts:** Each post may have `imageUrls[]` array. Download up to 4 images per carousel.

**Smart-select 30 posts** covering: product/service shots, client results, expert content, high engagement, recent posts.

In RE-ANALYSIS mode, filter out posts already in previous analysis (compare by `date > PREV_DATE`).

**Download images:**
```bash
curl -sL -o $WD/images/post-<N>.jpg "<imageUrl>"
# For carousels:
curl -sL -o $WD/images/post-<N>-slide-<M>.jpg "<imageUrls[M]>"
```

Send progress: "Отобрано 30 постов. Сканирую рилсы..."

### Phase 3: Broad Reel Scan + Smart Selection + Transcription

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/apify~instagram-reel-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=300" \
  -H "Content-Type: application/json" \
  -d '{"username":"<USERNAME>","resultsLimit":80}' > $WD/raw-reels.json
```

Pre-filter and smart-select 15 reels using same keyword scoring.

**IMMEDIATELY download top 5 videos** — Apify video URLs expire quickly!
```bash
curl -sL -o $WD/reels/reel-<N>.mp4 "<videoUrl>"
```

**Extract audio and transcribe via Deepgram:**
```bash
ffmpeg -i $WD/reels/reel-<N>.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 $WD/reels/reel-<N>.wav 2>/dev/null
curl -s -X POST "https://api.deepgram.com/v1/listen?detect_language=true&model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_KEY" -H "Content-Type: audio/wav" \
  --data-binary @$WD/reels/reel-<N>.wav > $WD/reels/reel-<N>-transcript.json
```

**Video analysis via OpenRouter Gemini Pro** for top reels (visual content, presentation style, production quality).

Send progress: "Рилсы обработаны. Анализирую комментарии..."

### Phase 4: Comments on Top 5 Posts

```bash
curl -s -X POST \
  "https://api.apify.com/v2/acts/apify~instagram-comment-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=120" \
  -H "Content-Type: application/json" \
  -d '{"postUrls":["<POST_URL>"],"resultsLimit":50}' > $WD/comments-post-<N>.json
```

Extract: FAQ patterns, audience pain points, testimonials, objections, language distribution.

Send progress: "Комментарии собраны. Анализирую изображения..."

### Phase 5: Vision Analysis + Face Matching + Photo Classification

For each downloaded image, analyze via OpenRouter with face reference:
```
Prompt: "Analyze this Instagram post image. The account owner looks like: <faceDescription from face-reference.json>.
Return JSON: {
  'content': 'what is shown',
  'colors': ['dominant','secondary'],
  'style': 'professional|casual|luxury|minimal|bright',
  'hasOwnerFace': true/false,
  'category': 'author|products|venue|social-proof|branding|lifestyle',
  'quality': 'high|medium|low',
  'funnelUse': 'hero|trust|offer|education|social-proof|none'
}"
```

**Classify by business type:**

| Business Type | Priority Categories |
|---------------|-------------------|
| services | author, social-proof, venue |
| products | products, branding, social-proof |
| venue | venue, branding, social-proof |
| education | author, social-proof, branding |
| health | author, social-proof, venue |
| food | products, venue, branding |
| personal-brand | author, branding, social-proof |

**Copy to category directories:**
```bash
cp $WD/images/post-<N>.jpg $WD/categories/<category>/
```

Send progress: "Фото классифицированы. Отправляю лучшие..."

### Phase 6: Present Photos to User via send_file

Send the best photos from each category to the user using `send_file`, grouped by category with brief descriptions of each selection and why it works for funnels.

### Phase 7: Wiki Media Catalog Ingest

**7a. Copy media to wiki:**
```bash
MEDIA_DIR=/workspace/group/wiki/media/instagram/<username>
mkdir -p $MEDIA_DIR/{posts,reels,screenshots}
cp $WD/images/* $MEDIA_DIR/posts/ 2>/dev/null
cp $WD/avatar.jpg $MEDIA_DIR/ 2>/dev/null
cp $WD/screenshots/* $MEDIA_DIR/screenshots/ 2>/dev/null
```

**7b. Create catalog** at `wiki/media/instagram/<username>/catalog.md`:
Tables of all media with file paths, categories, quality ratings, and funnel use.

**7c. Update media-index.json:**
```bash
node -e "
const idx=JSON.parse(require('fs').readFileSync('/workspace/group/wiki/media/media-index.json','utf8').catch(()=>'{}'));
idx['instagram/<username>']={type:'instagram',analyzedAt:new Date().toISOString(),fileCount:<N>};
require('fs').writeFileSync('/workspace/group/wiki/media/media-index.json',JSON.stringify(idx,null,2));
"
```

**7d. Create wiki entity page** at `wiki/entities/<username>.md`:
```yaml
---
title: "Instagram — @<username>"
type: entity
subtype: instagram-profile
created: YYYY-MM-DD
tags: [instagram, profile-analysis, content-analysis]
confidence: high
---
```
Sections: Overview, Profile Metrics, Content Strategy, Visual Branding, Top Posts, Audience Insights, Services & Products, Media Assets for Funnels.

**7e. .gitignore for binary media files:**
```bash
echo "*.jpg" >> $MEDIA_DIR/.gitignore
echo "*.png" >> $MEDIA_DIR/.gitignore
echo "*.mp4" >> $MEDIA_DIR/.gitignore
echo "*.wav" >> $MEDIA_DIR/.gitignore
```

**7f. In RE-ANALYSIS mode:** MERGE into existing wiki entity page and catalog. Do not overwrite previous entries.

**7g. Source summary + index + log + git commit:**
```bash
cd /workspace/group/wiki && git add -A && git commit -m "instagram-analyzer: @<username> $(date +%Y-%m-%d)"
```

Send progress: "Wiki обновлена. Формирую итоговый отчёт..."

### Phase 8: Okto-Ready Output

Save `$WD/okto-summary.json`:
```json
{
  "username":"","fullName":"","businessType":"",
  "followers":0,"following":0,"postsCount":0,
  "biography":"","externalUrl":"","websites":[],
  "contentTopics":[],"visualStyle":"","tone":"","languages":[],
  "services":[],"pricing":[],"audienceFAQ":[],
  "topPosts":[{"url":"","caption":"","likes":0,"category":"","funnelUse":"","selected":false}],
  "topReels":[{"url":"","caption":"","transcript":"","views":0}],
  "mediaCategories":{"author":[],"products":[],"venue":[],"social-proof":[],"branding":[]},
  "faceReference":{"hasFace":false,"description":""},
  "profileScreenshots":["profile-full.png","profile-grid.png","reels-grid.png"],
  "analyzedAt":"<ISO timestamp>"
}
```

In RE-ANALYSIS mode: MERGE into existing `okto-summary.json`. Preserve any `"selected": true` choices the user made previously. Add new posts/reels, update metrics, bump `analyzedAt`.

Send final summary to the user with key findings and selected media.

## Error Handling

- **Apify timeout:** Reduce `resultsLimit`, retry with lower limit
- **Login wall on screenshots:** Skip browser phase, note in output
- **Video URL expired:** Log warning, skip transcription for that reel
- **Deepgram unavailable:** Analyze reels visually only, note missing transcripts
- **No face in avatar:** Set `hasFace: false`, skip face matching in Phase 5
- **Profile is private:** Report to user immediately, abort analysis

## Cost Estimate

~$0.50-1.00 per profile: Apify ~$0.25-0.50, Deepgram ~$0.05-0.20, OpenRouter ~$0.10-0.30.
