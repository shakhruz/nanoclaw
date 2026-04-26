---
name: design-hd-image
description: Generate high-definition images using Gemini 3 Pro Image Preview (Google's flagship image model) or GPT Image 2 (OpenAI, when OPENAI_API_KEY is set). Use for hero banners, landing covers, product mockups, complex compositions with prominent text, or whenever you need sharper quality than Nano Banana 2 (the fast default). When the task is a quick social-media post, use design-social-post instead — this skill is for when quality matters more than speed.
trigger: hd image | hero banner | landing hero | premium image | gemini 3 pro | gpt image | дизайн лендинга | герой воркшопа | обложка курса
---

# HD Image Designer

## 🔴 MANDATORY pre-flight #1 — AshotAI Brand Style

Перед ЛЮБОЙ генерацией визуала прочитай brand guide и применяй стиль:

```bash
cat /workspace/global/wiki/projects/octo/brand/ashotai-brand-style.md
```

Кратко (Стив Джобс / Дитер Рамс «less but better»):
- **Фон:** `#000000` или `#0A0A0A` (чёрный)
- **Акцент:** ОДИН цвет — `#C9A84C` (gold). Не использовать два акцента.
- **Текст:** Inter / SF Pro Display, bold, заголовки 3-6 слов
- **Композиция:** ОДИН главный элемент, 80% whitespace, не «забивать» макет
- **Запрещено:** градиенты (кроме тонких тёмных), яркие неоновые цвета, синий как основной, выравнивание длинного текста по центру

Применяй ВО ВСЕХ prompt'ах независимо от типа артефакта (hero, обложка, баннер). Если для конкретного workshop-типа есть адаптация — она в guide в таблице "Адаптации по типу воркшопа".

После генерации — проверь по brand-checklist (тоже в guide).

## 🔴 MANDATORY pre-flight #2 (если в задаче есть конкретный человек)

Если генерируешь изображение с лицом Шахруза, клиента или партнёра — **обязательно** следуй face-reference protocol. Без него модель сгенерит случайного похожего человека (это та самая проблема почему так делать нельзя).

```bash
# 1. Проверь каталог
cat /workspace/global/assets/faces/README.md

# 2. Выбери фото под задачу (см. README — какое для hero, какое для рекламы)
# 3. Передавай как inline_data reference (примеры curl см. ниже в Phase 3+ или в protocol)
# 4. После генерации — vision verification (Phase 5)
```

Полный протокол с готовыми curl-командами + GPT Image 2 примерами + Vision verification: `[[architecture/face-reference-protocol]]`.

Если фото нужного человека НЕТ в каталоге — СТОП. Спроси Шахруза или сообщи в чат «нужно фото <person>». **НЕ генерируй с придуманным лицом.**

---

Premium image generation for cases where Nano Banana 2's output isn't sharp enough: hero landing banners, workshop covers, product mockups, long-form text on image, complex multi-element compositions.

## When to use this skill vs alternatives

| Use-case | Preferred skill | Why |
|---|---|---|
| Telegram/Instagram post, carousel slide, regular thumbnail | `design-social-post`, `design-instagram-carousel`, `design-youtube-thumbnail` | Nano Banana is fast, cheap, good enough |
| Workshop hero banner, landing-page cover, PDF lead-magnet cover | **this skill** | Gemini 3 Pro handles crisp typography + complex scenes |
| Avatar (personal or bot) | `design-avatar` | That skill has face-reference + 3-variant flow |
| Livestream YouTube thumbnail | `livestream-thumbnail` | That skill extracts real face from video |

## Prerequisites

- `$OPENROUTER_API_KEY` — for Gemini 3 Pro Image Preview (default)
- `$OPENAI_API_KEY` — optional, for GPT Image 2 (OpenAI's flagship; use when text-in-image is the dominant feature)

Both keys live in `/workspace/project/.env` on the host; inside containers they're injected via OneCLI.

## Phase 1: Pick model

Default: **Gemini 3 Pro Image Preview** (`google/gemini-3-pro-image-preview` via OpenRouter). 1024×1024 native, ~15s/generation, handles Cyrillic + Latin well, superior composition vs Nano Banana 2.

Switch to **GPT Image 2** (`gpt-image-1` via OpenAI direct) only when:
- Task demands prominent paragraph-level text ON the image
- Graphics have both Cyrillic AND Latin on same design
- Layout has multiple distinct zones (header + hero + CTA + footer)

If `$OPENAI_API_KEY` is not set, fall through to Gemini 3 Pro regardless.

## Phase 2: Draft prompt

Include these in every prompt (quality-critical):

1. **Dimensions + aspect.** "1024×1024 square" / "1280×720 landscape" / "1080×1920 portrait"
2. **Layout zones.** "Top third: headline text. Middle: hero visual. Bottom: CTA button."
3. **Exact text** (for text-in-image). Wrap in quotes: `Headline: "Личный бренд для предпринимателя"`. Include font-style hint: "bold condensed sans-serif".
4. **Brand colors.** AshotAI palette: `#1a237e` (кобальт), `#ff6f00` (амбер), `#0d1117` (тёмный). Rotate based on mood.
5. **Photography/illustration hint.** "Photorealistic product shot" / "Flat vector illustration" / "3D render" — pick ONE style, don't mix.
6. **Negative hint.** "No lorem ipsum. No watermarks. No stock-photo look. No placeholder icons."

## Phase 3: Generate (Gemini 3 Pro path)

```bash
export WD=/workspace/group/post-designs/$(date +%Y%m%d-%H%M%S)
mkdir -p $WD

PROMPT='<YOUR CONSTRUCTED PROMPT HERE>'

RESP=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(node -e "console.log(JSON.stringify({model:'google/gemini-3-pro-image-preview',messages:[{role:'user',content:process.argv[1]}]}))" "$PROMPT")")

echo "$RESP" | python3 -c "
import json, base64, sys
j=json.load(sys.stdin)
if 'error' in j: print('ERROR:', j['error']); sys.exit(1)
img=j['choices'][0]['message'].get('images', [])
if not img: print('no image'); sys.exit(1)
url=img[0]['image_url']['url']
b64=url.split(',',1)[1] if ',' in url else url
open('$WD/hd.png','wb').write(base64.b64decode(b64))
print('$WD/hd.png')
"
```

## Phase 4: Generate (GPT Image 2 path — optional)

Only runs if `$OPENAI_API_KEY` is set. OpenAI's Images API returns base64 (if `response_format=b64_json`):

```bash
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(node -e "console.log(JSON.stringify({model:'gpt-image-1',prompt:process.argv[1],n:1,size:'1024x1024',response_format:'b64_json'}))" "$PROMPT")" \
  | python3 -c "
import json, base64, sys
j=json.load(sys.stdin)
if 'error' in j: print('ERROR:', j['error']); sys.exit(1)
b64=j['data'][0]['b64_json']
open('$WD/hd.png','wb').write(base64.b64decode(b64))
print('$WD/hd.png')
"
```

## Phase 5: Review + iterate

After first generation, *you* evaluate against:

- Matches brief's brand colors?
- Text readable (no blurred/garbled letters)?
- Layout zones preserved?
- Style consistent (no mixed realism+illustration)?

If ≥1 fail → regenerate with tightened prompt. Max 3 iterations before escalating to human.

## Phase 6: Send to user — INLINE в чат, НЕ через milagpt.cc

**Default (ПРАВИЛЬНО):** отправь файл прямо в чат как inline image — Шахруз видит preview мгновенно:

```bash
mcp__nanoclaw__send_message(
  text="Hero готов — посмотри",
  files=["$WD/hd.png"],
  sender="Дизайнер"  # если в swarm
)
```

PNG/JPG автоматически приходят как inline-image preview в Telegram. См. `[[architecture/sub-agents#21--доставка-файлов]]` для полного правила.

**АНТИ-паттерн (раньше делали — НЕ ДЕЛАТЬ):**
- ❌ `send_message(text="Hero готов: $WD/hd.png")` — Шахруз получит только путь к файлу, не картинку
- ❌ Сразу публиковать через `web-asset-upload` — 30-60 сек ожидания + риск Vercel error + лишний URL

**Когда ВСЕ-ТАКИ web-publish:** только если сам Шахруз скажет "опубликуй на сайте" или это для клиента (используй `web-client-doc`).

If you're a pool-bot agent in a swarm (Дизайнер), ALSO save path to workshop's `design/` dir for persistent reference:

```bash
SLUG=$(basename $(dirname "$WD"))  # or pass explicitly
cp $WD/hd.png /workspace/global/workshops/<slug>/design/hero.png
```

## Anti-patterns

- ❌ Using this skill for social posts → use `design-social-post`, it's tuned for platform sizes and uses Nano Banana (cheaper/faster).
- ❌ Skipping Phase 5 review — Gemini 3 Pro occasionally hallucinates text. Always check.
- ❌ Regenerating with the exact same prompt — if first attempt is off, *rewrite* the prompt with more specificity, don't just re-roll.
- ❌ Hard-coding workshop slug — read it from env/brief, keep skill reusable.
