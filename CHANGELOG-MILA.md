# CHANGELOG — MILA Edition

История изменений нашего форка NanoClaw поверх upstream `qwibitai/nanoclaw`. Только наши коммиты на ветке `migrate/v1-to-v2`. Хронологически от свежих к старым.

---

## 2026-05-05 — `593d1a5` typing+approval polish + container reliability + voice digest pipeline

**16 файлов, +612 / −61 строк**

- **`src/modules/typing/index.ts`** — `POST_DELIVERY_PAUSE_MS` 10s → 60s. Typing-indicator больше не «горит постоянно» во время длинных turn'ов
- **`src/modules/permissions/channel-approval.ts`** — approve-карточки переведены на русский (Одобрить/Игнорировать), резолв `display_name` отправителя из `users` table, preview первого сообщения в карточке
- **`src/container-runner.ts`** — расширен env-whitelist для vendor-keys (OPENROUTER, DEEPGRAM, APIFY, COMPOSIO, ZERNIO, TODOIST, GEMINI, FAL) — temp fix до полной миграции на vault gateway header injection
- **`src/channels/chat-sdk-bridge.ts`** — мелкие правки delivery
- **`container/agent-runner/src/poll-loop.ts`** — auto-eyes hook (👀 на каждое входящее) + heartbeat в `setInterval` (защита от блокировки event-loop)
- **`container/agent-runner/src/providers/claude.ts`** — `compact_boundary` yield'ится как `progress` (не `result`), чтобы compaction не вешал heartbeat
- **`container/agent-runner/src/mcp-tools/core.ts`** — composite-messageId trim (фикс баг с 3-сегментным id)
- **`container/Dockerfile`** — `apt install jq` (раньше Mila каждый compaction пыталась `npm install jq` через прокси, залипала)
- **`scripts/refresh-claude-creds.sh` + `launchd/com.nanoclaw.refresh-claude-creds.plist`** — host-side периодическое обновление Anthropic OAuth каждые 30 мин
- **`container/skills/video-analysis/`** — placeholder skill для будущего OpenShorts pipeline

## 2026-05-02 — `6bf6564` channel content stack + admin UX + media pipeline

- Полный контент-стек для @ashotonline: master-content-plan.md (11 публикаций/неделю), personas-pool, tools-pool, skills-prompts-pool, events-pool, hashtag-system, sales-funnel
- 7 новых channel skills: `ai-news-digest`, `persona-week`, `tools-week`, `weekly-summary`, `livestream-thumbnail`, `instagram-livestream-publish`, `channel-weekly-planner`
- Inline-buttons как default для choice questions (через `ask_user_question` вместо текстовых "1/2/3")
- Real inline-buttons + callbacks для admin (parent session) — `next:menu_id:value` callback handler в `chat-sdk-bridge`
- Auto-eyes reaction на каждое входящее
- Mila identity rewrite: партнёр + ментор + управляющий (3 роли), не пассивный ассистент
- Pseudo-button next-steps в каждом ответе («✋ Что дальше? 1️⃣2️⃣3️⃣4️⃣»)
- Telegram-publish skill: download/transcribe (Deepgram) / extract-segments / publish_now / list_scheduled / cancel / reschedule / edit_sched / dm / metrics
- Container watchdog (`mila-watchdog.sh`) — kill при stuck >5 мин и pending >0
- Admin send-next-menu.sh + wait-decision.sh для inline-callback flow

## 2026-05-01 — `53c016e` OneCLI bind 0.0.0.0 + populate vault

- OneCLI Postgres + gateway на 0.0.0.0 (для Apple Container access)
- Скрипт первичного наполнения vault (5 vendor secrets с правильными host-patterns)
- Удалены env-only workarounds для случаев когда vault недоступен

## 2026-04-30 — `b622d96` 3rd-party API keys injection + NO_PROXY allowlist

- Container-runner whitelist'ит vendor keys (OpenRouter, Apify, Deepgram, Composio, Zernio) — fallback до миграции на vault
- NO_PROXY расширен: `api.anthropic.com`, `claude.ai`, `*.anthropic.com`, `github.com`, `*.github.com`, `codeload.github.com` — Anthropic трафик идёт мимо OneCLI прокси

## 2026-04-29 — `f844225` per-team wikis merge + a2a-write pattern + /workspace/group compat

- Объединение wiki разных групп в общее пространство `/workspace/global/wiki/`
- v2 a2a write pattern (sub-agents пишут в shared wiki через RW mount только в свой `journal/<group>/` подкаталог)
- `/workspace/group/` compat mount для скриптов которые ожидают v1 layout

## 2026-04-28 — `d54b5a6` reactions emoji aliases + better tool description

- В `set_reaction` MCP-tool: автоматический translate `:fire:` / `🔥` / `fire` → правильный Unicode из Telegram whitelist
- Расширенный description для LLM чтобы не пыталась использовать non-whitelisted emoji

## 2026-04-27 — `71ec586` inline Deepgram transcription для Telegram voice

