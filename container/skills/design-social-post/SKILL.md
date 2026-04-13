---
name: design-social-post
description: Generate visual posts for Telegram, Instagram, LinkedIn, Facebook using Nano Banana. Quote cards, infographics, announcements, case study visuals, stats cards. Use when asked to create a post design, visual for social media, or баннер.
---

# Social Media Post Designer

Generate visual content for Telegram channel, Instagram feed, LinkedIn, Facebook. Multiple formats for different content types.

## Prerequisites

- `$OPENROUTER_API_KEY` — for Nano Banana

## Trigger

- "дизайн поста", "визуал для поста"
- "баннер", "картинка для телеграм"
- "инфографика", "quote card"

## Post Formats

### 1. QUOTE — Цитата / мысль
**Best for:** Telegram, Instagram, LinkedIn
```
Prompt: "Social media post image, 1080x1080, square.
Clean minimal design. Dark/gradient background.
Large quotation marks at top.
Quote text (Russian, Cyrillic): '[QUOTE TEXT]'
Author name at bottom: '— [NAME]'
Subtle brand element or logo area at bottom.
Style: elegant, professional, inspirational."
```

### 2. STATS — Цифры / статистика
**Best for:** LinkedIn, Instagram, Telegram
```
Prompt: "Social media infographic, 1080x1080, square.
GIANT number in center: '[NUMBER]'
Subtitle below: '[CONTEXT]'
Background: [dark gradient / professional blue]
Small icon or visual element related to the stat.
Style: data-driven, impactful, modern business."
```

### 3. ANNOUNCE — Анонс / событие
**Best for:** All platforms
```
Prompt: "Event announcement post, 1080x1080, square.
Title (large, bold): '[EVENT NAME]'
Date/time: '[DATE]'
Key details: '[1-2 bullet points]'
CTA button shape at bottom: '[CTA TEXT]'
Background: energetic gradient or professional.
Style: urgent, exciting, clear call to action."
```

### 4. CASE — Кейс / результат
**Best for:** Instagram, Facebook, LinkedIn
```
Prompt: "Case study social media post, 1080x1080, square.
Before/After or result showcase.
Client name/photo area at top.
Key metric LARGE: '[RESULT]'
Brief description: '[HOW]'
Brand element at bottom.
Style: proof-driven, trustworthy, professional."
```

### 5. TIP — Совет / лайфхак
**Best for:** Telegram, Instagram
```
Prompt: "Tip/hack social media post, 1080x1080, square.
Light bulb or tip icon.
Title: 'СОВЕТ' or 'ЛАЙФХАК'
Main text (large): '[TIP TEXT]'
Background: bright, attention-grabbing.
Style: helpful, actionable, save-worthy."
```

### 6. BANNER — Широкий баннер (Telegram channel header)
**Best for:** Telegram channel, website
```
Prompt: "Wide banner image, 1280x640 pixels, landscape.
[Professional photo or abstract background]
Title text: '[CHANNEL/BRAND NAME]'
Subtitle: '[TAGLINE]'
Style: professional, trustworthy, modern."
```

## Workflow

### Phase 1: Understand Request

Determine: format type, text content, platform(s), brand style.
If unclear, ask:
```
"Какой формат?
1. 💬 Quote (цитата)
2. 📊 Stats (цифры)
3. 📢 Announce (анонс)
4. ⭐ Case (кейс)
5. 💡 Tip (совет)
6. 🖼 Banner (баннер)

Для какой платформы? Telegram / Instagram / LinkedIn / все"
```

### Phase 2: Generate

```bash
export WD=/workspace/group/post-designs/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
```

Use Nano Banana API (same as carousel skill):
```bash
RESULT=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-3.1-flash-image-preview","messages":[{"role":"user","content":"<PROMPT>"}]}')

echo "$RESULT" | node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const img=JSON.parse(d).choices?.[0]?.message?.images?.[0];
  if(img?.image_url?.url){
    const b64=img.image_url.url.replace(/^data:image\/\w+;base64,/,'');
    require('fs').writeFileSync('$WD/post.png',Buffer.from(b64,'base64'));
    console.log('Saved');
  }else{console.log('No image');}
})"
```

### Phase 3: Platform Adaptation

Generate variants if posting to multiple platforms:
- **Instagram:** 1080x1080 (square)
- **Telegram:** 1080x1080 or 1280x720 (landscape fits better in chat)
- **LinkedIn:** 1200x627 (landscape, professional)
- **Facebook:** 1200x630 (landscape)

### Phase 4: Send & Publish

Send via `send_file`. Offer zernio-publisher for cross-platform posting.

## Brand Defaults

Same as carousel skill. Read from wiki if available.
- Primary: #1a237e (deep blue)
- Accent: #ff6f00 (amber)
- Dark BG: #0d1117
- Light BG: #ffffff

## Cost

~$0.003 per image. Batch of 5 formats: ~$0.015.
