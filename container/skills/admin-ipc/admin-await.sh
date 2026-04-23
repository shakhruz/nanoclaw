#!/usr/bin/env bash
# admin-await.sh — subagent ждёт ответ на свой запрос.
#
# Usage:
#   admin-await.sh <request_id> [timeout_sec]
#
# Exit:
#   0 — ответ получен, JSON на stdout
#   1 — timeout
#   2 — ошибка (бэд request_id и т.п.)

set -eo pipefail

REQ_ID="${1:?usage: admin-await.sh <request_id> [timeout_sec]}"
TIMEOUT="${2:-300}"   # дефолт 5 мин

INBOX="${ADMIN_IPC_DIR:-/workspace/global/admin-ipc}"
RESP_FILE="$INBOX/responses/${REQ_ID}.json"

# exponential backoff: 1s → 2s → 4s → 8s → 15s (cap)
SLEEP=1
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  if [ -f "$RESP_FILE" ]; then
    cat "$RESP_FILE"
    exit 0
  fi
  sleep $SLEEP
  ELAPSED=$((ELAPSED + SLEEP))
  SLEEP=$((SLEEP * 2))
  [ $SLEEP -gt 15 ] && SLEEP=15
done

jq -n --arg id "$REQ_ID" --arg timeout "$TIMEOUT" \
  '{request_id:$id, state:"timeout", timeout_sec:($timeout|tonumber)}'
exit 1
