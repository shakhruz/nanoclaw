#!/usr/bin/env bash
# with-lock.sh — serialize Telegram Ads write operations across MILA containers
#
# Wraps a command in flock(1) on the shared lock file. Prevents two containers
# (main + channel-promoter, for example) from writing to ads.telegram.org or
# the cookie file simultaneously, which could corrupt session state.
#
# Usage:
#   with-lock.sh <command> [args...]
#   WITH_LOCK_TIMEOUT=180 with-lock.sh <command> [args...]
#
# Lock file: /workspace/global/telegram-ads/.lock
# Timeout: 120 seconds by default (waits that long for another holder to finish)
# If timeout expires → exits 75 (EX_TEMPFAIL) — caller decides whether to retry or abort.

set -eu

LOCK_DIR="${TG_ADS_STATE_DIR:-/workspace/global/telegram-ads}"
LOCK_FILE="$LOCK_DIR/.lock"
TIMEOUT="${WITH_LOCK_TIMEOUT:-120}"

mkdir -p "$LOCK_DIR"
touch "$LOCK_FILE"

if [ $# -eq 0 ]; then
  echo "usage: with-lock.sh <command> [args...]" >&2
  exit 2
fi

# -x = exclusive lock; -w = wait up to N seconds; fd 9 = the lock file
if ! command -v flock >/dev/null 2>&1; then
  # Fallback for systems without flock: use a best-effort atomic mkdir
  FALLBACK_LOCK="$LOCK_DIR/.lock.d"
  SECONDS_WAITED=0
  until mkdir "$FALLBACK_LOCK" 2>/dev/null; do
    if [ "$SECONDS_WAITED" -ge "$TIMEOUT" ]; then
      echo "with-lock: timeout ${TIMEOUT}s waiting for $FALLBACK_LOCK" >&2
      exit 75
    fi
    sleep 1
    SECONDS_WAITED=$((SECONDS_WAITED + 1))
  done
  trap 'rmdir "$FALLBACK_LOCK" 2>/dev/null || true' EXIT
  "$@"
  RC=$?
  exit $RC
fi

exec 9> "$LOCK_FILE"
if ! flock -x -w "$TIMEOUT" 9; then
  echo "with-lock: timeout ${TIMEOUT}s waiting for $LOCK_FILE" >&2
  exit 75
fi

"$@"
