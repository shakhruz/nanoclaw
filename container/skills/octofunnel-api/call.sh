#!/usr/bin/env bash
# octofunnel-api/call.sh — universal HTTP wrapper для OctoFunnel API
#
# Usage:
#   call.sh <platform> <method> <endpoint> [param1=value1] [param2=value2] ...
#
#   <platform>  — ashotai.uz / liliastrategy.uz / etc
#   <method>    — GET | POST
#   <endpoint>  — funnels_list / clients_get / blocks_create / etc (см. https://octofunnel.com/docs/)
#
# Auto-resolves secret from /workspace/group/config.json or /workspace/global/octofunnel-config.json
# Returns raw JSON response on stdout. Caller обычно жмёт через jq.
#
# Examples:
#   call.sh ashotai.uz GET funnels_list
#   call.sh ashotai.uz POST funnels_create name="New Funnel"
#   call.sh ashotai.uz GET clients_get id=123
#   call.sh ashotai.uz POST blocks_update id=42 content="новый текст"

set -eu

PLATFORM="${1:?usage: call.sh <platform> <GET|POST> <endpoint> [params...]}"
METHOD="${2:?method (GET|POST) required}"
ENDPOINT="${3:?endpoint required (e.g. funnels_list)}"
shift 3

# Resolve secret
SECRET=""
if [ -f /workspace/group/config.json ]; then
  SECRET=$(jq -r ".octofunnel.platforms.\"$PLATFORM\".secret // empty" /workspace/group/config.json 2>/dev/null || echo "")
fi
if [ -z "$SECRET" ] && [ -f /workspace/global/octofunnel-config.json ]; then
  SECRET=$(jq -r ".platforms.\"$PLATFORM\".secret // empty" /workspace/global/octofunnel-config.json 2>/dev/null || echo "")
fi

if [ -z "$SECRET" ]; then
  jq -n --arg p "$PLATFORM" '{error:1, description:("No secret for platform " + $p + " — add to /workspace/global/octofunnel-config.json:platforms.<domain>.secret")}'
  exit 1
fi

# Resolve base_url
BASE_URL=""
if [ -f /workspace/global/octofunnel-config.json ]; then
  BASE_URL=$(jq -r ".platforms.\"$PLATFORM\".api_endpoint // empty" /workspace/global/octofunnel-config.json 2>/dev/null || echo "")
fi
[ -z "$BASE_URL" ] && BASE_URL="https://$PLATFORM/crm/php/file/api.php"

# Build curl args
CURL_ARGS=( -s )
CURL_ARGS+=( --data-urlencode "v2=$ENDPOINT" )
CURL_ARGS+=( --data-urlencode "secret=$SECRET" )

# Append additional params
for arg in "$@"; do
  CURL_ARGS+=( --data-urlencode "$arg" )
done

if [ "$METHOD" = "GET" ]; then
  curl "${CURL_ARGS[@]}" -G "$BASE_URL"
elif [ "$METHOD" = "POST" ]; then
  curl "${CURL_ARGS[@]}" -X POST "$BASE_URL"
else
  jq -n --arg m "$METHOD" '{error:1, description:("Invalid HTTP method: " + $m + " — use GET or POST")}'
  exit 1
fi
