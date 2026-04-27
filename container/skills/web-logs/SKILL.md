---
name: web-logs
description: Fetch runtime or build logs for a deployed web project on Vercel, or inspect a deployment. Use when the user says "что с логами X", "почему упал билд", "покажи последний деплой", "что не так с сайтом".
version: 1.0.0
---

# web-logs — логи и inspect Vercel-деплоев

Обёртка над `vercel logs` и `vercel inspect` через реестр проектов.

## Когда использовать

- «Посмотри логи ashotai.com» → runtime-логи последнего production-деплоя.
- «Почему упал деплой X» → build-логи.
- «Когда последний раз деплоили Y» → inspect.

## Алгоритм

1. **Найди deployment URL** по запросу:
   - Пользователь может сказать «ashotai.com» → в `inventory.json` ищешь `vercel_domains` и сопоставляешь с `vercel_projects[].vercel_project`. Последний deploy ловишь через `vercel ls <project> --scope milagpt`.
2. **Runtime-логи**:
   ```bash
   vercel logs <deployment-url> --scope milagpt
   ```
3. **Build-логи** (если деплой упал):
   ```bash
   vercel inspect <deployment-url> --logs --scope milagpt
   ```
4. **Inspect без логов**:
   ```bash
   vercel inspect <deployment-url> --scope milagpt
   ```

## Правила

- **Не спамь полным дампом** в Telegram. Фильтруй ошибки/warning'и. Для пользователя — саммари (где упало, stack-trace в одну строку, время).
- **Не показывай env-переменные** — `vercel inspect --env` никогда без явной просьбы.
- Если логов слишком много — сохрани полный дамп в `/workspace/global/web-projects/audits/<date>-<slug>-logs.txt` и дай ссылку.

## Пример саммари

```
⚠️ *ashotai.com* — последний деплой упал
   Deployment: https://ashotai-abc123.vercel.app
   Время: 2 часа назад
   Причина: Build failed — "Module not found: 'next-intl'"
   Полный лог: /workspace/global/web-projects/audits/2026-04-23-ashotai-logs.txt
```
