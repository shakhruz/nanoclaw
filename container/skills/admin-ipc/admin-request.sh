#!/usr/bin/env bash
# admin-request.sh — subagent создаёт запрос к mila-admin (Claude Code на хосте).
#
# Usage:
#   admin-request.sh <action> '<json-params>' ["justification"]
#
# Example:
#   admin-request.sh publish_client_doc '{"client":"acme-corp","doc_type":"proposal","title":"ai-director","draft_path":"/workspace/global/..."}' "После звонка 22.04"
#
# Stdout: JSON {"request_id":"req-...","request_path":"/workspace/global/admin-ipc/requests/<id>.json"}

set -eo pipefail

ACTION="${1:?usage: admin-request.sh <action> <json-params> [justification]}"
PARAMS="${2:?params json required}"
JUSTIFICATION="${3:-}"

# Валидный JSON?
echo "$PARAMS" | jq empty 2>/dev/null || { echo "err: params must be valid JSON" >&2; exit 1; }

INBOX="${ADMIN_IPC_DIR:-/workspace/global/admin-ipc}"
mkdir -p "$INBOX/requests" "$INBOX/responses"

# req-id: timestamp + 6 random chars
gen_suffix() {
  LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyz23456789' < <(head -c 128 /dev/urandom) | head -c 6
}
TS=$(date -u +"%Y%m%d-%H%M%S")
REQ_ID="req-${TS}-$(gen_suffix)"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GROUP="${NANOCLAW_GROUP:-unknown}"

REQ_FILE="$INBOX/requests/${REQ_ID}.json"

jq -n \
  --arg id "$REQ_ID" \
  --arg group "$GROUP" \
  --arg action "$ACTION" \
  --argjson params "$PARAMS" \
  --arg justification "$JUSTIFICATION" \
  --arg created "$NOW" \
  '{
    id: $id,
    requesting_group: $group,
    action: $action,
    params: $params,
    justification: $justification,
    state: "pending",
    created_at: $created
  }' > "$REQ_FILE"

jq -c -n --arg id "$REQ_ID" --arg path "$REQ_FILE" '{request_id:$id, request_path:$path}'
