---
name: design-youtube-thumbnail
description: Generate YouTube video thumbnails using Nano Banana. High-CTR designs with bold text, emotions, contrast. Optimized for click-through rate. Use when asked to create a YouTube thumbnail, video cover, or обложка.
---

# YouTube Thumbnail Designer

Generate high-CTR YouTube thumbnails (1280x720) using Nano Banana image generation. Follows YouTube best practices for maximum click-through rate.

## Prerequisites

- `$OPENROUTER_API_KEY` — for Nano Banana

## Trigger

- "обложка для видео", "YouTube thumbnail"
- "сделай превью", "дизайн для ютуба"

## YouTube Thumbnail Best Practices (baked into prompts)

- **3 elements max:** Face + Text + 1 visual element
- **Face with emotion:** surprise, excitement, curiosity — 2x higher CTR
- **Text: 3-5 words MAX** — readable at phone thumbnail size
- **Contrast:** bright on dark OR dark on bright. No mid-tones.
- **Right 1/3 clear:** YouTube UI overlays timestamp there
- **No small details:** must work at 120x67px (mobile search)

## Thumbnail Styles

### 1. FACE+TEXT (highest CTR)
```
Left 2/3: Person's face showing emotion (surprise/excitement)
Right 1/3: Bold text (2-3 words)
Background: gradient or blurred
```

### 2. BEFORE/AFTER (split)
```
Left half: "Before" state (grey, dull)
Right half: "After" state (bright, colorful)
Dividing line or arrow in center
Text overlay: result metric ("$5000/мес")
```

### 3. STEP/NUMBER (educational)
```
Large number or step count: "5 шагов"
Visual element representing the topic
Small author face in corner
Bold title text
```

### 4. SHOCK/DATA (curiosity gap)
```
Giant number/stat in center ("$2.6 МЛРД")
Shocked face expression
Contrasting background
Minimal text — let the number speak
```

## Workflow

### Phase 1: Get Video Info

Ask user: title, topic, style preference. Or read from YouTube analysis in wiki:
```bash
cat /workspace/group/youtube-analysis/*/channel-summary.json 2>/dev/null
```

### Phase 2: Generate Thumbnail

```bash
export WD=/workspace/group/thumbnails/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
```

**Prompt template:**
```
Generate a YouTube video thumbnail, EXACTLY 1280x720 pixels, landscape.

STYLE: [FACE+TEXT / BEFORE_AFTER / STEP_NUMBER / SHOCK_DATA]

DESIGN RULES:
- Maximum 3 visual elements total
- Text: HUGE, bold, max 5 words. Must be readable at tiny size.
- High contrast: [bright text on dark BG / dark text on bright BG]
- Keep right 1/3 relatively clear (YouTube overlays timestamp)
- Colors: [brand colors or high-energy: red, yellow, blue]

TEXT ON THUMBNAIL: "[TITLE TEXT]" — in Russian, Cyrillic
[Optional: "$5000" or other number — make it GIANT]

VISUAL:
[Description of main visual element — person, product, diagram, screenshot]

DO NOT: use small text, cluttered layouts, low contrast, or more than 3 elements.
```

**With author's face** (from media catalog):
```json
{"messages":[{"role":"user","content":[
  {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,<AUTHOR_PHOTO>"}},
  {"type":"text","text":"Generate a YouTube thumbnail (1280x720). Use THIS person's face on the left side showing excited/surprised expression. Add bold text on the right: '[TITLE]'. Background: dark gradient. High contrast. Max 3 elements."}
]}]}
```

### Phase 3: Send & Iterate

Send via `send_file`. Offer variations:
"Вот 1 вариант. Хочешь попробовать другой стиль или изменить текст?"

Generate 2-3 options if user wants to choose.

### Phase 4: Batch Generation

For existing videos without custom thumbnails:
```bash
# Read video list from YouTube analysis
node -e "
const s=JSON.parse(require('fs').readFileSync('/workspace/group/youtube-analysis/<channel>/channel-summary.json','utf8'));
s.topVideos?.forEach(v=>console.log(v.title,'|',v.url));
"
```
Generate thumbnails for top 5-10 videos. Save all to `$WD/`.

## Cost

~$0.003-0.01 per thumbnail. Batch of 10: ~$0.03-0.10.
