# Wiki Essentials — Quick Snapshot

*Auto-updated на каждом ingest. Last updated: DATE_PLACEHOLDER*

> Быстрый снапшот вики для warm-start каждой сессии. ~600 токенов.
> Для полного каталога → [[index]]. Для деталей → drill-down в конкретную страницу.

---

## Domain

**<DOMAIN>**

> Замени `<DOMAIN>` на одну строку про предмет вики (например: "personal second brain — business + clients + AI research")

---

## 🔥 Активные проекты

| Проект | Описание |
|---|---|
| _(добавятся по мере ingest)_ | |

---

## 👤 Ключевые люди

| Человек | Роль / Контекст |
|---|---|
| _(добавятся по мере ingest)_ | |

---

## 📦 Последние 5 ingest'ов

_(автоматически обновляется при каждом ingest — добавляй сверху, держи макс 5)_

---

## 🏢 Ключевые сущности

| Сущность | Описание |
|---|---|
| _(добавятся по мере ingest)_ | |

---

## 🧩 Топ концепты

| Концепт | Суть |
|---|---|
| _(добавятся по мере ingest)_ | |

---

## 📊 Статистика wiki

- Всего страниц: 0
- Последнее обновление: DATE_PLACEHOLDER
- Активных проектов: 0
- Людей: 0
- Сущностей: 0
- Концептов: 0
- Sources: 0
- Journal entries: 0

---

## ⚠️ Правила (никогда не нарушай)

1. **Никогда не клади секреты в wiki** — API ключи, токены, пароли. Используй onecli vault. Lint-проверка ругается на patterns `sk-`, `pat-`, `Bearer `, `password:`, `token:`.
2. **Один источник за раз** при ingest. Не батч-ингест — это даёт shallow generic pages вместо глубокой интеграции.
3. **Binary media (audio, video, images >1MB) НЕ коммить в git** — они в `.gitignore`. Создавай `.md` stub с metadata + локальный путь.
4. **`git pull --rebase` перед commit** — wiki может синкаться с другой машиной через GitHub remote.
5. **Curator vs Contributor разграничение** — curator (main) делает full ingest и владеет structure. Contributors (sub-agents) пишут в `inbox.md` и `projects/<role>/`, не трогают чужое.
