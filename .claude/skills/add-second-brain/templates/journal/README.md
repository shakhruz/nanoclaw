# Journal

Daily-entries формата `YYYY-MM-DD.md`. Создаются по запросу или автоматически в конце дня.

## Когда создавать

- Утром: пустой шаблон `YYYY-MM-DD.md` с разделами для intent/decisions/wins/blockers
- В течение дня: append событий, мыслей, контекста разговоров
- Вечером: `## [YYYY-MM-DD] reflect | daily — short summary` в `log.md`, плюс journal-entry с verbatim ключевых обменов

## Шаблон дня

```markdown
---
title: "Daily — YYYY-MM-DD"
type: journal
date: YYYY-MM-DD
created: YYYY-MM-DDTHH:MM:SS
updated: YYYY-MM-DDTHH:MM:SS
related: []
tags: []
---

# YYYY-MM-DD — <короткий summary дня>

## Intent (утро)

Что хочу сделать сегодня и почему.

## Activity

- HH:MM — <что произошло>
- HH:MM — <что произошло>

## Decisions

> #DECISION HH:MM — <что решил, почему>

## Wins / Blockers

✅ Wins:
- ...

❌ Blockers:
- ...

## Reflection (вечер)

Свободные мысли о дне.

## Связи

- [[projects/<active>]]
- [[people/<met>]]
```

## Зачем journal'ы

- **Контекст для morning brief** — Мила читает вчерашний journal, понимает где остановились
- **Источник для weekly review** — еженедельная сводка строится из 7 journal-файлов
- **Личная история** — через год можно вернуться к "что я думал в апреле 2026"
- **Граф связей** — каждая daily-entry линкуется в проекты/людей/решения, обогащая обратные связи

## Журнал ≠ inbox

- **Inbox** — короткие непереваренные мысли любого автора, дни не группируются
- **Journal** — структурированная дневная летопись, по одной странице на день, ведётся curator'ом
