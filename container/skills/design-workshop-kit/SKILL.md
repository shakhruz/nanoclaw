---
name: design-workshop-kit
description: Composite design skill that generates the full visual pack for a workshop in one go — hero landing banner (1200×630), Telegram announce (1080×1080), Instagram announce (1080×1350), lead-magnet PDF cover (850×1100). Reads brief.md from the workshop folder and produces 4 PNGs in design/. Use when the Дизайнер pool-agent gets a workshop brief and needs all standard visuals. For one-off visuals use design-hd-image or design-social-post directly.
trigger: workshop kit | визуал пакет воркшопа | kit для воркшопа | все баннеры воркшопа | набор визуала
---

# Workshop Visual Kit

## 🔴 MANDATORY pre-flight #1 — AshotAI Brand Style + workshop adaptation

Перед генерацией ЛЮБОГО артефакта (hero/TG/IG/lead-magnet cover) прочитай brand guide:

```bash
cat /workspace/global/wiki/projects/octo/brand/ashotai-brand-style.md
```

Применяй: чёрный фон (`#000000` / `#0A0A0A`), один gold акцент (`#C9A84C`), Inter Bold, 80% whitespace, ОДИН главный элемент.

**Важно для workshop kit** — определи тип воркшопа из `brief.md` (personal brand / tech / sales / mindset / etc) и применяй соответствующую адаптацию из таблицы "Адаптации по типу воркшопа" в guide. Не просто базовый стиль — а его специфический вариант под тему.

После каждого артефакта — пройди brand-checklist (в конце guide).

## 🔴 MANDATORY pre-flight #2 (если на баннерах должен быть Шахруз / клиент / партнёр)

Hero, TG announce, IG announce — обычно содержат лицо. **Обязательно** используй face-reference protocol при генерации каждого артефакта.

```bash
cat /workspace/global/assets/faces/README.md   # выбери фото
# далее передавай как inline_data в каждом curl-запросе к Gemini/GPT Image 2
```

Полный протокол с готовыми curl-командами + Vision verification: `[[architecture/face-reference-protocol]]`.

Без него получишь 4 баннера с РАЗНЫМИ случайными людьми вместо Шахруза — это та проблема которую вчера фиксили (см. wiki). Если фото нет → СТОП, спроси Шахруза.

После каждого артефакта — vision verification.

---

Single entry-point for generating the full 4-artefact visual pack a workshop needs: landing hero + TG announce + IG announce + PDF lead-magnet cover. Orchestrates the right model per artefact so you don't have to decide each time.

## When to use

Triggered when Дизайнер (pool-agent in Mila octo swarm) is in Wave 2 of the workshop-design workflow and the brief is ready in `/workspace/global/workshops/<slug>/brief.md`. Instead of calling 4 different skills manually, this one pulls brief, generates all 4, saves them.

For standalone visuals (not tied to a workshop), use the underlying skills directly:
- `design-hd-image` — hero banners, premium quality
- `design-social-post` — Telegram/Instagram/LinkedIn posts

## Prerequisites

- `$OPENROUTER_API_KEY` — Gemini 3 Pro (hero, cover) + Nano Banana 2 (announces)
- Workshop brief at `/workspace/global/workshops/<slug>/brief.md` (from Маркетолог, Wave 1)
- Workshop slug (kebab-case, e.g. `lichnyy-brend-2026-05-15`)

## Phase 1: Read brief + extract design inputs

```bash
SLUG="${1:?usage: design-workshop-kit.sh <slug>}"
BRIEF="/workspace/global/workshops/$SLUG/brief.md"
OUT="/workspace/global/workshops/$SLUG/design"
mkdir -p "$OUT"
[ -f "$BRIEF" ] || { echo "brief not found: $BRIEF"; exit 1; }
```

Parse key fields yourself from brief.md — you're an agent, use Read+your judgement, don't write brittle grep. You need:

- **Workshop title** (e.g. "Личный бренд для предпринимателя с AI")
- **Date + time** (e.g. "15 мая 2026, 14:00 Ташкент")
- **Primary audience** (1-line — "предприниматели СНГ с опытом 3+ лет")
- **Mood** (derived from audience: formal / bold / warm / technical / playful)
- **3 key benefits** (for announce copy overlays)

Encode into one shared "style contract" JSON in your scratchpad — reused across all 4 generations:

