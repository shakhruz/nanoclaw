#!/usr/bin/env bash
# common.sh — shared bash helpers for telegram-ads-* skills
#
# Source this file: . "$(dirname "$0")/common.sh"
# (or absolute:      . /home/node/.claude/skills/telegram-ads-session/common.sh)

# State directory — shared across main + MILA groups via /workspace/global mount
TG_ADS_STATE_DIR="${TG_ADS_STATE_DIR:-/workspace/global/telegram-ads}"
TG_ADS_SESSION_FILE="$TG_ADS_STATE_DIR/session.json"
TG_ADS_CACHE_FILE="$TG_ADS_STATE_DIR/cache.json"
TG_ADS_HISTORY_DIR="$TG_ADS_STATE_DIR/history"

# Ensure state tree exists
tg_ads_init_state() {
  mkdir -p "$TG_ADS_STATE_DIR" "$TG_ADS_HISTORY_DIR" "$TG_ADS_STATE_DIR/creatives" "$TG_ADS_STATE_DIR/research"
}

# Write session.json atomically.
# Usage: tg_ads_write_session <status> <source> [error_message]
#   status: alive | expired | unknown
#   source: name of the caller (skill or script), for history trail
tg_ads_write_session() {
  local status="$1"
  local source="${2:-unknown}"
  local err="${3:-}"
  tg_ads_init_state
  node --input-type=module -e "
    import fs from 'fs';
    const p = process.env.TG_ADS_SESSION_FILE;
    const now = new Date().toISOString();
    const [,, status, source, err] = process.argv;
    let d = {};
    try { d = JSON.parse(fs.readFileSync(p, 'utf8')); } catch {}
    d.last_check = now;
    d.status = status;
    if (status === 'alive') { d.last_alive = now; d.consecutive_failures = 0; d.last_error = null; }
    else { d.consecutive_failures = (d.consecutive_failures || 0) + 1; d.last_error = err || null; }
    d.history = (Array.isArray(d.history) ? d.history : []).concat([{ts: now, status, source}]).slice(-60);
    const tmp = p + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(d, null, 2));
    fs.renameSync(tmp, p);
  " _ "$status" "$source" "$err"
  export TG_ADS_SESSION_FILE
}

# Read current status. Usage: STATUS=$(tg_ads_read_status)
# Outputs: alive | expired | unknown | missing
tg_ads_read_status() {
  if [ ! -f "$TG_ADS_SESSION_FILE" ]; then
    echo "missing"
    return
  fi
  node -e "
    try { console.log(require('$TG_ADS_SESSION_FILE').status || 'unknown'); }
    catch { console.log('missing'); }
  " 2>/dev/null || echo "missing"
}

# Check whether an ISO timestamp is older than N minutes.
# Usage: tg_ads_is_stale <iso_ts> <minutes> → exits 0 if stale, 1 if fresh
tg_ads_is_stale() {
  local iso="$1"
  local minutes="$2"
  node -e "
    const iso = '$iso', mins = $minutes;
    if (!iso) process.exit(0);
    const age = (Date.now() - new Date(iso).getTime()) / 60000;
    process.exit(age > mins ? 0 : 1);
  " 2>/dev/null || return 0
}

# Export paths to callers that source this file
export TG_ADS_STATE_DIR TG_ADS_SESSION_FILE TG_ADS_CACHE_FILE TG_ADS_HISTORY_DIR
