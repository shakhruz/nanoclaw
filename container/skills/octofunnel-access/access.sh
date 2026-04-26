#!/usr/bin/env bash
# octofunnel-access/access.sh — pre-flight для работы с любой OctoFunnel платформой
#
# Output JSON: status, platform, session_path, session_age_h, api_secret_present, admin_ipc_req_id
# Exit 0 always (status в JSON). Caller обрабатывает status.

set -eu

PLATFORM="${1:?usage: access.sh <platform-domain> (e.g. ashotai.uz)}"

# Validate domain format
if ! [[ "$PLATFORM" =~ ^[a-z0-9][a-z0-9.-]+$ ]]; then
  jq -n --arg p "$PLATFORM" '{status:"error", platform:$p, reason:"invalid domain format"}'
  exit 0
fi

SHARED_AUTH=/workspace/global/octofunnel-auth
SESSION_FILE="$SHARED_AUTH/$PLATFORM.json"
PENDING_FILE="$SHARED_AUTH/.pending-$PLATFORM.json"
ADMIN_IPC=/home/node/.claude/skills/admin-ipc
GROUP_CONFIG=/workspace/group/config.json

mkdir -p "$SHARED_AUTH"

# Check API secret presence — group config OR shared global
HAS_API="false"
SECRET=""
if [ -f "$GROUP_CONFIG" ]; then
  SECRET=$(jq -r ".octofunnel.platforms.\"$PLATFORM\".secret // empty" "$GROUP_CONFIG" 2>/dev/null || echo "")
fi
if [ -z "$SECRET" ] && [ -f /workspace/global/octofunnel-config.json ]; then
  SECRET=$(jq -r ".platforms.\"$PLATFORM\".secret // empty" /workspace/global/octofunnel-config.json 2>/dev/null || echo "")
fi
[ -n "$SECRET" ] && HAS_API="true"

emit() {
  jq -n \
    --arg s "$1" \
    --arg p "$PLATFORM" \
    --arg sp "$SESSION_FILE" \
    --arg age "${2:-}" \
    --arg api "$HAS_API" \
    --arg req "${3:-}" \
    --arg reason "${4:-}" \
    '{
      status: $s,
      platform: $p,
      session_path: $sp,
      session_age_h: (if $age=="" then null else ($age|tonumber) end),
      api_secret_present: ($api == "true"),
      admin_ipc_req_id: (if $req=="" then null else $req end),
      reason: (if $reason=="" then null else $reason end)
    }'
}

# PRIMARY PATH: API key (preferred — no browser, no session expiry)
# Воронщик через `octofunnel-api/call.sh` использует API directly. Browser session
# нужна только если конкретная операция не поддерживается через API (rare).
if [ "$HAS_API" = "true" ]; then
  emit "ready" "0" "" "API path active (secret in config — see octofunnel-api skill)"
  exit 0
fi

# FALLBACK PATH: browser session (только если API secret отсутствует)
# Step 1 — session file existence
if [ ! -f "$SESSION_FILE" ]; then
  # Дедупликация — не пинговать > 1 раз / 30 мин
  if [ -f "$PENDING_FILE" ]; then
    LAST_TS=$(jq -r .ts "$PENDING_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DIFF=$(( NOW - LAST_TS ))
    if [ "$DIFF" -lt 1800 ]; then
      EXISTING_REQ=$(jq -r .req_id "$PENDING_FILE" 2>/dev/null || echo "")
      emit "needs_login" "" "$EXISTING_REQ" "Already pending (created $((DIFF/60))m ago)"
      exit 0
    fi
  fi

  REQ_ID="req-$(date +%Y%m%d-%H%M%S)-octo$(openssl rand -hex 3 2>/dev/null || echo "abcdef")"
  if [ -x "$ADMIN_IPC/admin-request.sh" ]; then
    "$ADMIN_IPC/admin-request.sh" \
      "octofunnel_login_needed" \
      "{\"platform\":\"$PLATFORM\",\"crm_url\":\"https://$PLATFORM/crm\",\"req_id\":\"$REQ_ID\"}" \
      "Воронщику нужен ваш login на https://$PLATFORM/crm. Откройте в браузере, залогиньтесь, потом ответьте 'готово' в этом чате — mila-admin сохранит сессию в shared." 2>/dev/null || true
  fi

  echo "{\"ts\":$(date +%s),\"req_id\":\"$REQ_ID\"}" > "$PENDING_FILE"
  emit "needs_login" "" "$REQ_ID" "Session file missing, admin-ipc sent to Shakhruz"
  exit 0
fi

# Step 2 — session age
NOW=$(date +%s)
SESSION_MTIME=$(stat -c %Y "$SESSION_FILE" 2>/dev/null || stat -f %m "$SESSION_FILE" 2>/dev/null || echo "$NOW")
AGE_S=$(( NOW - SESSION_MTIME ))
AGE_H=$(( AGE_S / 3600 ))

# Если session > 14 дней — стоит обновить (но всё ещё ready, Воронщик может попробовать)
if [ $AGE_S -gt 1209600 ]; then  # 14 days
  emit "ready" "$AGE_H" "" "Session > 14 days old, may need refresh soon"
  exit 0
fi

# Step 3 — could probe live URL here, but skip for now (сложно без actual browser tool from bash)
# Воронщик сам обнаружит expired через open() и повторит access.sh после удаления session file
emit "ready" "$AGE_H" "" ""
