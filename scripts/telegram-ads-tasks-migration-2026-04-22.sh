#!/usr/bin/env bash
# Migration: Telegram Ads scheduled-tasks consolidation (2026-04-22)
#
# REMOVES the two false-positive tasks that caused daily "session expired" alerts
# when cookies are actually valid until 2027-04-20:
#   1. task-1776346282705-rrv7dr  — legacy */30 with agent-browser state load workaround
#   2. task-1776274760849-x3y56t  — "telemetry-first" 0 7,11,15,19 that alerted without verify
#
# UPDATES the existing keepalive task to use the new canonical helpers.
# ADDS a monthly deep session-check task (1st of each month, 10:00 Tashkent).
#
# Before running:
#   - Backup saved to groups/telegram_main/.scheduled-tasks-backup/removed-2026-04-22.json (already exists)
#   - Old tasks will be lost (the backup lets you restore by hand if needed)
#
# Run from repo root:
#   bash scripts/telegram-ads-tasks-migration-2026-04-22.sh

set -eu

DB="${DB:-$(pwd)/store/messages.db}"
BACKUP_DIR="$(pwd)/groups/telegram_main/.scheduled-tasks-backup"

if [ ! -f "$DB" ]; then
  echo "ERROR: messages.db not found at $DB" >&2
  exit 1
fi

if [ ! -f "$BACKUP_DIR/removed-2026-04-22.json" ]; then
  echo "ERROR: backup file missing; re-run the earlier backup step before migration" >&2
  exit 1
fi

echo "→ Using DB: $DB"
echo "→ Backup present at: $BACKUP_DIR/removed-2026-04-22.json"
echo ""
echo "→ Current tasks matching 'telegram-ads' or 'ads.telegram':"
sqlite3 "$DB" "SELECT id, schedule_value, status FROM scheduled_tasks WHERE prompt LIKE '%telegram-ads%' OR prompt LIKE '%ads.telegram%' OR prompt LIKE '%keepalive%ads%'"
echo ""

read -rp "Proceed with migration? [y/N] " ans
case "$ans" in
  [yY]|[yY][eE][sS]) ;;
  *) echo "aborted"; exit 0;;
esac

echo ""
echo "→ Deleting task-1776346282705-rrv7dr (*/30 legacy)..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-1776346282705-rrv7dr'"

echo "→ Deleting task-1776274760849-x3y56t (0 7,11,15,19 telemetry-first)..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-1776274760849-x3y56t'"

PROMPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts/telegram-ads-tasks-migration-2026-04-22-prompts"
mkdir -p "$PROMPTS_DIR"
KEEPALIVE_PROMPT_FILE="$PROMPTS_DIR/keepalive.txt"
MONTHLY_PROMPT_FILE="$PROMPTS_DIR/monthly-healthcheck.txt"

if [ ! -f "$KEEPALIVE_PROMPT_FILE" ] || [ ! -f "$MONTHLY_PROMPT_FILE" ]; then
  echo "ERROR: prompt files missing in $PROMPTS_DIR — this script requires the prompts alongside it" >&2
  exit 1
fi

echo "→ Updating keepalive prompt (task-keepalive-1776389523000-ads)..."
sqlite3 "$DB" "UPDATE scheduled_tasks SET prompt=CAST(readfile('$KEEPALIVE_PROMPT_FILE') AS TEXT) WHERE id='task-keepalive-1776389523000-ads'"

echo "→ Adding (or replacing) monthly deep-check task..."
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
NEXT_RUN_ISO="2026-05-01T10:00:00.000+05:00"
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-ads-monthly-healthcheck-2026-04-22'"
sqlite3 "$DB" "INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode) VALUES ('task-ads-monthly-healthcheck-2026-04-22', 'telegram_main', 'tg:33823108', CAST(readfile('$MONTHLY_PROMPT_FILE') AS TEXT), 'cron', '0 10 1 * *', '$NEXT_RUN_ISO', 'active', '$NOW_ISO', 'isolated')"

echo ""
echo "→ Final state — current telegram-ads-related tasks:"
sqlite3 "$DB" "SELECT id, schedule_value, status FROM scheduled_tasks WHERE prompt LIKE '%telegram-ads%' OR prompt LIKE '%ads.telegram%' OR prompt LIKE '%keepalive%ads%' OR id LIKE '%monthly-healthcheck%'"

echo ""
echo "✅ Migration complete. Restart the NanoClaw service so the scheduler picks up changes:"
echo "   launchctl kickstart -k gui/\$(id -u)/com.nanoclaw"
