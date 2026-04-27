---
name: web-inventory
description: Show or refresh the registry of our web projects — Vercel projects, domains, GitHub repos, local clones in ~/apps. Use when the user asks "что у нас задеплоено", "какие сайты есть", "покажи реестр", "обнови список", or before any /web-deploy / /web-audit action to pick the right slug.
version: 1.0.0
---

# web-inventory — реестр наших веб-проектов

Единый источник правды по тому что у нас живёт: Vercel-team `milagpt` + GitHub-user `shakhruz` + локальные клоны `~/apps/`.

## Когда использовать

- «Покажи список наших сайтов» → прочитай `/workspace/global/web-projects/inventory.json`, сформатируй.
- «Обнови реестр» → запусти refresh-inventory.sh.
- Любой `/web-deploy`, `/web-logs`, `/web-audit` — сначала сверься с реестром (узнай slug → путь → домен).

## Алгоритм: show

1. Проверь свежесть:
   ```bash
   cat /workspace/global/web-projects/last-refresh.txt
   ```
   Если старше 7 дней — запусти refresh (см. ниже), затем читай.

2. Загрузи данные:
   ```bash
   jq . /workspace/global/web-projects/inventory.json
   ```

3. Сформатируй для пользователя. Минимальный output:
   - **Активные live-сайты**: домен + Vercel-project + local_path (если есть).
   - **Проекты без кастом-домена**: только Vercel-URL.
   - **Orphans**: GitHub-репо без Vercel, Vercel без GitHub.

4. Формат (Telegram markdown):
   ```
   📦 *Наши веб-проекты* · 50 Vercel · 19 доменов · 163 GitHub

   *Priority (домены)*
   • ashotai.com — `ashotai` / `~/apps/ashotai`
   • milagpt.cc — `milagpt-cc` / `~/apps/milagpt-cc`
   ...

   *Без кастом-домена*
   • `cpr` — cpr-steel.vercel.app
   ...

   Последнее обновление: <ISO-ts>
   ```

## Алгоритм: refresh

```bash
/home/node/.claude/skills/web/refresh-inventory.sh
```

Работает только где есть `vercel`, `gh`, `git`, `jq`. В MILA-контейнере без этих CLI не сработает — тогда проси main.

Output: JSON-саммари `{updated_at, vercel_projects, vercel_domains, github_repos, local_clones}`.

## Правила

- **Не публикуй** содержимое реестра как есть в публичных каналах — там внутренние URL и маркеры.
- При обнаружении **orphan'а** (репо без Vercel или Vercel без репо) — упомяни в summary, но не удаляй ничего.
- Для команды `что у нас с проектом X`: найди в `inventory.json` по slug или по подстроке домена.

## Структура данных

`inventory.json`:
```json
{
  "updated_at": "2026-04-23T03:15:21Z",
  "vercel_projects": [{ "vercel_project": "ashotai", "vercel_prod_url": "https://ashotai.vercel.app", "updated": "34d", "node": "24.x" }, ...],
  "vercel_domains": ["ashotai.com", "mantra.uz", ...],
  "github_repos": [{ "name": "ashotai", "url": "https://github.com/shakhruz/ashotai", "description": "...", "defaultBranchRef": {"name": "main"}, "updatedAt": "...", "isArchived": false }, ...],
  "local_clones": [{ "slug": "milagpt-cc", "local_path": "/Users/.../apps/milagpt-cc", "github_url": "...", "last_commit": "..." }]
}
```

## Ссылки

- `refresh-inventory.sh` — `container/skills/web/refresh-inventory.sh`
- Shared state — `/workspace/global/web-projects/`
- См. также `/web-publish`, `/web-deploy`, `/web-logs`
