# NanoClaw Admin Panel

Лёгкая локальная панель для просмотра разговоров Милы с лидами.

## Запуск

```bash
# из корня проекта nanoclaw
source .env
npm run admin-panel
```

Откроется на http://127.0.0.1:3030 (bind только на localhost — внешнего доступа нет).

## Возможности

- `/` — список всех публичных лидов (отсортирован по последнему сообщению)
- `/lead/<jid>` — полный диалог + lead-profile из wiki + meta
- `/all` — все зарегистрированные группы (включая main, channel-promoter и т.д.)
- `⚡ Summary` кнопка в диалоге — Claude Haiku генерирует структурированный summary (кто лид, его боль, стадия воронки, что Мила сделала хорошо, что улучшить, next action)

## Требования

- `store/messages.db` — SQLite база NanoClaw (read-only)
- `ANTHROPIC_API_KEY` в `.env` — для генерации summary
- Node.js 18+ (`better-sqlite3`, `express`, `@anthropic-ai/sdk`)

## Автозапуск (опционально)

Создать `~/Library/LaunchAgents/com.nanoclaw.admin.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.nanoclaw.admin</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>cd /Users/milagpt/nanoclaw/nanoclaw && source .env && /opt/homebrew/bin/node admin-panel/server.cjs</string>
    </array>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/tmp/nanoclaw-admin.log</string>
    <key>StandardErrorPath</key><string>/tmp/nanoclaw-admin.err</string>
</dict>
</plist>
```

Затем:
```bash
launchctl load ~/Library/LaunchAgents/com.nanoclaw.admin.plist
```

## Безопасность

Панель биндится ТОЛЬКО на `127.0.0.1` — доступна только с этого компьютера.
Без auth — подразумевается что Mac закрыт паролем.

Для удалённого доступа — добавь cloudflared tunnel или ssh port-forward. Но пока не нужно по ТЗ.

## Что дальше

- Редактирование CLAUDE.md лида прямо из UI (для корректировки поведения Милы)
- Фильтрация по стадии воронки / дате
- Экспорт чатов
- Push-уведомления о новых лидах (в браузер)
