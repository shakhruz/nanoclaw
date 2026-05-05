# Мила (MILA GPT) — Кастомизированный NanoClaw v2

## Что это

**Мила** — форк NanoClaw v2 для личного AI-ассистента Шахруза Аширова. Полный переход с v1 на v2 с 18 локальными коммитами, добавляющими специализированные навыки, бизнес-интеграции и оптимизацию для **Telegram-first рабочего процесса**. Основная работа идёт через голосовые дайджесты Шахруза, который наговаривает контекст, задачи и идеи. Мила — не помощник, а **бизнес-партнёр**: генерирует планы, ведёт решения, предлагает шаги, учитывает приоритеты и управляет информацией между чатом, wiki и инструментами (Todoist, Google Calendar, Gmail).

**Лицензия:** Copyright (c) Anthropic. Форк для личного использования Шахруза Аширова.

---

## Главные доработки

### 1. **Голосовой дайджест-процессор** (`voice-digest-processor`)
Полностью переработанный pipeline для обработки голосовых от Шахруза. Deepgram nova-2 (русский) → автоматическое расшифровка → разбор по темам → журнал в wiki с ссылками → инкремент задач Шахруза в Todoist с back-reference на запись. Реакция ⚡ сигнализирует о получении, финальный ответ — партнёрский (вопросы как эксперт, идеи для counter-argument).

### 2. **Управление открытыми решениями** (`pending-decisions`)
Очередь вопросов Шахрузу с приоритизацией и follow-up'ами. Ты **ведёшь** партнёра по решениям, не жди пока он сам заглянет в файл. Каждый вопрос — D-NNN с контекстом, вариантами 1️⃣2️⃣3️⃣, автоматический repeat через 3 часа если нет ответа. Файл `decisions/pending.md`, архив в `answered.md`.

### 3. **Утренний бриф** (`morning-brief`)
Ежедневно в 08:00 (Ташкент) — погода, лунный календарь, встречи, задачи на день, бизнес-пульс с наблюдениями и рекомендацией, новые письма, соцсети-аналитика (YouTube/Instagram/LinkedIn через Zernio API), новости ИИ, новости Узбекистана, статус Telegram Ads (баланс, активные кампании, CTR). Мобильный формат — 8 строк max в Telegram.

### 4. **Вечерний recap** (`evening-recap`)
Каждый день в 21:00 — краткое закрытие дня. Что сделано, что в работе, какие решения висят твоего ответа, рекомендация на завтра. Тоже Telegram-оптимизировано.

### 5. **Фабрика видео-шортсов** (`video-shorts-factory`)
OpenShorts engine на host'е → нарезка длинных видео (2+ часа) в вертикальные shorts (9:16) для TikTok, Reels, YouTube Shorts с AI-выбором viral-moments через Gemini Flash. Разбивка на 30-минутные чанки перед обработкой, параллельный processing, автоматический копирование результатов перед auto-purge OpenShorts'а.

### 6. **Образование клиентов / Octo-воронка** (группа `octo-_`)
Интеграция с OctoFunnel (платформа видео-обучения Шахруза). Отслеживание trial-клиентов (day 1–7), конверсия trial → платная ($200/мес базовый, $1200/мес VIP), атрибуция лидов через Telegram Ads → подписку → trial. Отдельный агент `octo-_` управляет sales-action'ами.

### 7. **Канал и контент** (`channel-curator`, `business-pulse`, `content-planner`)
Управление каналом @ashotonline (подписчики, engagement, schedule), еженедельный контент-план, анализ engagement через Zernio API, реакции на сообщения (👀, 👍, ❤️), трекинг постов-лидеров. auto-suggest каждого завершённого действия предлагает next-action из бизнес-целей (📈 подписчики, 🎯 реклама, ✍️ контент, 💰 продажи, 🤝 партнёры).

### 8. **Telegram Ads аналитика и управление** (`telegram-ads-generator`, `telegram-ads-auth`)
Curl-pipeline вместо headless-browser для скорости. Еженедельный отчёт по кампаниям — CTR, потрачено, показы, ROI. Auto-генерация креативов (текст + картинка через Gemini), паузирование/расширение winners, ротация по performance. Логирование spend в usage-log.jsonl.

