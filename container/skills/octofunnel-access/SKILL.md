---
name: octofunnel-access
description: Unified access skill для OctoFunnel платформ (ashotai.uz, farangismaster.uz, aiahmedov.uz, и т.д.). Single entry point для Воронщика — проверка auth, escalation Шахрузу при необходимости логина, shared session storage. Use BEFORE any octofunnel-* skill operation. Заменяет ad-hoc auth в creator/editor/explorer.
---

# OctoFunnel Access — единая точка входа для Воронщика

Все скиллы `octofunnel-*` (creator, editor, explorer) ДОЛЖНЫ начинать с проверки через этот skill. Если он вернул `ready` — работаем; если `needs_login` — пингуем Шахруза через admin-ipc, ждём.

## Архитектурный принцип

🎯 **Воронщик = единственный канал коммуникации с OctoFunnel** (платформа → ashotai.uz/crm и партнёрские).

Mila octo и другие Mila НЕ работают напрямую с OctoFunnel. Они дают задание Воронщику через swarm dispatch:

```
mcp__nanoclaw__send_message(
  text="Создай воронку для клиента X с такими-то параметрами",
  sender="Воронщик"
)
# или Task subagent с sender:"Воронщик"
```

Воронщик в своём subagent делает:
1. `bash /home/node/.claude/skills/octofunnel-access/access.sh <platform>` → проверка
2. Если `ready` → запускает соответствующий octofunnel-* skill
3. Если `needs_login` → admin-ipc Шахрузу с просьбой залогиниться → ждёт
4. Возвращает результат

Это убирает дублирование auth по группам, даёт единое место для troubleshooting, и Шахруз логинится один раз (а не каждый раз когда новая Mila приходит).

## Платформы — реестр

`config.json` содержит API-secrets per-platform в `octofunnel.platforms.<domain>.secret`:

| Domain | Owner | API secret в config | Browser login |
|---|---|---|---|
| ashotai.uz | Шахруз | `kvzdcugjwfty34ngowvcz7e2k7bmo` (`ashotai.uz/crm/php/file/api.php`) | <логин Шахруза> |
| liliastrategy.uz | Лилия Полина | `rpsjiacaqts7pb2sdgwrwk76txgg2i` | TBD |
| farangismaster.uz | Фарангиз | `vhfsrysimkrev...` | TBD |
| aiahmedov.uz | Ahmedov | `poeo4vaw54wav...` | TBD |

Browser sessions хранятся в `/workspace/global/octofunnel-auth/<domain>.json` (shared mount, не per-group).

## access.sh

```bash
bash /home/node/.claude/skills/octofunnel-access/access.sh <platform-domain>
```

Where `<platform-domain>` = `ashotai.uz` / `liliastrategy.uz` / etc.

Output JSON:
```json
{
  "status": "ready|needs_login|truly_expired|error",
  "platform": "ashotai.uz",
  "session_path": "/workspace/global/octofunnel-auth/ashotai.uz.json",
  "session_age_h": 12,
  "api_secret_present": true,
  "admin_ipc_req_id": "req-..."  // если needs_login
}
```

Algorithm:
1. Проверить наличие session файла в `/workspace/global/octofunnel-auth/<platform>.json`
2. Если нет → status=`needs_login`, отправить admin-ipc Шахрузу
3. Если есть → quick session probe (HTTP HEAD на admin URL с session cookies) → если 200 → ready; если 302/401 → expired
4. Дедупликация: один admin-ipc per 30 минут на одну платформу

## Как Шахруз логинится (one-time per платформа)

Когда access.sh вернул `needs_login`, Шахруз получает Telegram сообщение от admin-ipc:

> «Для работы с воронками `<platform>` нужен ваш login. Откройте https://`<platform>`/crm в браузере, залогиньтесь, потом ответьте «готово» в Telegram».

После этого mila-admin (Claude Code на host):
1. Запускает helper script на host: `bash scripts/save-octofunnel-auth.sh <platform>`
2. Скрипт открывает headed browser → ждёт Шахруза → когда он подтвердит → сохраняет cookies в `/workspace/global/octofunnel-auth/<platform>.json`
3. Подтверждает в admin-ipc → Воронщик retry'ит → ready → работает

Helper TBD — пока создан стаб ниже.

## API-only path (для read-only операций — будущее)

Для некоторых операций (получить список воронок, проверить статус, читать leads) API ключ из `config.json` `metafunnels_api_key` достаточен. Они не требуют browser login. Скиллы могут пробовать API сначала, fallback на browser если не хватает функциональности.

API endpoint pattern (приблизительно):
```bash
curl -s -H "Authorization: Bearer $METAFUNNELS_API_KEY" \
  "https://ashotai.uz/api/v1/funnels"
```

(точный endpoint узнаём из ashotai.uz documentation — TBD)

## Anti-patterns

❌ НЕ открывать ashotai.uz/crm напрямую через agent-browser в любой Mila — кроме Воронщика. Каждая такая попытка → race condition + просьба «логин/пароль» Шахрузу.

❌ НЕ копировать auth между группами вручную — используй shared `/workspace/global/octofunnel-auth/`.

❌ НЕ автоматически re-логиниться при первом 302/401 — escalate через admin-ipc, Шахруз решает.

## Используется в

- `octofunnel-creator` — должен делать `octofunnel-access` pre-flight
- `octofunnel-editor` — то же
- `octofunnel-explorer` — то же
- Любой новый octofunnel-* skill — начинать с него
