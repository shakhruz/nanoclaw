#!/usr/bin/env bash
# Web-projects scheduled-tasks migration (2026-04-23)
#
# Adds:
#   1. task-web-weekly-inventory-2026-04-23 (cron 0 20 * * 0 — Sunday 20:00 Tashkent)
#      → refresh inventory, report orphans
#   2. task-web-daily-domain-health-2026-04-23 (cron 30 9 * * * — 09:30 Tashkent)
#      → curl-ping all custom domains, alert if ≥1 dead (with 24h dedupe)
#
# Run from repo root:
#   bash scripts/web-tasks-migration-2026-04-23.sh

set -eu

DB="${DB:-$(pwd)/store/messages.db}"
PROMPTS_DIR="$(cd "$(dirname "$0")" && pwd)/web-tasks-migration-2026-04-23-prompts"

if [ ! -f "$DB" ]; then
  echo "ERROR: messages.db not found at $DB" >&2
  exit 1
fi

for f in weekly-inventory.txt domain-health.txt; do
  [ -f "$PROMPTS_DIR/$f" ] || { echo "ERROR: missing $PROMPTS_DIR/$f" >&2; exit 1; }
done

echo "→ DB: $DB"
echo "→ Prompts: $PROMPTS_DIR"
echo ""
read -rp "Proceed with web-tasks migration? [y/N] " ans
case "$ans" in [yY]|[yY][eE][sS]) ;; *) echo "aborted"; exit 0;; esac

NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# 1. Weekly inventory refresh — Sunday 20:00 Tashkent
echo "→ Inserting task-web-weekly-inventory-2026-04-23..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-web-weekly-inventory-2026-04-23'"
sqlite3 "$DB" "INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode) VALUES ('task-web-weekly-inventory-2026-04-23', 'telegram_main', 'tg:33823108', CAST(readfile('$PROMPTS_DIR/weekly-inventory.txt') AS TEXT), 'cron', '0 20 * * 0', '2026-04-26T20:00:00.000+05:00', 'active', '$NOW_ISO', 'isolated')"

# 2. Daily domain health — 09:30 Tashkent
echo "→ Inserting task-web-daily-domain-health-2026-04-23..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-web-daily-domain-health-2026-04-23'"
sqlite3 "$DB" "INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode) VALUES ('task-web-daily-domain-health-2026-04-23', 'telegram_main', 'tg:33823108', CAST(readfile('$PROMPTS_DIR/domain-health.txt') AS TEXT), 'cron', '30 9 * * *', '2026-04-24T09:30:00.000+05:00', 'active', '$NOW_ISO', 'isolated')"

echo ""
echo "→ Final web-tasks state:"
sqlite3 "$DB" "SELECT id, schedule_value, status, length(prompt) AS chars FROM scheduled_tasks WHERE id LIKE 'task-web-%' ORDER BY id"

echo ""
echo "✅ Web-tasks migration complete. Restart NanoClaw to pick up:"
echo "   launchctl kickstart -k gui/\$(id -u)/com.nanoclaw"
