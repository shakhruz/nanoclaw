#!/usr/bin/env bash
# mcp-call.sh — talk to telegram-scanner MCP via streamable HTTP, no SDK needed.
# Performs initialize → notifications/initialized → tools/call in one shot.
#
# Usage:
#   mcp-call.sh <tool_name> <args_json>
#
# Example:
#   mcp-call.sh publish_to_channel '{"channel":"ashotonline","text":"Hello *world*"}'
#
# Env overrides:
#   MCP_URL — endpoint URL (default: http://host.containers.internal:3002/mcp)
#             Falls back to http://host.docker.internal:3002/mcp if first fails.
#
# Output: JSON tool result on stdout. On failure, prints {"error":"..."} and exits non-zero.

set -uo pipefail

TOOL="${1:?usage: mcp-call.sh <tool_name> <args_json>}"
ARGS_JSON="${2:-}"
[ -z "$ARGS_JSON" ] && ARGS_JSON='{}'

# Resolve MCP URL: explicit override → Apple Container DNS → Docker Desktop DNS → localhost
URLS=()
if [ -n "${MCP_URL:-}" ]; then URLS+=("$MCP_URL"); fi
URLS+=("http://host.containers.internal:3002/mcp")
URLS+=("http://host.docker.internal:3002/mcp")
URLS+=("http://127.0.0.1:3002/mcp")

# Common headers; mcp-session-id added after init
ACCEPT="application/json, text/event-stream"

# ---- Probe & initialize ----------------------------------------------------
SID=""
URL=""
INIT_BODY='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"telegram-publish","version":"1.0"}}}'

for candidate in "${URLS[@]}"; do
  TMP=$(mktemp)
  HTTP=$(curl -sS -o "$TMP" -D - --max-time 10 \
    -H "Content-Type: application/json" \
    -H "Accept: $ACCEPT" \
    -X POST "$candidate" \
    -d "$INIT_BODY" 2>/dev/null | head -1 | awk '{print $2}')
  if [ "$HTTP" = "200" ]; then
    # Extract session id from response headers (curl -D - puts headers + body)
    SID=$(curl -sS -D - -o /dev/null --max-time 10 \
      -H "Content-Type: application/json" \
      -H "Accept: $ACCEPT" \
      -X POST "$candidate" \
      -d "$INIT_BODY" 2>/dev/null | tr -d '\r' | grep -i '^mcp-session-id:' | head -1 | awk '{print $2}')
    if [ -n "$SID" ]; then
      URL="$candidate"
      rm -f "$TMP"
      break
    fi
  fi
  rm -f "$TMP"
done

if [ -z "$URL" ] || [ -z "$SID" ]; then
  jq -n --argjson urls "$(printf '%s\n' "${URLS[@]}" | jq -R . | jq -s .)" \
    '{error:"mcp_unreachable", tried:$urls, hint:"Is telegram-scanner running on the host? Check launchctl com.nanoclaw.telegram-scanner"}'
  exit 2
fi

# ---- Send notifications/initialized ----------------------------------------
curl -sS -o /dev/null --max-time 10 \
  -H "Content-Type: application/json" \
  -H "Accept: $ACCEPT" \
  -H "mcp-session-id: $SID" \
  -X POST "$URL" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'

# ---- Call the tool ----------------------------------------------------------
CALL_BODY=$(jq -n --arg t "$TOOL" --argjson a "$ARGS_JSON" \
  '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:$t,arguments:$a}}')

# Per-tool timeout: env override MCP_TIMEOUT (seconds) or default 120s.
# For long-running tools (download_media on big files, batch operations) caller
# should `MCP_TIMEOUT=1800 bash mcp-call.sh download_media …`
TIMEOUT_S="${MCP_TIMEOUT:-120}"

RESP=$(curl -sS --max-time "$TIMEOUT_S" \
  -H "Content-Type: application/json" \
  -H "Accept: $ACCEPT" \
  -H "mcp-session-id: $SID" \
  -X POST "$URL" \
  -d "$CALL_BODY")

# Streamable HTTP returns SSE-format: lines like "event: message\ndata: {...}\n\n"
# Extract first data: line containing JSON-RPC response.
DATA=$(echo "$RESP" | awk '/^data: /{sub(/^data: /,""); print; exit}')

if [ -z "$DATA" ]; then
  # Maybe plain JSON (server returned 200 with body)
  DATA="$RESP"
fi

# Pull text content if present (FastMCP wraps str returns in content[0].text)
echo "$DATA" | jq -r '
  if .error then
    "ERROR: " + (.error.message // (.error | tostring))
  elif .result.content[0].text then
    .result.content[0].text
  elif .result then
    .result | tojson
  else
    .
  end
'
