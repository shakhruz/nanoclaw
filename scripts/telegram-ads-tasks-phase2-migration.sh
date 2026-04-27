#!/usr/bin/env bash
# Phase 2 migration: scheduled-tasks for the full Telegram Ads suite (2026-04-22)
#
# Adds/updates:
#   1. UPDATE  task-1776472572612-w6wn7n (channel-promoter daily 09:00 1-5)
#      → use canonical helpers, no false-positive on session quirks
#   2. INSERT  task-ads-daily-snapshot-2026-04-22 (cron 30 23 * * *)
#      → copy cache.json → history/YYYY-MM-DD.json (for trend analysis)
#   3. INSERT  task-ads-weekly-report-2026-04-22 (cron 0 19 * * 0)
#      → run telegram-ads-analyze, send weekly performance report
#   4. INSERT  task-ads-budget-alert-2026-04-22 (cron 0 9,15 * * *)
#      → script-gated wake — only fires if balance < 3 TON
#
# All prompts live in scripts/telegram-ads-tasks-migration-2026-04-22-prompts/
# Re-runnable: each operation is INSERT-OR-REPLACE (DELETE existing then INSERT).
#
# Run from repo root:
#   bash scripts/telegram-ads-tasks-phase2-migration.sh

set -eu

DB="${DB:-$(pwd)/store/messages.db}"
PROMPTS_DIR="$(cd "$(dirname "$0")" && pwd)/telegram-ads-tasks-migration-2026-04-22-prompts"

if [ ! -f "$DB" ]; then
  echo "ERROR: messages.db not found at $DB" >&2
  exit 1
fi

required_files="channel-promoter-daily.txt daily-snapshot.txt weekly-report.txt budget-alert.txt budget-alert-script.sh"
for f in $required_files; do
  if [ ! -f "$PROMPTS_DIR/$f" ]; then
    echo "ERROR: missing prompt file $PROMPTS_DIR/$f" >&2
    exit 1
  fi
done

echo "→ DB: $DB"
echo "→ Prompts dir: $PROMPTS_DIR"
echo ""
read -rp "Proceed with Phase 2 migration? [y/N] " ans
case "$ans" in [yY]|[yY][eE][sS]) ;; *) echo "aborted"; exit 0;; esac

NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# 1. UPDATE channel-promoter daily prompt
echo "→ Updating task-1776472572612-w6wn7n (channel-promoter daily)..."
sqlite3 "$DB" "UPDATE scheduled_tasks SET prompt=CAST(readfile('$PROMPTS_DIR/channel-promoter-daily.txt') AS TEXT) WHERE id='task-1776472572612-w6wn7n'"

# 2. INSERT daily snapshot task
echo "→ Inserting task-ads-daily-snapshot-2026-04-22..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-ads-daily-snapshot-2026-04-22'"
sqlite3 "$DB" "INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode) VALUES ('task-ads-daily-snapshot-2026-04-22', 'telegram_main', 'tg:33823108', CAST(readfile('$PROMPTS_DIR/daily-snapshot.txt') AS TEXT), 'cron', '30 23 * * *', '2026-04-22T23:30:00.000+05:00', 'active', '$NOW_ISO', 'isolated')"

# 3. INSERT weekly report task
echo "→ Inserting task-ads-weekly-report-2026-04-22..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-ads-weekly-report-2026-04-22'"
sqlite3 "$DB" "INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode) VALUES ('task-ads-weekly-report-2026-04-22', 'telegram_main', 'tg:33823108', CAST(readfile('$PROMPTS_DIR/weekly-report.txt') AS TEXT), 'cron', '0 19 * * 0', '2026-04-26T19:00:00.000+05:00', 'active', '$NOW_ISO', 'isolated')"

# 4. INSERT budget alert (script-gated)
echo "→ Inserting task-ads-budget-alert-2026-04-22 (with script gate)..."
sqlite3 "$DB" "DELETE FROM scheduled_tasks WHERE id='task-ads-budget-alert-2026-04-22'"
sqlite3 "$DB" "INSERT INTO scheduled_tasks (id, group_folder, chat_jid, prompt, schedule_type, schedule_value, next_run, status, created_at, context_mode, script) VALUES ('task-ads-budget-alert-2026-04-22', 'telegram_main', 'tg:33823108', CAST(readfile('$PROMPTS_DIR/budget-alert.txt') AS TEXT), 'cron', '0 9,15 * * *', '2026-04-23T09:00:00.000+05:00', 'active', '$NOW_ISO', 'isolated', CAST(readfile('$PROMPTS_DIR/budget-alert-script.sh') AS TEXT))"

echo ""
echo "→ Final telegram-ads task state:"
sqlite3 "$DB" "SELECT id, schedule_value, status, length(prompt) AS chars FROM scheduled_tasks WHERE id IN ('task-1776472572612-w6wn7n','task-ads-daily-snapshot-2026-04-22','task-ads-weekly-report-2026-04-22','task-ads-budget-alert-2026-04-22','task-keepalive-1776389523000-ads','task-ads-monthly-healthcheck-2026-04-22') ORDER BY id"

echo ""
echo "✅ Phase 2 migration complete. Restart NanoClaw to pick up the new schedules:"
echo "   launchctl kickstart -k gui/\$(id -u)/com.nanoclaw"
