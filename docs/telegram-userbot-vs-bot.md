# Telegram: userbot vs официальный бот — контракт и каталог тулз

**Кому это:** автору нового Telegram-скилла, или агенту, который получил ambiguous-задачу про Telegram, не подходящую ни под один существующий скилл. **Не для runtime-консультации перед каждым действием** — в существующих скиллах решение уже зашито.

---

## Два пути в Telegram

| | **Userbot — `telegram-scanner` MCP** | **Официальный бот — `mcp__nanoclaw__*`** |
|---|---|---|
| **Identity** | `@ashot_ashirov_ai` (Ashot Ashirov AI), Premium, личный аккаунт | `@mila_gpt_bot` (Мила GPT \| ИИ Маркетолог) |
| **Транспорт** | MTProto через Telethon, локальный сервис на 127.0.0.1:3002 | Bot API через nanoclaw channel adapter |
| **Endpoint для контейнеров** | `host.containers.internal:3002/mcp` (Apple) / `host.docker.internal:3002/mcp` (Docker) | внутренний vs core nanoclaw |
| **Лимиты** | без лимита размера медиа; FloodWait по правилам user-аккаунта | 20MB на скачку; rate-limit Bot API |
| **Когда использовать** | админские операции в каналах, лидген, скрейп, MTProto-загрузка >20MB, channel-stories, выставление аватаров ботам | ответы пользователям воронки в DM/группах, callback_query, inline keyboard |

### Решающее правило

- **Получатель — клиент Милы или подписчик воронки** → официальный `@mila_gpt_bot`. Они подписались на бот, ждут от него ответа. Userbot тут — самозванец.
- **Получатель — широкая аудитория канала** (публикация, story, pin, forward) → userbot. Он админ, он публикует.
- **Операция — над инфраструктурой Telegram** (subscribe, list_chats, get_user_profile, set_bot_avatar, get_channel_admins) → userbot. Bot API таких операций не даёт.
- **Скачать большой файл** (видео, voice >20MB, документ из лида) → userbot (`download_media`). Bot API режет на 20MB.
- **Ambiguous лидген** (узнать профиль человека до контакта) → userbot, через `get_user_profile`.

### Identity disclosure

Когда userbot пишет DM (`send_dm`) или публикует в канале — это видно как сообщение от **Ашот Аширов**, не от Милы. Если контекст требует, чтобы получатель видел Милу как отправителя — **не** используй userbot, переключайся на `mcp__nanoclaw__send_message`.

---

## Каталог тулз `telegram-scanner` (18 шт.)

### Чтение / разведка

| Тулза | Сигнатура | Use-case |
|---|---|---|
| `list_channels` | `()` | Каналы из NEWS-папки, для periodic-scan скиллов (`channel-curator`) |
| `list_my_chats` | `(limit, only_channels, only_groups)` | Все диалоги userbot'а без folder-фильтра — для discovery chat_id, аудита членства |
| `get_messages` | `(channel_username, chat_id, limit, hours)` | Свежие сообщения канала/группы за окно времени |
| `search_messages` | `(query, chat_id, channel_username, hours, limit)` | Полнотекстовый поиск по сообщениям |
| `get_channel_admins` | `(channel)` | Кто админит канал — проверка прав перед публикацией |
| `read_dm_history` | `(username, limit)` | История DM (тестирование воронок ботов) |
| `list_chat_media` | `(chat_id, limit)` | MTProto message_id для последующего `download_media` |
| `download_media` | `(chat_id, message_id, dest_dir, filename)` | Скачать файл любого размера (ответ Bot API "file too big") |
| `get_user_profile` | `(username)` | Bio, premium, verified, common_chats, last_seen — лидген, due diligence |

### Запись / действия

| Тулза | Сигнатура | Use-case |
|---|---|---|
| `subscribe_to_channel` | `(channel)` | Подписать userbot'а на новый канал (после рекомендации `channel-curator`) |
| `publish_to_channel` | `(channel, text, image_path, image_base64, disable_notification, schedule_date)` | Публикация поста в канал/группу (text + media + scheduling) |
| `publish_story` | `(text, image_path)` | Story в **user-stories** userbot'а (личный stream Ашота) |
| `publish_channel_story` | `(channel, image_path/base64, caption, privacy)` | Story **в канале** (Telegram-фича 2024, нужны права на post-stories) |
| `send_dm` | `(username, text)` | DM от лица Ашота — лидген, тестирование, межбот связь |
| `pin_message` | `(chat_id, message_id, notify, pm_oneside)` | Pin сообщения (нужны pin-rights) |
| `forward_message` | `(from_chat, message_id, to_chat, drop_author, drop_caption)` | Форвард с опциональным скрытием автора |
| `set_bot_avatar` | `(bot_username, image_path)` | Аватар своему боту через MTProto (Bot API не умеет) |

### Самонаблюдение

| Тулза | Сигнатура | Use-case |
|---|---|---|
| `get_telegram_metrics` | `()` | Per-tool counters, latency p50/p95/p99, errors, uptime — диагностика «что у userbot'а с нагрузкой» |

---

## Каталог `mcp__nanoclaw__*` (для контраста, кратко)

Идут через core nanoclaw → Bot API → @mila_gpt_bot. Подробности в `nanoclaw/v2/...` коде.

- `mcp__nanoclaw__send_message(chat_id, text, ...)` — отправить пользователю в активном `messaging_group`
- `mcp__nanoclaw__send_image`, `send_audio`, `send_video` — медиа через Bot API
- `mcp__nanoclaw__add_reaction` — реакция-эмодзи (не путать со старым именем `react_to_message`)
- `mcp__nanoclaw__delete_message`, `mcp__nanoclaw__edit_message`
- inline keyboards / callback_query — обрабатываются адаптером, скилл получает callback в нормальном flow

Если скилл **отвечает пользователю воронки** — почти всегда нужен один из этих, а не userbot.

---

## Fallback policy

Что делать, если `telegram-scanner` MCP недоступен:

1. **`set_bot_avatar`** недоступен — попросить пользователя вручную через @BotFather (`/setuserpic`). Уже реализовано в `design-avatar`.
2. **`download_media` недоступен**, файл <20MB — fallback на стандартный Bot API channel adapter
3. **`publish_to_channel` недоступен** — отдать пользователю готовый текст+медиа на ручную публикацию (не запрашивать через @mila_gpt_bot, у него нет прав в каналах Ашота)
4. **`publish_story` / `publish_channel_story` недоступны** — fallback на pinned channel post (тот же контент, но обычное сообщение с pin)
5. **`get_user_profile` недоступен** — на разведке через `read_dm_history` (если есть переписка) или поиск через `search_messages`
6. **Все остальные** — без fallback, репортить пользователю «scanner недоступен» и ждать восстановления

Проверка живости: `curl http://127.0.0.1:3002/mcp` → `400 Bad Request: Missing session ID` означает «сервис жив, просто нужен handshake». Любой `Connection refused` или таймаут — сервис лежит.

---

## Когда обратно сюда заглядывать

- **Создаю новый Telegram-скилл** — открываю этот файл, выбираю нужные тулзы, включаю их **в тело скилла напрямую** (не через ссылку на этот гид)
- **Получил ambiguous-задачу** — пользователь написал нечто Telegram-ное вне любого существующего скилла (например, «найди мне профиль @durov» в свободном диалоге). Тогда я свожу запрос к одной из тулз каталога выше
- **Diagnose health** — `get_telegram_metrics` для самопроверки

В **рутинных** запусках существующих скиллов — этот файл **не нужен**. Скилл уже знает свой путь.