### 9. **Вторая мозг на основе Karpathy LLM Wiki** (`wiki` skill)
Полная инфраструктура второго мозга: `/workspace/global/wiki/` с разделами journal (дневные записи), people (сотрудники, клиенты, партнёры), projects (инициативы), concepts (идеи и паттерны), entities (товары, услуги), sources (ресурсы с цитатами). Curator-режим ты — ingest'ируешь материал, фрагментируешь, обновляешь индекс. Шахруз не открывает файлы, всё — в Telegram.

### 10. **Интеграция с внешними инструментами**
- **Todoist:** MCP-доступ, создание/обновление/закрытие задач с привязкой к бизнес-целям и проектам
- **Google Calendar:** встречи, свободные слоты, интеграция с Todoist (встреча с X — какие задачи)
- **Gmail:** дайджесты входящих, поиск, черновики (но Шахруз редко открывает)
- **Parallel AI Task API:** глубокий ресёрч с асинхронным polling через scheduler

### 11. **Команда субагентов** (`create_agent`)
Долгоживущие специалисты (маркетолог, дизайнер, копирайтер, продавец, методолог) для параллельной работы. Каждый имеет свой контейнер, workspace в `groups/<имя>/`, накапливает контекст. Ты координируешь — отправляешь задачи через `send_message(to="<role>")`, они отвечают async, ты синтезируешь в финальный ответ.

### 12. **Реакции на сообщения с двусторонними командами** (`telegram-reactions`)
👀 автоматически при получении, финальные реакции для статуса (👏 готово, 💔 ошибка, 🤔 уточнение). Плюс команды **от Шахруза к тебе** через реакции (👍 одобрить, ❤️ запомнить в wiki, 🤬 удалить, 🔥 важно).

### 13. **Admin-IPC канал** (двусторонняя связь с parent Claude Code)
Прямой JSON-канал для общения между инфраструктурой (admin) и Милой. Admin может запросить статус, Мила может запросить новый skill, расширить vault. Файлы в `/workspace/global/admin-ipc/`.

### 14. **Улучшения типинг-индикатора** (`src/modules/typing`)
Пролонгирование typing-indicator во время длинных операций (вместо одного вызова). Патч 2026-05-04: увеличение post-delivery паузы с 10s до 60s так чтобы не горел при длинных sub-agent отчётах.

### 15. **Русскоязычное одобрение каналов** (`src/modules/permissions/channel-approval`)
Карточки одобрения нового канала на русском: «Одобрить / Игнорировать» с явным указанием target agent group. Dedup по messaging_group_id.

---

## Custom Skills (по категориям)

### Голос и медиа
- **voice-digest-processor** — обработка голосовых дайджестов (основной входной канал)
- **video-shorts-factory** — нарезка видео в shorts через OpenShorts
- **telegram-reactions** — двусторонние реакции на сообщения
- **telegram-publish** — публикация в @ashotonline через bot API

### Контент и каналы
- **channel-curator** — управление @ashotonline (расписание, ревью, engagement)
- **content-planner** — еженедельный контент-план с Todoist-интеграцией
- **business-pulse** — наблюдения за ростом (подписчики, ROI, клиенты)
- **morning-brief** — утренний бриф (встречи, задачи, новости, ads)
- **evening-recap** — итоги дня и pending-решения

### Планирование и решения
- **pending-decisions** — очередь вопросов с follow-up'ами
- **weekly-plan** — распределение задач на неделю
- **weekly-review** — what done, what failed, what next

### Реклама и продажи
- **telegram-ads-generator** — автоген креативов (текст + изображение через Gemini)
- **telegram-ads-auth** — OAuth для Telegram Ads API
- **telegram-ads-research** — анализ соперников, keywords, trending ads
- **client-pulse** — трекинг клиентов (trial → paid, NPS, touch-points)
- **offer-iteration** — A/B тестирование КП и лендинг-страниц

### Admin и инфра
- **wiki** — curator-mode для второго мозга (ingest, фрагментация, индекс)
- **team-monitor** — статус членов команды, loads, availability
- **usage-report** — еженедельный отчёт по потреблению OpenRouter, Apify, Deepgram

