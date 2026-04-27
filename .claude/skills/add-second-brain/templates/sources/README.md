# Sources — Source Summaries

Один summary-файл на каждый ingested источник. Это *Layer 2* отображение Layer 1 (raw sources на `/workspace/group/sources/`).

## Filename convention

`YYYY-MM-DD-<short-slug>.md`

Примеры: `2026-04-21-karpathy-llm-wiki-pattern.md`, `2026-04-21-voice-onboarding-call.md`, `2026-04-21-pdf-anthropic-economic-index.md`

## Шаблон

```markdown
---
title: "<Заголовок источника>"
type: source-summary
created: YYYY-MM-DD
updated: YYYY-MM-DD
source_url: "<URL or N/A>"
source_files: ["/workspace/group/sources/YYYY-MM-DD-name.ext"]
source_type: article | pdf | voice | video | image | webpage | conversation | book
duration: "<for media — minutes>"
related:
  - "[[concepts/...]]"
  - "[[entities/...]]"
  - "[[people/...]]"
tags: []
confidence: high | medium | low
---

# <Заголовок>

## TL;DR (3-5 строк)

Главное, что нужно знать. Без этого summary бесполезен.

## Структурированный summary

Разделы по логике источника. Цитаты в кавычках с указанием стр./минуты.

## Ключевые claims

- Claim 1 (с ссылкой на источник внутри)
- Claim 2

## Insights

> #INSIGHT — нетривиальные выводы для меня лично

## Затронутые wiki pages

- `[[concepts/...]]` — добавлено что
- `[[entities/...]]` — обновлено что
- `[[people/...]]` — обновлено что

## Контрадикции (если есть)

Если этот источник противоречит другим — фиксируй здесь, плюс отметь в обеих сторонах с `confidence: medium`.

## Vote

> Стоит ли возвращаться: high / medium / low — почему
```

## Media-стubs (audio/video/binary)

Для голосовых, видео, больших PDF — binary в git **не идёт** (см. `.gitignore`). Создавай только source-summary `.md` с metadata + локальный путь:

```markdown
---
type: source-summary
source_type: voice
source_files: ["/local/path/to/recording.m4a"]  # local-only, not in git
duration: "26 min"
transcript_via: "Deepgram Nova-2"
...
---

# Voice — <тема>

## Transcript

<полный transcript>

## TL;DR + дальше как обычный source-summary
```

## NEVER

- Не клади сюда binary файлы (>1MB media) — они в `.gitignore`
- Не дублируй текст source если он уже на диске в `/workspace/group/sources/<name>` — ссылайся через `source_files`
- Не клади секреты (даже из расшифровки звонка с обсуждением паролей)