```json
{
  "title": "Личный бренд для предпринимателя с AI",
  "date_label": "15 мая, 14:00 Ташкент",
  "audience": "предприниматели СНГ",
  "mood": "bold professional",
  "palette": ["#1a237e", "#ff6f00", "#0d1117"],
  "illustration_style": "flat vector with subtle 3D accents",
  "key_benefits_short": ["Запустишь бренд за 30 дней", "Воронка под твою нишу", "AI берёт рутину"]
}
```

## Phase 2: Generate 4 artefacts

Run these in sequence — don't parallelize inside one skill, the OpenRouter endpoint handles concurrency poorly from a single bash session.

### 2.1 Hero banner (1200×630, landing page) — Gemini 3 Pro

```bash
PROMPT_HERO='1200x630 landscape hero banner for a business workshop landing page.
Title text (EXACT, top-center bold): "<title>"
Subtitle (smaller, below title): "<date_label>, live"
Right side: isolated photorealistic/3D hero element suggesting "личный бренд + AI" (portrait silhouette + neural-net glow OR laptop with glowing aura). Clean composition with clear negative space on left for title.
Background: gradient from #1a237e to #0d1117 with subtle geometric accents in #ff6f00.
Style: <mood> <illustration_style>.
No lorem ipsum, no watermarks, no stock icons, no placeholder text.'

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d "$(node -e "console.log(JSON.stringify({model:'google/gemini-3-pro-image-preview',messages:[{role:'user',content:process.argv[1]}]}))" "$PROMPT_HERO")" \
  | python3 -c "
import json, base64, sys
j=json.load(sys.stdin)
if 'error' in j: print('ERR:',j['error']); sys.exit(1)
img=j['choices'][0]['message'].get('images',[])
if not img: print('no image'); sys.exit(1)
b64=img[0]['image_url']['url'].split(',',1)[1]
open('$OUT/hero.png','wb').write(base64.b64decode(b64))
print('ok hero')"
```

### 2.2 Telegram announce (1080×1080, square) — Nano Banana 2

Same pattern but with Nano Banana (`google/gemini-3.1-flash-image-preview`), square composition, benefits listed as 3 bullets on image. Save `$OUT/announce-tg.png`.

### 2.3 Instagram announce (1080×1350, portrait) — Nano Banana 2

Same content, portrait layout, Instagram-feed optimized. Save `$OUT/announce-ig.png`.

### 2.4 Lead-magnet PDF cover (850×1100, portrait) — Gemini 3 Pro

Cover for a branded PDF lead magnet. Title on top third, subtitle below, minimal illustration in middle. Save `$OUT/leadmag-cover.png`.

## Phase 3: Write design notes

Create `$OUT/README.md`:

```markdown
# Design pack — <workshop title>

Generated: <date>, model mix: Gemini 3 Pro + Nano Banana 2

| Artefact | File | Dimensions | Use |
|---|---|---|---|
| Hero | hero.png | 1200×630 | Landing page header |
| TG announce | announce-tg.png | 1080×1080 | Channel post + thumb |
| IG announce | announce-ig.png | 1080×1350 | IG feed post |
| PDF cover | leadmag-cover.png | 850×1100 | Lead-magnet first page |

Palette: #1a237e / #ff6f00 / #0d1117
Mood: <mood>
Style: <illustration_style>
```

## Phase 4: Report to chat

Pool-agent Дизайнер sends to Mila octo group:

```
✓ Визуал пакет готов (4 артефакта):
• hero.png (1200×630) для лендинга
• announce-tg.png и announce-ig.png для анонсов
• leadmag-cover.png для PDF

Папка: /workspace/global/workshops/<slug>/design/
Палитра и стиль — README.md там же.
```

## Phase 5 (optional): Review + iterate

If any artefact looks off (text blurred, wrong composition, off-brand colors) — regenerate JUST that one with tightened prompt. Don't re-run the whole kit.

Max iterations: 3 per artefact. Beyond that, escalate to human (Шахруз) with a short explanation of what keeps going wrong.

## Anti-patterns

- ❌ Running this skill when a workshop brief doesn't exist — you'll generate generic visuals with no context.
- ❌ Hard-coding title/palette inside the skill — always pull from brief + style contract.
- ❌ Skipping Phase 3 README — future agents and humans need to know what's in the folder.
- ❌ Calling this skill OUTSIDE a workshop context — use the underlying skills (`design-hd-image`, `design-social-post`) for one-offs.
