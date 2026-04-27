# Entities

Названные организации, продукты, места, инструменты, бренды, сервисы — конкретные вещи.

Примеры: `obsidian.md`, `anthropic.md`, `nanoclaw.md`, `octofunnel.md`, `tashkent.md`, `claude-code.md`.

Не люди (`people/`) и не идеи (`concepts/`).

## Filename

`kebab-case.md`. Если есть несколько entity с похожими именами — используй disambiguator: `apple-company.md` vs `apple-fruit.md`.

## Шаблон

```markdown
---
title: "<Название>"
type: entity
subtype: organization | product | place | tool | service | brand | event
created: YYYY-MM-DD
updated: YYYY-MM-DD
url: "<homepage if exists>"
location: "<for places>"
sources: ["[[sources/...]]"]
related:
  - "[[people/founder-or-key-person]]"
  - "[[concepts/related-concept]]"
  - "[[entities/competitor]]"
tags: []
confidence: high | medium | low
status: active | inactive | deprecated
---

# <Название>

## TL;DR (1 строка)

Что это такое — для будущего меня.

## Описание

Развёрнутое описание. Что делает, для кого, какие ключевые свойства.

## Контекст для меня

Почему я про это знаю. Связь с моей деятельностью. Был ли личный опыт использования.

## Ключевые факты

| Параметр | Значение |
|---|---|
| Founded | YYYY |
| Founders | [[people/...]] |
| Industry | ... |
| Stage | ... |

## История изменений

- YYYY-MM-DD — что-то изменилось

## Связи

- **Конкуренты / альтернативы:** [[entities/...]]
- **Использует:** [[entities/upstream-tool]]
- **Партнёры:** [[entities/...]]

## Open questions

> #PROBLEM — что я ещё не знаю / не уверен
```

## Версионирование (когда entity сильно меняется)

Если entity радикально меняется (rebrand, pivot, новая стратегия) — создай новую страницу `<entity>-v2.md` или раздел `## v2 (YYYY-MM-DD)` внутри. Старая версия остаётся как историческая запись с пометкой `status: deprecated, see [[<entity>-v2]]`.
