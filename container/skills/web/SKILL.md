---
name: web
description: Foundation skill for the web-projects suite — shared helpers for Vercel CLI, GitHub CLI, and the inventory of our public web properties. Don't invoke this directly; it's the substrate for /web-inventory, /web-publish, /web-deploy, /web-logs, /web-audit.
version: 1.0.0
---

# web — foundation for web-projects suite

Общая инфраструктура для работы с нашими веб-проектами: Vercel (team `milagpt`), GitHub (org/user `shakhruz`), локальные клоны в `~/apps/`.

## Shared state

- `/workspace/global/web-projects/inventory.json` — канонический реестр проектов. Обновляется `refresh-inventory.sh`.
- `/workspace/global/web-projects/inventory-readable.md` — человеко-читаемая версия для Telegram/wiki.
- `/workspace/global/web-projects/audits/<date>-<slug>.md` — отчёты аудита.
- `/workspace/global/web-projects/last-refresh.txt` — ISO-таймстамп последнего обновления.

## Helpers (исполняются только там где есть Vercel CLI + gh + git + доступ к ~/apps/)

| Helper | Назначение |
|---|---|
| `publish-html.sh` | публикация страницы на milagpt.cc (см. skill `/web-publish`) |
| `refresh-inventory.sh` | собрать `inventory.json` с Vercel + GitHub |
| `vercel-scope.sh` | обёртка `vercel --scope milagpt <args>` |
| `gh-wrap.sh` | обёртка `gh` с нужными дефолтами |

## Типы проектов (tier)

- `priority` — ashotai.com, aibusinessclub.uz, mantra.uz, skylineyoga.uz, farangismaster.com, govorilka.app, milagpt.io, milagpt.cc
- `medium` — yogamap.uz, skyline-instructor-course, growingsoftware, skylineyoga.online
- `experiment` — ustabot.uz, nanobot.uz, chiefai.uz, chiefai.my, bquantum.online
- `client` — solidrealty.uz
- `archive` — всё что не активно

## Слоты статуса

- `active` — реально используется, есть live-домен
- `maintenance` — живёт, но без активной разработки
- `paused` — пауза (не удалять, но не развивать)
- `planned` — в планах, ещё не создан

## Правила безопасности

- Write-операции (publish, deploy, env) — только main-group.
- MILA-группы — read-only (inventory, audits). Write через proposal-в-main.
- `tg_lead-*` и `telegram_ashotai-experts` — вообще без доступа к `web-*` скиллам (отрезаны в `src/container-runner.ts`).
- Secrets (`.env`, tokens, DB connection strings) — **никогда не публиковать** в `milagpt.cc` и не класть в inventory.

## Ссылки на другие скиллы

- `/web-publish` — опубликовать HTML на milagpt.cc
- `/web-inventory` — показать / обновить реестр проектов
- `/web-deploy` — `vercel --prod` из `~/apps/<slug>/` (main-only)
- `/web-logs` — логи / inspect по slug
- `/web-audit` — проверка здоровья проекта
