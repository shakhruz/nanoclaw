# Projects

Активные проекты — то, над чем я работаю сейчас и что имеет отдельную нить событий, решений, артефактов.

Не "идеи на будущее" (это `concepts/` или `inbox.md`), не "ушло в прод и забыто" (это либо deprecated в `entities/` либо вообще удалить).

## Filename

`kebab-case.md`. Большие проекты — поддиректория с `index.md` внутри:

```
projects/
├── claude-cert-prep.md           # маленький, одна страница
├── nanoclaw-redesign/            # большой, sub-pages
│   ├── index.md
│   ├── decisions.md
│   ├── milestones.md
│   └── retro.md
```

## Шаблон

```markdown
---
title: "<Project name>"
type: project
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: active | paused | completed | abandoned
target_date: YYYY-MM-DD  # if has deadline
sources: ["[[sources/...]]"]
related:
  - "[[people/key-collaborator]]"
  - "[[entities/used-platform]]"
  - "[[concepts/applied-method]]"
tags: []
priority: high | medium | low
---

# <Project name>

## Цель

Что хочу получить в конце. Конкретно, измеримо.

## Why now

Контекст: почему сейчас, какая возможность / проблема.

## Текущий статус

Где я сейчас. Что сделано, что в работе.

## План

| Этап | Срок | Статус |
|---|---|---|
| 1. ... | YYYY-MM-DD | ✅ Done |
| 2. ... | YYYY-MM-DD | 🔄 In progress |
| 3. ... | YYYY-MM-DD | ⏳ Pending |

## Решения

> #DECISION YYYY-MM-DD — Решил X потому что Y. Альтернативы Z отвергнуты потому что W.

## Артефакты / ссылки

- [[sources/<related-source>]]
- GitHub: <repo url>
- Документ: <link>

## Блокеры

- [Active] X — нужно Y чтобы разблокировать
- [Resolved] Z — было блокером с DATE до DATE, решилось через W

## Открытые вопросы

> #PROBLEM — что не решено

## Retro (по завершении)

- Что получилось хорошо
- Что плохо
- Что бы сделал иначе
```

## Контрибуция от sub-агентов

Sub-агенты (channel-promoter, partner-recruitment, client-profiler) **могут создавать страницы в** `projects/<role>/` — например `projects/channel-promoter/ashotonline-growth-q2.md`. Curator не вмешивается в эту поддиректорию (только при явной просьбе).

## Когда status → completed

- Финальный артефакт сдан / запущен
- Retro секция написана
- Linkованные milestones отмечены

После status=completed: оставляем как есть в `projects/` ещё месяц-два (для свежего reference), потом можем переместить в `archive/projects/` (отдельная папка для старья если она появится).
