---
name: web-deploy
description: Deploy a web project from ~/apps/<slug> to Vercel production. Use when the user says "задеплой X", "раскати на прод", "обнови лендинг". Main group only — MILA groups must request main to deploy.
version: 1.0.0
---

# web-deploy — production-деплой проекта

Прогоняет `vercel --prod --scope milagpt` из локальной папки проекта в `~/apps/<slug>/`.

## Когда использовать

- «Задеплой ashotai на прод», «обнови milagpt.cc», «залей farangismaster».
- После правок в `~/apps/<slug>/` — прогнать свежую версию на production.
- После вызова `/web-publish` (он сам деплоит milagpt-cc, здесь — для других проектов).

## Main-only

Скилл живёт только у main-группы. В MILA-контейнерах к нему нет доступа (проверь — если скилла нет, не пытайся сам).

Если ты MILA-группа и нужен деплой → сформируй предложение и отправь в main через `mcp__nanoclaw__send_message`: «Предлагаю задеплоить `mantra-uz` после правок в README. Ок?».

## Алгоритм

1. **Сверься с реестром** (`/workspace/global/web-projects/inventory.json`):
   - Ищешь slug по запросу пользователя (может быть «ashotai.com», «ashotai», «сайт Шахруза»).
   - Забирай `local_path` из `local_clones[]`.
2. **Проверь, что папка на месте и чистая**:
   ```bash
   cd <local_path>
   git status --porcelain
   ```
   Если есть незакоммиченное — **не деплой слепо**. Спроси: что делать с незакоммиченными правками (закоммитить / проигнорировать / отменить).
3. **Убедись, что есть `.vercel/project.json`** — если нет, сделай `vercel link --yes --project <slug> --scope milagpt` (ещё раз).
4. **Запусти деплой**:
   ```bash
   cd <local_path>
   vercel deploy --prod --scope milagpt --yes
   ```
5. **Дождись готовности.** CLI печатает Production URL. Выполни `curl -sSfI <url>` → 200.
6. **Обнови inventory** (по желанию): подними `refresh-inventory.sh`, чтобы `vercel_projects[].updated` обновилась.
7. **Сообщи результату**: `✅ Задеплоено: https://...` + commit-хеш, если был push.

## Защита

- **Не деплой в проды чужие** (например, клиентский `solidrealty` без одобрения Шахруза).
- **Не push --force** в git при деплое.
- При ошибке деплоя — **покажи последние 30 строк** `vercel logs <url>` и останавливайся, не ретраить в цикле.

## Helpers

Можешь использовать `/home/node/.claude/skills/web/vercel-scope.sh` — тонкая обёртка. Не обязательно.