### Партнёрство и онбординг
- **onboarding-new-user** — welcome-flow для новых клиентов (бот, форма, trial)
- **octofunnel-crm** — интеграция с Octo, управление воронкой
- **octofunnel-analytics** — конверсия, retention, LTV по когортам

---

## Изменения в core (src/)

| Файл | Что изменено | Зачем |
|------|---|---|
| `src/modules/typing/index.ts` | Пролонгирование typing-indicator, паузы между сообщениями | Улучшение UX при длинных операциях — не горит постоянно |
| `src/modules/permissions/channel-approval.ts` | Русскоязычные карточки одобрения каналов | Одобрение новых чатов с явным указанием целевого агента |
| `src/container-runner.ts` | Расширение NO_PROXY allowlist для 3rd-party API | Обход проксирования для OpenRouter, Deepgram, Apify |
| `src/db/` migrations | Schema для pending_decisions, admin-ipc messages | Persistent storage для open questions и admin-канала |
| `src/session-manager.ts` | Heartbeat для tracking agent work | Основа для typing-indicator refresh logic |

---

## Архитектура общения

```
Шахруз (мобильный Telegram)
   ↓ (голосовое, текст, реакции)
Telegram Bot API (chat SDK)
   ↓
Router (routeInbound)
   ↓
Мила (контейнер agent-runner, Bun)
   ├─ voice-digest-processor → wiki/journal/
   ├─ tasks.md → pending-decisions
   ├─ Todoist ←→ task sync
   ├─ sub-agents (маркетолог, дизайнер, продавец) ← → a2a communication
   ├─ admin-ipc ← → parent Claude Code
   └─ output → outbound.db → Delivery → Telegram
   ↓
Шахруз (уведомление, read, react)
```

**Однонаправленные потоки:**
- Входящее: голос/текст от Шахруза → routeInbound → inbound.db → agent wake-up
- Выходящее: agent output → outbound.db → Delivery → Telegram Bot API → chat
- Sub-agent ответы: async через destination "parent" → встраиваются в текущий turn или пишут в chat

**Между-сессионная память:**
- `/workspace/global/wiki/` — второй мозг (shared, persisted git)
- `tasks.md` — текущий backlog Милы
- `/workspace/agent/shakhruz-todo.md` — Todoist mirror (ждёт поднятия MCP)
- `/workspace/agent/wiki/decisions/pending.md` — open questions

---

## Что НЕ публично (gitignore)

```
.env*                          # API keys, credentials
data/                          # SQLite DBs (session + central)
groups/telegram_main/data/     # Per-group data, attachments
logs/                          # Runtime logs
.credentials.json              # Claude OAuth tokens
groups/*/wiki/ (архив)         # Если были локальные wiki до v2
/workspace/*/                  # Container mounts (они существуют только runtime)
groups/telegram_main/CLAUDE.local.md  # Шахруз и его персональный контекст
```

**CLAUDE.local.md** содержит:
- Стиль речи и русский язык requirements (без англицизмов)
- Учёт расходов при вызове OpenRouter/Apify
- Часовой пояс (Asia/Tashkent, UTC+5)
- Роли (бизнес-партнёр, ассистент, curator второго мозга)
- Бизнес-цели и компас next-actions
- Todoist integration rules
- Wiki curator discipline
- Mobile-friendly format rules
- Emoji reactions whitelist

Это **личное настроение** Милы для работы с Шахрузом — не входит в репо.

---

## Roadmap (в работе и планы)

### В процессе (из последних commit'ов)

1. **Auto-approve для trusted partners** — расширение channel-approval для группы партнёров (без full-admin, но auto-wire если trusted)
2. **Billing-tracker per-user** — fine-grained учёт spend по каждому клиенту (OpenRouter/Apify usage tagged with client_id)
3. **Multi-agent shared-chat** — несколько субагентов могут общаться друг с другом в одном чате (сейчас только через Милу)

### Longer-term (из comments в коде)

