---
name: octofunnel-api
description: HTTP API wrapper для OctoFunnel платформ (ashotai.uz, liliastrategy.uz, etc). Заменяет browser-based octofunnel-creator/editor/explorer для большинства операций — list/get/create/update funnels, clients, blocks, payment analytics. Read API docs https://octofunnel.com/docs/. Use это вместо open browser когда задача — read/write data through API. Для visual edits и UI-интеракций оставайся на browser-skills.
---

# OctoFunnel API Wrapper

Universal CLI wrapper для OctoFunnel REST API. Воронщик использует этот skill для большинства операций — без cookies, без browser, без 2FA challenges.

## Когда API vs Browser

| Задача | API (этот skill) | Browser (octofunnel-editor/creator) |
|---|---|---|
| Получить список воронок | ✅ `funnels_list` | — |
| Создать воронку | ✅ `funnels_create` | альтернативно через ОКТО chat |
| Обновить content воронки | ✅ `blocks_update` | для сложных UI правок |
| Получить leads/clients | ✅ `clients_list/get/search` | — |
| Отправить сообщение клиенту | ✅ `clients_send_message` | — |
| Аналитика payments | ✅ `payment_analytics_*` | — |
| Визуальное редактирование (drag-drop, layouts) | — | ✅ через ОКТО chat |
| Загрузка изображений в галерею | возможно через blocks API | ✅ через UI |

**Default — пробуй API первым.** Если возможности не хватает — fallback на browser skill.

## Использование

```bash
bash /home/node/.claude/skills/octofunnel-api/call.sh <platform> <GET|POST> <endpoint> [params]
```

Примеры:

```bash
# Список всех воронок на ashotai.uz
bash call.sh ashotai.uz GET funnels_list

# Получить детали воронки id=16 (AI Business)
bash call.sh ashotai.uz GET funnels_get id=16

# Создать новую воронку
bash call.sh ashotai.uz POST funnels_create name="Workshop launch May 15"

# Список клиентов с пагинацией
bash call.sh ashotai.uz GET clients_list limit=50 offset=0

# Найти клиента по email
bash call.sh ashotai.uz GET clients_search query="ivan@example.com"

# Отправить сообщение клиенту
bash call.sh ashotai.uz POST clients_send_message client_id=123 text="Привет!"

# Дневная статистика платежей
bash call.sh ashotai.uz GET payment_analytics_daily_revenue from=2026-04-01 to=2026-04-26

# На клиентской платформе Лили
bash call.sh liliastrategy.uz GET funnels_list
```

## Auth resolution

Skill сам находит API secret:
1. `/workspace/group/config.json:octofunnel.platforms.<domain>.secret` — приоритет
2. `/workspace/global/octofunnel-config.json:platforms.<domain>.secret` — fallback (shared между группами)

Если secret отсутствует → JSON error с описанием куда положить.

## Endpoints (cheat sheet — полная дока https://octofunnel.com/docs/)

### Funnels
- `funnels_list` — все воронки
- `funnels_get?id=X` — одна воронка
- `funnels_create` POST — name=...
- `funnels_update` POST — id=... + поля
- `funnels_delete` POST — id=... + confirm=1

### Clients (leads / contacts)
- `clients_list` — все, с limit/offset
- `clients_get?id=X` — один клиент
- `clients_search?query=...` — поиск
- `clients_create` POST — email, name, phone, ...
- `clients_update` POST — id + поля
- `clients_send_message` POST — client_id + text

### Blocks (контент воронки)
- `blocks_list?funnel_id=X` — блоки воронки
- `blocks_types` — справочник типов
- `blocks_create` POST
- `blocks_update` POST — id + content + ...

### Analytics
- `payment_analytics_revenue_summary`
- `payment_analytics_all`
- `payment_analytics_customers`
- `payment_analytics_daily_revenue` ?from=YYYY-MM-DD&to=YYYY-MM-DD

## Rate limit

600 req/60sec на IP (per OctoFunnel docs). Для нашего объёма с большим запасом. Если Воронщик делает batch — добавляй sleep между запросами.

## Output

Raw JSON на stdout. Pипай через jq:

```bash
COUNT=$(bash call.sh ashotai.uz GET funnels_list | jq -r '.count')
NAMES=$(bash call.sh ashotai.uz GET funnels_list | jq -r '.funnels[].name')
```

Стандартный формат ответа:
- ✅ Success: `{"ok":1, ...payload}`
- ❌ Error: `{"error":1, "description":"..."}`

## Workflow для Воронщика

```
Mila octo / partners / clients / instagram → дёргает Task subagent с sender:"Воронщик"
prompt:
  Задача: получить список активных воронок ashotai.uz и отправить summary в чат

Воронщик:
1. bash /home/node/.claude/skills/octofunnel-access/access.sh ashotai.uz
   → status=ready (потому что API secret есть в config)
2. bash /home/node/.claude/skills/octofunnel-api/call.sh ashotai.uz GET funnels_list
   → JSON с воронками
3. Форматирует summary
4. send_message(text="...", sender="Воронщик")
```

Никаких login/2FA challenges. Никаких race conditions. Никаких сcsons expirations.

## Если API не покрывает — browser fallback

Если Воронщику нужно сделать что-то не доступное через API (например тонкая UI-настройка через ОКТО chat) — тогда:
1. access.sh с НЕТ API config → status=needs_login
2. Шахруз через admin-ipc даст browser session
3. Открывает octofunnel-editor / explorer (browser-based)

Это редкий fallback path. По умолчанию — API.
