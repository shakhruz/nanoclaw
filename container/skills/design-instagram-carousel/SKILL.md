---
name: design-instagram-carousel
description: Generate viral Instagram carousel slides using Nano Banana (Google Gemini image generation). 7 viral formats optimized for engagement, shares, and conversion to Telegram reality show and ashotai.uz workshop. Use when asked to create a carousel, Instagram post design, or content for social media.
---

# Instagram Carousel Designer — Viral & Converting

## 🔴 MANDATORY pre-flight (если на слайдах есть Шахруз / клиент / партнёр)

Карусели часто содержат фото эксперта (intro slide, об авторе). **Обязательно** используй face-reference protocol:

```bash
cat /workspace/global/assets/faces/README.md   # выбери фото — обычно shakhruz-A1-studio для intro
# передавай как inline_data в curl к Nano Banana / Gemini 3 Pro
```

Полный протокол: `[[architecture/face-reference-protocol]]`.

Без него — на каждом слайде будет РАЗНОЕ лицо (Nano Banana не сохраняет персонажа между генерациями). Реальный Шахруз — только через reference.

Vision verification после каждого слайда с лицом — обязательна.

---

Generate Instagram carousels optimized for organic reach and conversion. Each carousel drives traffic to the "$5000/мес reality" Telegram channel or the free workshop at ashotai.uz.

## Prerequisites

- `$OPENROUTER_API_KEY` — for Nano Banana image generation

## Trigger

- "создай карусель", "карусель для инстаграм"
- "дизайн поста", "Instagram carousel"
- "контент для инстаграм"

## Image Generation API

**Model:** `google/gemini-3.1-flash-image-preview` (Nano Banana 2 — fastest, Pro-level quality)

```bash
RESULT=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-3.1-flash-image-preview","messages":[{"role":"user","content":"<PROMPT>"}]}')

# Extract base64 image and save to file
echo "$RESULT" | node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const img=JSON.parse(d).choices?.[0]?.message?.images?.[0];
  if(img?.image_url?.url){
    const b64=img.image_url.url.replace(/^data:image\/\w+;base64,/,'');
    require('fs').writeFileSync('$WD/<FILENAME>.png',Buffer.from(b64,'base64'));
    console.log('Saved: <FILENAME>.png');
  }else{console.log('No image generated');}
})"
```

## 7 Viral Carousel Formats

Each format follows: Hook slide -> Body slides -> CTA slide. CTA always drives to Telegram channel, ashotai.uz, or DM action.

| # | Format | When to use | Structure |
|---|--------|-------------|-----------|
| 1 | **STORY** (сторителлинг) | Personal story, transformation | Hook fact/number -> Problem -> Solution steps -> Result + proof -> Social proof -> CTA |
| 2 | **LISTICLE** (список) | Tips, mistakes, tools | Number + provocation -> One item per slide -> Bonus -> CTA |
| 3 | **BEFORE_AFTER** (трансформация) | Client results, approach comparison | "До" visual -> Process -> "После" visual -> Numbers -> CTA |
| 4 | **MYTHS** (разрушение мифов) | Debunking, provocation | Title -> Myth+Reality pairs (strikethrough -> truth) -> CTA |
| 5 | **STEPS** (инструкция) | How-to, guide, process | Promise -> Step-per-slide with visuals -> Result -> CTA |
| 6 | **DATA** (цифры) | Statistics, cases, market data | Big number -> Context -> Breakdown -> "What it means for you" -> CTA |
| 7 | **CASE** (кейс клиента) | Real client results | Client photo + "$X за Y дней" -> Who (before) -> Process -> Result -> Quote -> CTA |

## Workflow

### Phase 0: Choose Format & Topic

Ask user or decide based on topic. Present the 7 formats or auto-select from the topic description.

### Phase 1: Generate Slide Texts

For each slide write: Title (max 8 words), Subtitle (max 15 words), Slide number (N/TOTAL), CTA text (last slide). Show all texts to user for approval before generating images.

### Phase 2: Generate Images

```bash
export WD=/workspace/group/carousel-$(date +%Y%m%d-%H%M%S)
mkdir -p $WD
```

**Slide prompt template:**
```
Generate an Instagram carousel slide, 1080x1080 pixels, square format.

DESIGN:
- Background: [gradient from #hex1 to #hex2 | solid #hex | abstract pattern]
- Style: modern, clean, bold. Business/marketing aesthetic.
- Slide counter "[N]/[TOTAL]" in top-right corner, small, semi-transparent

TEXT ON THE IMAGE:
- Main title (large, bold, centered or left-aligned): "[TITLE]"
- Subtitle (below title, smaller): "[SUBTITLE]"
- [For last slide: CTA button shape at bottom with text "[CTA]"]

[For first slide: Add a professional photo-realistic element related to the topic]
[For last slide: Add arrow pointing down + "Ссылка в bio" text]

IMPORTANT: Text in Russian, CLEARLY readable (large font, high contrast), minimal design, subtle "→" swipe indicator at right edge.
```

Wait 3-5 seconds between generations to avoid rate limits.

### Phase 3: Send to User

Send all slides via `send_file` with caption "Слайд N/TOTAL: [title]". Prefix: "Карусель готова! Формат: [format], [N] слайдов"

### Phase 4: Revisions

Regenerate specific slides on request (color, text, layout changes). For editing with reference image, send existing slide as `image_url` base64 content block with edit instructions.

### Phase 5: Publish (optional)

Offer to publish via zernio-publisher with auto-generated caption + hashtags:
```
[Hook line from slide 1]
[2-3 sentences expanding on the topic]
Подробнее → ссылка в bio
#ии #бизнесонлайн #автоворонка #заработоконлайн #маркетинг #octofunnel #aiбизнес
```

## Brand Defaults

If no colors specified, use:
- Primary: #1a237e (deep blue) | Accent: #ff6f00 (amber/orange)
- Background: #0d1117 (dark) or #ffffff (light) | Text: white on dark, #1a237e on light

Read brand colors from wiki if available:
```bash
grep -i "color\|palette\|hex" /workspace/group/wiki/entities/shakhruz-ashot.md 2>/dev/null || echo "Using defaults"
```

## Viral Optimization Tips

- **Slide 1 = 80% of success.** Use numbers, provocation, curiosity gap, bold claims. If hook fails, nobody swipes.
- **Save/share-worthy:** actionable frameworks, surprising data, relatable struggles, contrarian takes.
- **CTA precision:** one clear action, not three. "Напиши 'воронка' в DM" > "подпишись и поставь лайк". Text must pass 3-second readability rule.

## Error Handling

- **No image / wrong output:** retry with simplified prompt; add "EXACTLY 1080x1080 pixels, square" and "Make ALL text extra large, bold, high contrast".
- **Russian text garbled:** try English text + note "Text language: Russian (Cyrillic)".
