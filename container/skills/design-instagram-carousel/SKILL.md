---
name: design-instagram-carousel
description: Generate viral Instagram carousel slides using Nano Banana (Google Gemini image generation). 7 viral formats optimized for engagement, shares, and conversion to Telegram reality show and ashotai.uz workshop. Use when asked to create a carousel, Instagram post design, or content for social media.
---

# Instagram Carousel Designer — Viral & Converting

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

### 1. STORY — Сторителлинг (конверсия + вирусность)
**Когда:** личная история, путь к результату, трансформация
```
Slide 1: HOOK — шокирующий факт/цифра крупно ("Я потерял $5000 на первой воронке")
Slide 2-3: Проблема/контекст ("Вот что было не так...")
Slide 4-6: Путь решения (шаги, инсайты)  
Slide 7-8: Результат + proof (цифры, скриншоты)
Slide 9: Social proof (отзыв/кейс)
Slide 10: CTA → "Подробнее в реалити — ссылка в bio"
```

### 2. LISTICLE — Список (shares + saves)
**Когда:** советы, ошибки, инструменты, причины
```
Slide 1: "5 ошибок которые убивают твой онлайн-бизнес" (число + провокация)
Slide 2-6: По одной ошибке (номер крупно + объяснение)
Slide 7: Бонус/инсайт
Slide 8: CTA → "Бесплатный воркшоп → ashotai.uz"
```

### 3. BEFORE_AFTER — Трансформация (engagement)
**Когда:** результат клиента, сравнение подходов
```
Slide 1: "До" (проблема визуально)
Slide 2-3: Процесс/действие
Slide 4: "После" (результат визуально)
Slide 5: Цифры трансформации
Slide 6: CTA → "Хочешь так же? Напиши 'воронка' в DM"
```

### 4. MYTHS — Разрушение мифов (вирусность через дискуссию)
**Когда:** опровержение заблуждений, провокация
```
Slide 1: "3 мифа которые мешают тебе зарабатывать в интернете"
Slide 2-3: Миф 1 → Реальность (перечёркнутый текст → правда)
Slide 4-5: Миф 2 → Реальность
Slide 6-7: Миф 3 → Реальность
Slide 8: CTA → "Узнай правду на воркшопе"
```

### 5. STEPS — Пошаговая инструкция (saves + shares)
**Когда:** how-to, гайд, процесс
```
Slide 1: "Как создать воронку с ИИ за 30 минут" (обещание)
Slide 2: Шаг 1 (с визуалом)
Slide 3: Шаг 2
Slide 4: Шаг 3
Slide 5-6: Шаги 4-5
Slide 7: Результат
Slide 8: CTA → "Попробуй на воркшопе — бесплатно"
```

### 6. DATA — Шокирующие цифры (вирусность через wow-эффект)
**Когда:** статистика, кейсы, рыночные данные
```
Slide 1: Огромная цифра крупно ("$2.6 МЛРД за 3 года")
Slide 2: Контекст цифры
Slide 3-4: Разбивка (как это получилось)
Slide 5: "А вот что это значит для тебя"
Slide 6: CTA → конкретный путь к такому результату
```

### 7. CASE — Кейс клиента (social proof + конверсия)
**Когда:** реальный результат клиента
```
Slide 1: Фото клиента + "$X за Y дней"
Slide 2: Кто этот человек (before)
Slide 3: Что сделали (процесс)
Slide 4: Результат (цифры)
Slide 5: Цитата клиента
Slide 6: CTA → "Следующим можешь быть ты"
```

## Workflow

### Phase 0: Choose Format & Topic

Ask user or decide based on topic:
```
"Какой формат карусели?
1. 📖 Story (сторителлинг)
2. 📋 List (5 советов/ошибок)
3. 🔄 Before/After (трансформация)
4. 💥 Myths (разрушение мифов)
5. 📝 Steps (пошаговая инструкция)
6. 📊 Data (шокирующие цифры)
7. ⭐ Case (кейс клиента)

Или опиши тему — я подберу лучший формат."
```

### Phase 1: Generate Slide Texts

Based on format, write text for EACH slide:
- Title (max 8 words, крупный)
- Subtitle (max 15 words, мельче)
- Slide number (1/N)
- CTA text (last slide)

Show all texts to user for approval before generating images.

### Phase 2: Generate Images

For each slide, call Nano Banana:

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

IMPORTANT: 
- Text must be in Russian
- Text must be CLEARLY readable — large font, high contrast
- Keep design minimal — focus on the message
- Add subtle "→" swipe indicator at right edge
```

Wait 3-5 seconds between generations to avoid rate limits.

### Phase 3: Send to User

Send all slides via `send_file`:
```
"Карусель готова! Формат: [format], [N] слайдов"
```
Send each slide as photo with caption "Слайд N/TOTAL: [title]"

### Phase 4: Revisions

If user requests changes:
- "Измени цвет на синий" → regenerate specific slide
- "Перепиши текст на слайде 3" → update text, regenerate
- "Добавь моё фото на первый слайд" → use photo from media catalog as input

For editing with reference image:
```json
{"messages":[{"role":"user","content":[
  {"type":"image_url","image_url":{"url":"data:image/png;base64,<EXISTING_SLIDE>"}},
  {"type":"text","text":"Edit this Instagram slide: change the background color to deep blue (#1a237e), keep everything else the same."}
]}]}
```

### Phase 5: Publish (optional)

Offer to publish via zernio-publisher:
"Опубликовать карусель в Instagram? Могу добавить caption с хештегами."

Generate caption with hashtags:
```
[Hook line from slide 1]

[2-3 sentences expanding on the topic]

Подробнее → ссылка в bio 👆

#ии #бизнесонлайн #автоворонка #заработоконлайн #маркетинг #octofunnel #aiбизнес
```

## Brand Defaults

If no colors specified, use:
- Primary: #1a237e (deep blue) — trust, technology
- Accent: #ff6f00 (amber/orange) — action, energy
- Background: #0d1117 (dark) or #ffffff (light)
- Text: white on dark, #1a237e on light

Read brand colors from wiki if available:
```bash
grep -i "color\|palette\|hex" /workspace/group/wiki/entities/shakhruz-ashot.md 2>/dev/null || echo "Using defaults"
```

## Viral Optimization Tips (embedded in generation)

- **Slide 1 = 80% of success.** If hook fails, nobody swipes. Use: numbers, provocation, curiosity gap, bold claim
- **Swipe motivation:** each slide must create curiosity for the next
- **Save-worthy:** actionable advice, frameworks, checklists → people save these
- **Share-worthy:** surprising data, relatable struggles, contrarian takes
- **CTA precision:** one clear action, not three. "Напиши 'воронка' в DM" > "подпишись и поставь лайк"
- **Text readability:** 3-second rule — if can't read in 3 sec, text is too long

## Cost

~$0.01-0.05 per carousel (8-10 image generations × ~$0.003 each).

## Error Handling

- **No image generated:** retry with simplified prompt
- **Text unreadable:** add "Make ALL text extra large, bold, high contrast" to prompt
- **Wrong aspect ratio:** specify "EXACTLY 1080x1080 pixels, square" in prompt
- **Russian text garbled:** try English text + note "Text language: Russian (Cyrillic)"
