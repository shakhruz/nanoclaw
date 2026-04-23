---
name: admin-ipc
description: Request an action from mila-admin (Claude Code session on Shakhruz's laptop) — for host-CLI operations (publish, deploy), financial transactions, integrations, or any action requiring human approval. Use when a subagent needs something that it can't do itself but the admin can.
version: 1.0.0
---

# admin-ipc — канал к mila-admin (Claude Code)

Протокол «сабагент → mila-admin → ответ обратно». Используется когда тебе нужно host-level действие (publish, deploy), разрешение Шахруза на трату бюджета/опасное действие, или доступ к внешнему сервису которого у тебя нет.

## Shared state

```
/workspace/global/admin-ipc/
├── requests/<req-id>.json     ← ты пишешь
├── responses/<req-id>.json    ← mila-admin отвечает
└── ledger.jsonl                ← аудит всего
```

## Когда использовать

**Используй:**
- Запуск действия которое ты не можешь сама (нет CLI/креденшалов) — `web_deploy`, `install_integration`, `spend_ads_budget`
- Нужно явное разрешение Шахруза для чувствительного действия (отправка финального сообщения клиенту, удаление данных, публикация под его именем)
- Результат нужен прежде чем ты можешь продолжить работу

**НЕ используй:**
- Для того что можешь сделать сама (у client-profiler есть `publish-client-doc-api.sh` — шли запрос только если твой прямой путь сломался)
- Для «сообщи Шахрузу что X» — это `mcp__nanoclaw__send_message`
- Для быстрых read-only операций

## Алгоритм

### 1. Создать запрос

```bash
RESULT=$(/home/node/.claude/skills/admin-ipc/admin-request.sh \
  <action_type> \
  '<json-params>' \
  "краткое обоснование (почему нужно, что за контекст)")

REQ_ID=$(echo "$RESULT" | jq -r .request_id)
```

### 2. Опционально — запланируй wake-check

Если ответа нет в ближайшие секунды, поставь scheduled_task через `mcp__nanoclaw__schedule_task`:
```
prompt: "Проверь /workspace/global/admin-ipc/responses/<REQ_ID>.json. Если готов — продолжи работу из контекста <описание>. Если нет — подожди ещё 10 мин и снова проверь."
schedule_type: one-time
schedule_value: +60 sec
```

### 3. Либо — ждать прямо сейчас

```bash
RESPONSE=$(/home/node/.claude/skills/admin-ipc/admin-await.sh "$REQ_ID" 300)
STATE=$(echo "$RESPONSE" | jq -r .state)
```

`admin-await.sh` поллит с exponential backoff до timeout (дефолт 300 сек). Возвращает JSON с `state`: `success | denied | failure | timeout`.

### 4. Обработай ответ

- `success` → в `result.*` лежат данные, продолжай
- `denied` → Шахруз отказал, в `notes` объяснение. Не ретрай автоматически, доложи пользователю
- `failure` → была ошибка на стороне mila-admin, посмотри `notes`
- `timeout` → никто не ответил, твой запрос всё ещё в очереди. Либо подожди ещё (создай новый wake-task), либо доложи пользователю

## Action types (white-list — что umеет mila-admin)

| action | params обязательные | auto-approve? | кто исполняет |
|---|---|---|---|
| `ping` | `{}` | ✅ | test-action, возвращает "pong" |
| `publish_client_doc` | `client, doc_type, title, draft_path, note` | ✅ | publish-client-doc.sh |
| `publish_web_article` | `type, slug, html_path` | ✅ | publish-html.sh |
| `web_deploy` | `slug` (из реестра) | ❌ спрашивает | vercel --prod |
| `send_message_to_client` | `client_slug, text, channel` | ❌ | Шахруз подтверждает |
| `spend_ads_budget` | `amount, currency, purpose` | ❌ | Шахруз подтверждает |
| `install_integration` | `service, scope` | ❌ | Шахруз одобряет |
| `modify_nanoclaw_config` | `change_description` | ❌ | Шахруз одобряет |

Если action не в white-list — mila-admin попросит Шахруза подтвердить (все незнакомые действия по умолчанию high-risk).

## Примеры

### Deploy сайта
```bash
PARAMS='{"slug":"ashotai"}'
REQ=$(/home/node/.claude/skills/admin-ipc/admin-request.sh \
  web_deploy "$PARAMS" "Поменял hero-секцию, нужно деплой")
REQ_ID=$(echo "$REQ" | jq -r .request_id)

# Планируй wake-check через 2 минуты
# ... schedule_task ...

# В следующем wake:
RESPONSE=$(/home/node/.claude/skills/admin-ipc/admin-await.sh "$REQ_ID" 5)
echo "$RESPONSE" | jq .
```

### Ping (для проверки что канал работает)
```bash
REQ=$(/home/node/.claude/skills/admin-ipc/admin-request.sh ping '{}' "smoke test")
sleep 5
cat /workspace/global/admin-ipc/responses/$(echo "$REQ" | jq -r .request_id).json
```

## Правила

- **Не блокируй контейнер на 5+ минут ожидания.** Если делаешь scheduled_task — пусть wake-check будет отдельным заходом.
- **Один запрос = одно действие.** Не батч-запросы.
- **Justification обязательно** — mila-admin и Шахруз должны понимать зачем.
- **Не кидай секреты в params** — файлы/ссылки, а не сами токены.
- **Идемпотентность:** если вдруг создашь один и тот же request повторно, mila-admin увидит дубль и вернёт кэш.
- **Чувствительные действия** (денежные, удаления) — mila-admin в любом случае спросит Шахруза, не бойся запрашивать.
