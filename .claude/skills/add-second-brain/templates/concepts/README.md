# Concepts

Абстрактные идеи, темы, mental models. Не конкретные вещи (это `entities/`), не люди (`people/`), не активные дела (`projects/`).

Примеры: `llm-wiki-pattern`, `second-brain`, `flow-state`, `attention`, `compounding-knowledge`, `dwy-format` (Done With You).

## Filename

`kebab-case.md`. `attention.md`, `t-shaped-specialist.md`.

## Шаблон

```markdown
---
title: "<Концепт>"
type: concept
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: ["[[sources/...]]"]
related:
  - "[[concepts/related-concept]]"
  - "[[entities/example-entity]]"
  - "[[people/who-promotes]]"
tags: []
confidence: high | medium | low
---

# <Концепт>

## Суть (1-2 строки)

Что это такое — для будущего меня, который забыл.

## Почему важно

Контекст: где встречается, какой проблемой объясняется, что меняет.

## Происхождение / источники

Откуда взялось. Кто автор. Какие материалы лучше всего объясняют.

## Связи

- **Похожие концепты:** [[concepts/...]]
- **Противоположные:** [[concepts/...]]
- **Применение:** [[entities/...]] / [[projects/...]]

## Применимость

Где я могу использовать это в своей работе/жизни.

## Открытые вопросы

> #PROBLEM — что я ещё не понимаю про это
```

## Когда создавать

- При ingest источника, который вводит новый концепт — даже если стаб с одной строкой
- Когда `[[concepts/X]]` встречается в других страницах, а самой страницы нет (broken-link) — создай стаб

## Stub > broken link

Лучше одна строка с `confidence: low` чем dangling reference. Lint потом подсветит "stub слишком маленький — пора расширять".
