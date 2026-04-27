---
name: web-audit
description: Run a health check on a web project — domain reachable, last deploy age, package versions outdated, git dirty, obvious TODOs. Use when the user says "проверь X", "что со здоровьем сайта Y", "аудит".
version: 1.0.0
---

# web-audit — здоровье веб-проекта

Проходится по проекту в `~/apps/<slug>/` + по Vercel-деплою + по домену, собирает краткий отчёт.

## Когда использовать

- «Проверь состояние yogamap.uz» → аудит.
- «Что с проектами в целом» → аудит всех priority-проектов по очереди.
- Перед тем как что-то обновлять — сначала audit (знаем стартовую точку).

## Чек-лист аудита (один проект)

1. **Домен живой?**
   ```bash
   curl -sSfIL --max-time 10 https://<domain> | head -1
   ```
   Ожидаем `HTTP/2 200`. Если 4xx/5xx/timeout → **фатально**, сверху отчёта.

2. **Последний деплой когда?**
   ```bash
   vercel ls <project> --scope milagpt | head -5
   ```
   Если старше 60 дней — флаг "застоялся".

3. **Git на месте?**
   ```bash
   cd ~/apps/<slug>
   git status --porcelain
   git log -1 --format="%cI %s"
   ```
   Если dirty → упомяни незакоммиченные файлы. Если последний коммит старше 90 дней → флаг "давно не трогали".

4. **package.json — нода и зависимости**:
   ```bash
   cat package.json | jq '{name, engines, scripts}'
   ```
   Если в Vercel node != package.engines.node → флаг несоответствия.

5. **Быстрая проверка — build-ready**:
   Скажи про то, что нужно `npm install && npm run build` для полной проверки, но **не запускай** (долго, может положить CI). Только если пользователь попросил.

6. **TODO / FIXME / XXX**:
   ```bash
   git -C ~/apps/<slug> grep -nE "TODO|FIXME|XXX" | head -10
   ```

## Output формат

Сохрани отчёт в `/workspace/global/web-projects/audits/<YYYY-MM-DD>-<slug>.md`:

```markdown
# Audit: <slug> (<domain>) — YYYY-MM-DD

## Статус
- 🟢 Домен: 200 OK
- 🟡 Последний деплой: 83 дня назад (застоялся)
- 🟢 Git: чисто, последний коммит 12 дней назад
- 🟢 Node: 24.x согласовано
- 🔴 TODO: 7 штук

## TODOs
- src/page.tsx:42 — TODO: add analytics
- ...

## Рекомендации
1. Задеплоить последнюю версию — она на main, но в прод не раскатана 83 дня.
2. Добавить Umami/Plausible аналитику.
3. ...
```

Затем пришли пользователю саммари в Telegram (3-5 строк) + линк на полный отчёт.

## Правила

- **Не запускай `npm install`** автоматически — только по просьбе (может быть долго, может сломать lock).
- **Не чини сам** — скилл только диагностирует, фикс — отдельная сессия.
- Если детектишь критичное (сайт лежит, SSL истёк, security issue) → шли пользователю ⚠️-уведомление сразу, не жди full аудита.
