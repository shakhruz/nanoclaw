#!/bin/bash
# Meta Ads — shared helpers (sourced by other scripts)
# Reads token + ad account from /workspace/group/config.json:meta_ads

set -e

META_CONFIG="${META_CONFIG:-/workspace/group/config.json}"
META_API="${META_API:-https://graph.facebook.com/v21.0}"

[ ! -f "$META_CONFIG" ] && { echo "config not found: $META_CONFIG" >&2; exit 1; }

META_TOKEN=$(jq -r '.meta_ads.access_token // empty' "$META_CONFIG")
META_ACT=$(jq -r '.meta_ads.primary_ad_account // empty' "$META_CONFIG")
META_TOKEN_EXP=$(jq -r '.meta_ads.token_expires_at // empty' "$META_CONFIG")

[ -z "$META_TOKEN" ] && { echo "meta_ads.access_token missing in $META_CONFIG" >&2; exit 1; }
[ -z "$META_ACT" ] && { echo "meta_ads.primary_ad_account missing" >&2; exit 1; }

# meta_get <path> [extra --data-urlencode args ...]
meta_get() {
  local path="$1"; shift
  curl -sG "$META_API/$path" --data-urlencode "access_token=$META_TOKEN" "$@"
}

# meta_post <path> <json_body>
meta_post() {
  local path="$1" body="$2"
  curl -s -X POST "$META_API/$path?access_token=$META_TOKEN" \
    -H "Content-Type: application/json" -d "$body"
}

# meta_check_error <json> — exit non-zero if response contains error
meta_check_error() {
  local json="$1"
  local err
  err=$(echo "$json" | jq -r '.error.message // empty')
  if [ -n "$err" ]; then
    echo "META API ERROR: $err" >&2
    echo "$json" | jq '.error' >&2
    return 1
  fi
}

# meta_token_warning — print warning if token expires within 7 days
meta_token_warning() {
  [ -z "$META_TOKEN_EXP" ] && return
  local now exp days
  now=$(date -u +%s)
  exp=$(date -u -d "$META_TOKEN_EXP" +%s 2>/dev/null || python3 -c "import datetime,sys;print(int(datetime.datetime.fromisoformat(sys.argv[1].replace('Z','+00:00')).timestamp()))" "$META_TOKEN_EXP" 2>/dev/null)
  [ -z "$exp" ] && return
  days=$(( (exp - now) / 86400 ))
  if [ "$days" -lt 7 ]; then
    echo "⚠️  Meta access token expires in $days days ($META_TOKEN_EXP). Renew via Graph API Explorer." >&2
  fi
}
