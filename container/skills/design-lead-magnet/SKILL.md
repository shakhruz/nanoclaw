---
name: design-lead-magnet
description: Generate a branded PDF lead-magnet (checklist, template, one-pager, workbook) from structured content. Combines a cover image (design-hd-image) + HTML-styled inner pages rendered to PDF via headless Chromium. Output is a single PDF in the workshop's lead-magnets/ folder. Use after structure.md (Методолог) and copy.md (Копирайтер) are ready in Wave 2.
trigger: lead magnet | чеклист | one-pager | template PDF | рабочая тетрадь | лид магнит PDF
---

# Lead Magnet PDF Designer

## 🔴 MANDATORY pre-flight #0 — AshotAI Brand Style

Перед генерацией cover И стилизацией HTML-шаблона inner-страниц прочитай brand guide:

```bash
cat /workspace/global/wiki/projects/octo/brand/ashotai-brand-style.md
```

Применяй ВЕЗДЕ:
- **Cover:** чёрный фон, gold акцент `#C9A84C`, заголовок 3-6 слов, ОДИН главный элемент, 80% whitespace. **Не** «классическая обложка книги» — premium-минимализм a la Apple.
- **Inner pages HTML/CSS:** замени дефолтную палитру на чёрно-белый-золотой. Body text — Inter Regular на тёмном фоне. Чеклист-боксы — `#C9A84C` outline вместо оранжевых.
- **PDF style:** не «толстая книга» — лёгкий, дышащий layout.

Если в Phase 4 обнаружишь что HTML/CSS шаблоны в этом скилле всё ещё в старом стиле (амбер `#ff6f00`, белый фон, ul.checklist с оранжевыми ☐) — спроси Шахруза разрешения переписать CSS под новый brand. Не переделывай молча.

## 🔴 MANDATORY pre-flight #1 — face reference (если на cover есть Шахруз/клиент)

Cover часто содержит лицо эксперта. Обязательно: `[[architecture/face-reference-protocol]]`. Без reference Gemini/GPT Image 2 нарисуют чужое лицо — выглядит непрофессионально на лид-магните.

```bash
cat /workspace/global/assets/faces/README.md   # обычно shakhruz-A2-suit для premium PDF
```

## 🔴 MANDATORY pre-flight #2 — выбор type (главная причина «толстой книги» вчера)

**Типичная ошибка: выбрать `workbook` для простого 7-шагового чеклиста** — получается толстая книга которая не соответствует ожиданиям пользователя ("чеклист, не курс"). Это та проблема которую вчера фиксили.

### Decision matrix — какой type выбирать

| Содержание | Сколько строк | Подходящий type | Pages |
|---|---|---|---|
| Простой список действий («7 шагов», «10 правил») | 5-10 пунктов | **`checklist`** | 1-2 |
| Один концептуальный месседж + CTA | 1 страница | **`one-pager`** | 1 |
| Шаблон для заполнения (контент-план, стратегия в форме) | 2-3 раздела | **`template`** | 2-3 |
| Полноценный курс/тренинг с упражнениями | 4-6 разделов | **`workbook`** | 4-6 |

**Правило большого пальца:** если контент влезает в 1 экран — это `checklist` или `one-pager`. Если есть упражнения с местом для записи — `template`. Только если это **реальный многодневный курс** с разделами по дням — `workbook`.

### Anti-patterns (проверяй перед запуском)

- ❌ «Чеклист 7 шагов» → НЕ `workbook`. Это 1-2 страницы максимум, type=`checklist`.
- ❌ «Шаблон контент-плана» → НЕ `workbook`. Это `template`.
- ❌ Многостраничный PDF из-за того что `workbook` дефолт. Дефолта нет — выбирай по матрице.
- ❌ Размер обложки несоответствующий типу: для checklist — флэт минималист, не «обложка тома». Cover prompt должен включать «cover for short PDF guide» а не «cover for book».

### Если сомневаешься в выборе

Сообщи в чат: «не уверена какой формат — checklist или template — для задачи <X>. Как ты видишь: 1-2 страницы или 2-3 с полями?» Жди ответа Шахруза, не предполагай.

---

Produces a branded PDF lead-magnet: cover page + 2-6 content pages styled to AshotAI palette. Primary use: workshop giveaways ("Чеклист: 7 шагов к личному бренду за 30 дней" or "Шаблон: контент-план на месяц").

## When to use

- You have a workshop brief + structure + copy ready in `/workspace/global/workshops/<slug>/`
- You need a PDF deliverable that attendees download on registration
- Standalone usage: generate a one-off PDF for any campaign (pass content as args, skip workshop slug)

For just the cover image (no PDF), use `design-hd-image`. For multi-PDF package (cover + multiple inner magnets), run this skill multiple times with different `--type`.

## Prerequisites

- `$OPENROUTER_API_KEY` or `$OPENAI_API_KEY` — for cover image
- Container has `chromium` installed — we use `chromium --headless --print-to-pdf` for HTML→PDF
- Optional: inner-page content as markdown file or inline string

## Supported types

| Type | Structure | Pages |
|---|---|---|
| `checklist` | Headline → 5-10 checkbox items with 1-line explanation each | 1-2 content pages |
| `template` | Headline → fill-in blocks (tables, empty fields) with section headers | 2-3 content pages |
| `one-pager` | Headline → problem → solution → benefits → CTA on single page | 1 content page |
| `workbook` | Headline → exercises with writing space, section-divider pages | 4-6 content pages |

## Phase 1: Inputs