1. **Self-modification tier 2** — draft/activate flow для прямых изменений source в контейнере (сейчас только install_packages и add_mcp_server)
2. **Multi-provider routing** — switcher между Claude / OpenCode / OpenRouter в зависимости от задачи (сейчас всё через Claude через OneCLI)
3. **Wiki versioning + diffs** — Git-based wiki с автоматическим tracking изменений и rollback
4. **Telegram userbot integration** — отдельная личная идентичность (@ashot_ashirov_ai) для DM'ов и истории кампаний
5. **Octo-embedded video player** —직접 Octo trial-видео в Telegram (сейчас linker на асhotai.uz)

### Known issues (watch list)

- OneCLI `selective` secret mode для auto-created agents — нужно `set-secret-mode --mode all` вручную после спавна
- Pool bot'ы (4 identity'я для swarm-команды) перезагружаются при рестарте сервиса (state не persisted)
- Todoist MCP ещё не поднят — используется `shakhruz-todo.md` как workaround
- OpenShorts job auto-purge через 1 час — нужна immediate persistence после `status=completed`

---

## Как разворачивать форк

1. **Clone и initial setup:**
   ```bash
   git clone https://github.com/YOUR_ORG/mila-nanoclaw.git
   cd mila-nanoclaw
   pnpm install
   ./container/build.sh
   cp .env.example .env  # заполнить credentials
   ```

2. **Run первый раз:**
   ```bash
   pnpm run dev  # host в dev-mode
   # в отдельном терминале:
   onecli --help  # проверить и поднять vault
   ```

3. **Wire Telegram:**
   - В `/setup` skill или через chat: `/telegram:configure` — bot token
   - В `/telegram:access` — approve pairing

4. **Init first agent:**
   ```bash
   /init-first-agent  # setup DM channel + CLAUDE.md for main group
   ```

5. **Вкусы (customization):**
   - Обновить `groups/telegram_main/CLAUDE.local.md` под своего пользователя
   - Расширить `wiki/` структуру (добавить `people/`, `projects/`, `entities/`)
   - Wiring каналов через `/manage-channels` если нужны дополнительные

---

## Запуск в продакшене (macOS с launchd)

```bash
# Install launchd plist
cp assets/launchd/com.nanoclaw.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.nanoclaw.plist

# Logs
tail -f logs/nanoclaw.log
tail -f logs/nanoclaw.error.log

# Restart
launchctl kickstart -k gui/$(id -u)/com.nanoclaw
```

На Linux — используй systemd (инструкции в docs/build-and-runtime.md).

---

## Что уникального в этом форке

1. **Полный переход на v2 с сохранением 18 custom-шагов** — не half-migration, а clean restart на новой архитектуре
2. **Мила как партнёр, не ассистент** — активное predicting next-actions, ведение решений, автоматические suggest'ы через inline-buttons
3. **Голос как основной канал** — всё подстроено под дайджесты от Шахруза; wiki и tasks — support system
4. **Интеграция Telegram Ads + Octo воронка** — полный цикл от рекламы через trial к платной подписке с attribution
5. **Strict Russian без англицизмов** — языковая дисциплина встроена в CLAUDE.local.md, используется как инструмент самоизучения
6. **Асинхронные субагенты вместо sync-calls** — маркетолог/дизайнер/продавец работают в параллель, aggregate результаты
7. **Second-brain wiki на основе Karpathy LLM Wiki pattern** — полная инфра для persistent knowledge с curator-модой

---

## Для разработчика форкнувшего этот репо

Основной паттерн: **бизнес-целей в emoji-префиксах, одного вопроса за раз, мобильного формата, партнёрского тона**. Раскодирование каждого новога действия:
- Связано ли это с одной из 5 целей? (📈🎯✍️💰🤝)
- Блокирует ли это что-то или это nice-to-have?
- Может ли это сделать sub-agent параллельно?
- Нужно ли решение от user'а или я могу решить сама?
- Поместится ли в 8 строк мобильного Telegram?

Если хоть на один вопрос ответ «нет» — переработай.

---

**Ветка:** `migrate/v1-to-v2` • **Автор форка:** Shakhruz Ashirov • **Дата форка:** май 2026 • **Upstream:** NanoClaw v2 (main)
