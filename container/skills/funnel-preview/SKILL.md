---
name: funnel-preview
description: Compile ALL workshop/funnel artefacts (баннеры, обложки, PDF lead-magnets, аудио уроки, тексты) into a single AshotAI-styled HTML preview page and publish to milagpt.cc/w/<slug>/. ATOMIC — все файлы в одном git commit + один Vercel deploy под flock. Для Mila octo при review воронок с тяжёлыми ассетами (>30MB) или audio. Use when finalizing a funnel and Шахрузу нужно одно URL чтобы посмотреть всё в браузере.
---

# Funnel Preview — single-page web review

Собирает все ассеты воронки в одну страницу с anchor-навигацией, публикует на milagpt.cc/w/<slug>/. Шахруз открывает один URL → видит всё (баннеры grid + PDF iframe + audio плееры + markdown context) → даёт обратную связь конкретно по элементам.

## Когда использовать

✅ **Подходит:**
- Воронка содержит >2 баннеров + PDF + audio уроки → не помещается в Telegram comfortable
- Финальное согласование собранной воронки перед запуском
- Контент для клиента (но secret URL — другой скилл `web-client-doc`)
- Total размер ассетов > 30MB (HTML inline overload)

❌ **НЕ подходит:**
- Один баннер / одна картинка → отправляй в чат как inline image (см. CLAUDE.md «Доставка файлов»)
- Один MP3 → audio attachment в чат
- Маленький draft / черновик 1-2 файла → inline в чат

## Trigger

«опубликуй preview воронки», «собери всё в одну страницу», «дай URL чтобы я увидел всё», «funnel review preview», «выведи воронку на сайт для согласования»

## Использование

```bash
bash /home/node/.claude/skills/funnel-preview/build-and-publish.sh <slug>
```

Где `<slug>` — это имя workshop folder в `/workspace/global/workshops/`.

Скрипт сам найдёт и встроит:
- `design/*.{png,jpg,jpeg,webp}` → секция «🖼 Изображения» (grid с превью)
- `lead-magnets/*.pdf` + `*-cover.png` → секция «📄 PDF» (iframe + download link)
- `audio/*.{mp3,m4a,ogg}` → секция «🔊 Аудио» (HTML5 плеер)
- `brief.md`, `copy.md`, `strategy.md`, `structure.md`, `methodology.md`, `targeting.md` → секции «📝 контекст» (collapsible)

## Output

JSON в stdout с URL и метаданными:

```json
{
  "url": "https://milagpt.cc/w/lichnyy-brend-2026-05-15/",
  "commit": "abc1234",
  "deployment": "https://milagpt-xxxxxx.vercel.app",
  "push": 1,
  "images": 5,
  "pdfs": 1,
  "audios": 3
}
```

Возьми `.url` и отправь Шахрузу:

```
mcp__nanoclaw__send_message(
  text="🔗 Preview воронки готов: https://milagpt.cc/w/<slug>/\n\nВнутри: 5 изображений, 1 PDF, 3 аудио. Открой и дай feedback.",
  sender="Воронщик"   # если дёргаешь из swarm
)
```

## Что внутри HTML preview

- **Brand-style** AshotAI: чёрный фон #0A0A0A, gold accent #C9A84C, Inter Bold
- **Anchor nav** — клик по «🖼 Изображения» / «📄 PDF» / «🔊 Аудио» прыгает к секции
- **Image grid** — все картинки в карточках с именами файлов
- **PDF embedded iframe** — Шахруз видит PDF без скачивания
- **HTML5 audio плеер** для каждого mp3
- **Markdown секции** в `<details>` (раскрываются по клику)
- **Lazy loading** — большие изображения грузятся по scroll

## Atomicity (важно!)

Скрипт держит `flock /tmp/milagpt-cc-publish.lock` всё время — pull, copy, commit, push, deploy в одной транзакции. Это устраняет race-conditions с другими `publish-*.sh` скриптами которые мы видели вчера (4 из 5 Vercel deploys падали).

## Update vs initial publish

Если воронка уже публиковалась — скрипт идемпотентен:
- Перезаписывает все ассеты в `~/apps/milagpt-cc/public/w/<slug>/`
- git diff — видит изменения
- Если файл идентичен — `unchanged:true`, deploy НЕ дёргается
- Если что-то поменялось — новый commit + deploy

То есть Mila может вызывать скрипт сколько угодно раз (после каждой итерации с Шахрузом) — лишних deploys не будет.

## Anti-patterns

❌ НЕ публиковать каждый файл воронки отдельно через `web-asset-upload` — это и создаёт race-condition. Используй `funnel-preview` для всей воронки за раз.

❌ НЕ забывать слать URL в чат — иначе Шахруз не узнает что страница готова.

❌ НЕ помещать в `/workspace/global/workshops/<slug>/` файлы которые НЕ должны быть на превью (черновики LLM, debug logs). Эти лежат в `notes/` или `_drafts/` подпапках которые скрипт игнорирует (он читает только в `design/`, `lead-magnets/`, `audio/` подпапки если искать по структуре).

## Workflow для Mila octo

```
1. Команда (Wave-проколом) собрала воронку:
   - Дизайнер → /workspace/global/workshops/<slug>/design/{hero.png, banner-tg.png, ...}
   - Копирайтер → copy.md, lead-magnets/*-script.md
   - Методолог → structure.md
   - Воронщик → audio/*.mp3 (если есть)
2. После всех Wave 2 deliverables:
   bash /home/node/.claude/skills/funnel-preview/build-and-publish.sh <slug>
3. Получишь URL — отправь Шахрузу в чат + перечисли что внутри
4. Шахруз даёт feedback → итерация → тот же команда → re-publish
```