- Telegram channel adapter транскрибирует voice автоматически через Deepgram nova-2 (русский, smart_format)
- Mila получает в text сразу: `[Voice: расшифровка]` — не нужно качать .oga и звать Deepgram
- Auto-extract аудио из видео через ffmpeg (380MB видео → 26MB mp3 → upload Deepgram за 1 мин)

## 2026-04-26 — `b6948db` shared /workspace/global/wiki mount + auto-fragment

- `groups/telegram_main/wiki/` mount'ится в каждый sub-agent контейнер как `/workspace/global/wiki/` (read-only по умолчанию)
- Auto-fragment instructions: large CLAUDE.local.md разбиваются на `.claude-fragments/` для context-budget hygiene
- `module-agents`, `module-core`, `module-interactive`, `module-scheduling`, `module-self-mod` фрагменты

## 2026-04-25 — `60f43d2` message_reaction subscriptions + acknowledge-reactions skill

- Подписка на `message_reaction` updates в Telegram (видим когда кто-то реагирует на наше сообщение)
- Skill `acknowledge-reactions` — Mila реагирует обратно на эмодзи Шахруза (👍 → 🙏, 🔥 → 🚀, и т.д.) — поддержание raport

## 2026-04-24 — `79be138` shared CLAUDE fragment via container/skills/team-mode

- Skill `team-mode` — фрагмент CLAUDE.md шарится через container skills, чтобы все sub-agents работали как единая команда
- Унификация identity между группами без копирования

## 2026-04-23 — `09f8249` host-side Claude OAuth auto-refresh

- macOS Keychain + launchd для auto-refresh Claude subscription tokens каждые 30 мин
- Mila не падает на expired OAuth (раньше падала каждые ~3 часа)

## 2026-04-22 — `80a9c01` v2 create_agent pattern для team-mode

- Sub-agent spawn через v2 `mcp__nanoclaw__create_agent` (вместо ручных a2a destinations)
- `session_mode='dedicated'` для каждого sub-agent — изолированный контекст

## 2026-04-21 — `1127565` Claude subscription via .credentials.json + bypass OneCLI proxy

- Anthropic API через subscription (Claude Pro/Max) вместо API-tokens
- `data/anthropic-creds/.credentials.json` mount в каждый container
- NO_PROXY для Anthropic (idempotent с предыдущим)

## 2026-04-20 — `91894bc` migrate restore-scheduled-tasks.ts

- Скрипт миграции v1 → v2 для scheduled tasks (hourly pulse, evening recap, etc.)
- Seed v1 cron'ов в v2 sessions schema

## 2026-04-19 — `cdb3c32` router debug trace

- Diagnostic log в `routeInbound` для отладки multi-channel routing

## 2026-04-18 — `003c951` Apple Container compat + Claude binary path

- `node:20-bullseye` → bullseye-slim (меньше образ)
- Полный путь к Claude binary (`/home/node/.local/bin/claude`) — Apple Container не имел `claude` в PATH

## 2026-04-17 — `de46a1f` Apple Container CLI runtime switch

- `src/container-runtime.ts` поддерживает Apple Container (system status, ls --format json, --mount)
- Fallback на Docker если Apple Container не доступен
- Mila теперь спавнится через `container run` (нативный macOS), не через Docker

## 2026-04-15 — `f8cab90` migrate stages 1-3

- Извлечение из v1: 75 container skills, 6 custom feature skills, telegram channel skill, admin-panel
- Миграция guide в `.nanoclaw-migrations/`
- v1 archive остаётся read-only в `~/nanoclaw/nanoclaw/`

---

## Что в ближайшем roadmap

- **Auto-approve refactor**: bypass approve-карточек → `admin-messages/` Mila (чтобы она генерила нормальные карточки на русском с полным контекстом, не upstream-стиль)
- **Per-user billing tracker**: middleware logger в OneCLI gateway → daily report в `wiki/admin/billing-YYYY-MM-DD.md`
- **Multi-agent shared chat**: один Telegram-чат где Шахруз + Mila + Admin + sub-agents видят друг друга, оркеструются автоматом
- **Subtitles pipeline в video-shorts-factory**: ASS-стиль (TikTok-like word-level highlighting) уже работает на host'е, перенос в skill для full Mila ownership
- **Onboarding-new-user**: Mila как ментор-маркетолог с автомат парсингом IG/YT (apify), продуктовая матрица, аватарка через gpt-image-2

См. live tasks в admin-сессии Claude Code (~50 tasks tracked).

---

## Как обновляться от upstream

```bash
git fetch origin
git log --oneline migrate/v1-to-v2..origin/migrate/v1-to-v2  # что нового у upstream
git merge origin/migrate/v1-to-v2  # или rebase, по вкусу
```

На текущий момент (2026-05-05): upstream `migrate/v1-to-v2` стабилен, **0 commits behind**. Пуллить пока нечего.

---

_Файл ведётся вручную при каждом значимом коммите. Для деталей реализации каждого пункта — `git log --grep="ключевое-слово"` или прямо смотреть diff коммита из шапки секции._
