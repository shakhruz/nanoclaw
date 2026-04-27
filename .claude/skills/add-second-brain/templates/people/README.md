# People

Люди. Один файл на человека. **Чувствительные данные — приватные, в публичный репо не идут** (вики на private remote, см. main `.gitignore`).

## Filename

`kebab-case.md` от имени-фамилии. `john-smith.md`, `anna-ivanova.md`. Латинизация для русских/узбекских имён через стандартную транслитерацию.

## Шаблон

```markdown
---
title: "<Имя Фамилия>"
type: person
created: YYYY-MM-DD
updated: YYYY-MM-DD
relationship: client | partner | mentor | friend | family | acquaintance | public-figure | colleague
context: "Краткий контекст: где познакомились, в какой роли"
last_seen: YYYY-MM-DD
contact:
  telegram: "@username"
  email: "name@example.com"  # only if confirmed and contextually appropriate
  phone: "+..."  # only if needed for ops
city: "Ташкент"
sources: ["[[sources/...]]"]
related:
  - "[[entities/where-works]]"
  - "[[projects/joint-project]]"
  - "[[people/spouse-or-partner]]"
tags: []
confidence: high | medium | low
---

# <Имя Фамилия>

## Кто это

1-2 строки: роль, что делает, чем интересен.

## Контекст знакомства

Когда, где, через кого. Текущий статус отношений.

## Биография / Trajectory

Что важно знать про путь этого человека.

## Чем занимается сейчас

Активные проекты, роли, ответственности.

## Что мы делаем вместе / для друг друга

- ...
- ...

## Предпочтения / стиль общения

- Time zone
- Прямой / непрямой стиль
- Темы интереса
- Триггеры (избегать)

## Последние взаимодействия

- YYYY-MM-DD — что обсуждали
- YYYY-MM-DD — что обсуждали

## Связи в моём круге

- [[people/...]] — отношения с другими людьми из моей вики

## Open questions

> #PROBLEM — что я не знаю про этого человека
```

## Privacy rules

1. **Никогда не публикуй** wiki в открытый репо. Используй private remote backup (см. `/add-second-brain` Phase 3).
2. **Чужие секреты — без явного согласия** не записывай. Если человек поделился чем-то конфиденциальным "для тебя лично" — не клади в вики или клади с пометкой `private: true` и обработкой при exports.
3. **GDPR / запрос на удаление** — если человек попросит "забудь меня", удали страницу + ссылки на неё (lint поможет найти).
4. **Last_seen** обновляй только когда было реальное взаимодействие. Не заглядывай назад "хочу обновить" — это искажение.

## Frontmatter поля — почему обязательны

- `relationship` — для query "покажи всех моих клиентов" / "кого давно не видела"
- `context` — для warm-start при упоминании имени в чате
- `last_seen` — для проактивных напоминаний "давно не общался с X"
- `contact.telegram` — для быстрого `notify_owner` или прямого DM