```bash
SLUG="${1:?usage: design-lead-magnet.sh <slug> <type> <title> [content_md_path]}"
TYPE="${2:?type: checklist|template|one-pager|workbook}"
TITLE="${3:?title}"
CONTENT_PATH="${4:-}"  # optional markdown file; if empty, you generate content in-memory
OUT="/workspace/global/workshops/$SLUG/lead-magnets"
mkdir -p "$OUT"
SAFE_TITLE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zа-я0-9]/-/g' | tr -s '-')
PDF="$OUT/${TYPE}-${SAFE_TITLE}.pdf"
COVER="$OUT/${TYPE}-${SAFE_TITLE}-cover.png"
```

Content for inner pages: either read from `$CONTENT_PATH` if supplied (markdown), or construct in your scratchpad from brief.md + structure.md + copy.md.

## Phase 2: Generate cover image (design-hd-image pattern)

850×1100 portrait cover. Use Gemini 3 Pro or GPT Image 2 via the same curl pattern as in `design-hd-image`. Key prompt fields:

- Title text (EXACT, top-center)
- Subtitle: "Чеклист для воркшопа "<workshop_title>"" (or template/one-pager)
- Background: vertical gradient #1a237e → #0d1117 with #ff6f00 accent
- Bottom-center: small AshotAI signature (optional logo)

Save to `$COVER`.

## Phase 3: Build HTML for inner pages

Use this template (inline in the skill, or as `inner-template.html`):

```html
<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><title>__TITLE__</title>
<style>
  @page { size: A4; margin: 20mm 18mm; }
  body { font-family: -apple-system, 'Inter', 'Segoe UI', sans-serif; color: #0d1117; line-height: 1.55; }
  h1 { color: #1a237e; font-size: 28pt; margin: 0 0 6pt; border-bottom: 3px solid #ff6f00; padding-bottom: 6pt; }
  h2 { color: #1a237e; font-size: 16pt; margin: 18pt 0 6pt; }
  h3 { color: #0d1117; font-size: 12pt; margin: 10pt 0 4pt; }
  ul.checklist { list-style: none; padding: 0; }
  ul.checklist li { margin: 10pt 0; padding-left: 22pt; position: relative; }
  ul.checklist li::before { content: "☐"; position: absolute; left: 0; color: #ff6f00; font-size: 16pt; line-height: 1; }
  .box { border: 1.5px solid #1a237e; border-radius: 4pt; padding: 12pt; margin: 14pt 0; }
  .fill-in { border-bottom: 1px solid #666; display: inline-block; min-width: 200pt; min-height: 20pt; }
  .cta { background: #1a237e; color: white; padding: 14pt 20pt; border-radius: 4pt; text-align: center; margin: 20pt 0; font-weight: bold; }
  .cta a { color: white; text-decoration: none; }
  .footer { position: fixed; bottom: 6mm; left: 18mm; right: 18mm; font-size: 8pt; color: #666; text-align: center; }
  .pagebreak { page-break-after: always; }
</style></head><body>
<div class="footer">ashotai.uz · AI Business Club · __SLUG__</div>
__CONTENT__
</body></html>
```

Per-type content rendering:

- **checklist** → `<ul class="checklist"><li>...</li></ul>` with each item becoming `<strong>Item headline</strong><br/><span>1-line explanation</span>`
- **template** → `<h2>` section headers + `<div class="box">` with `<span class="fill-in"></span>` slots
- **one-pager** → 4 sections: Проблема / Решение / Выгоды / CTA, each a short paragraph
- **workbook** → same as template but with more space per field + page breaks between sections

Write assembled HTML to temp file.

## Phase 4: Render PDF via headless Chromium

```bash
TMP_HTML=$(mktemp --suffix=.html)
# ... write HTML to $TMP_HTML ...

chromium --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" \
  --print-to-pdf-no-header \
  --virtual-time-budget=5000 \
  "file://$TMP_HTML"

rm "$TMP_HTML"
ls -la "$PDF"  # verify size > 0
```

If you want the cover image embedded as the first page: generate a separate 1-page HTML with `<img src="file:///$COVER" style="width:100%;height:100vh;object-fit:cover">` and a `<div class="pagebreak"></div>`, then append your inner HTML. Chromium prints both pages sequentially.

## Phase 5: Report to chat

```
✓ Lead-magnet готов: <type> — "<title>"
Файл: /workspace/global/workshops/<slug>/lead-magnets/<type>-<slug>.pdf
Страниц: N | Размер: X KB
```

Also update `/workspace/global/workshops/<slug>/README.md` with a link to the new PDF.

## Phase 6 (optional): Preview

Export the PDF to first-page PNG for quick visual review:

```bash
chromium --headless --disable-gpu --no-sandbox \
  --screenshot="${PDF%.pdf}-preview.png" \
  --window-size=850,1100 \
  "file://$TMP_HTML"
```

Send preview image to Шахруз before finalising if lead-magnet is customer-facing.

## Anti-patterns

- ❌ Generating a lead-magnet without reading structure.md + copy.md — content will be disconnected from the workshop.
- ❌ Hard-coding workshop-specific copy inside this skill — keep skill reusable; content comes from brief/copy artefacts.
- ❌ Skipping the `@page` CSS rule — Chromium will use its ugly default margins.
- ❌ Using `<h1>` multiple times per page — screen readers and PDF TOCs hate it; use one h1 per page/section, h2/h3 below.
- ❌ Including interactive elements (buttons, forms) — PDF is static, they won't work.
