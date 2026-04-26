#!/usr/bin/env bash
# telegram-ads-http/lib.sh — shared helpers for curl-based ads.telegram.org access.
#
# Replaces headless-browser approach (telegram-ads-manager + telegram-ads-session +
# telegram-ads-access) which suffered from Telegram device-fingerprint rejection on
# every container spawn. Curl with persisted cookies bypasses fingerprint check.
#
# Usage in skill scripts:
#   source /home/node/.claude/skills/telegram-ads-http/lib.sh
#   ads_init                # builds cookie jar, fetches initial /account, sets HASH
#   ads_get "/account/ad/36" > out.html
#   ads_post "/account/ad/36" "method=editAdStatus&ad_id=36&active=1"

set -uo pipefail

ADS_BASE="https://ads.telegram.org"
ADS_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Cookie source — main is the canonical store, copied into every group on spawn.
ADS_COOKIES_JSON="${ADS_COOKIES_JSON:-/home/node/.agent-browser/sessions/telegram-ads-default.json}"

# Per-run state (set by ads_init)
ADS_JAR=""
ADS_HASH=""
ADS_INITIAL_HTML=""
ADS_OWNER_ID=""

# Build a Netscape-format cookie jar from the agent-browser JSON.
# Echoes path to jar.
_ads_build_jar() {
  local out
  out=$(mktemp -t ads-jar.XXXXXX) || return 1
  echo "# Netscape HTTP Cookie File" > "$out"
  jq -r '
    .cookies[]
    | select(.domain | contains("telegram.org"))
    | [.domain, "FALSE", .path, "TRUE", (.expires | tostring | split(".")[0]), .name, .value]
    | @tsv
  ' "$ADS_COOKIES_JSON" >> "$out" 2>/dev/null || {
    echo "lib.sh: failed to read cookies from $ADS_COOKIES_JSON" >&2
    return 1
  }
  echo "$out"
}

# Initialize state. Builds jar, fetches /account, extracts apiUrl hash.
# Returns 0 on success, 1 if cookies missing, 2 if Telegram rejects (auth issue).
ads_init() {
  if [ ! -f "$ADS_COOKIES_JSON" ]; then
    echo "lib.sh: cookie file not found at $ADS_COOKIES_JSON" >&2
    return 1
  fi
  ADS_JAR=$(_ads_build_jar) || return 1

  ADS_INITIAL_HTML=$(mktemp -t ads-account.XXXXXX) || return 1
  local code
  code=$(curl -sS -b "$ADS_JAR" -c "$ADS_JAR" \
    -A "$ADS_UA" \
    -o "$ADS_INITIAL_HTML" \
    -w "%{http_code}" \
    "$ADS_BASE/account") || return 1

  if [ "$code" != "200" ]; then
    echo "lib.sh: /account returned HTTP $code" >&2
    return 2
  fi

  # Detect login redirect
  if grep -qE '"error":"AUTH_REQUIRED"|<title>.*[Ll]ogin' "$ADS_INITIAL_HTML"; then
    echo "lib.sh: /account redirected to login — session invalid" >&2
    return 2
  fi

  ADS_HASH=$(grep -oE 'apiUrl":"\\?/api\?hash=[a-f0-9]+' "$ADS_INITIAL_HTML" \
    | head -1 | grep -oE '[a-f0-9]+$')
  if [ -z "$ADS_HASH" ]; then
    echo "lib.sh: failed to extract apiUrl hash from /account" >&2
    return 2
  fi

  # owner_id = stel_adowner cookie value (also exposed as ownerId in page state)
  ADS_OWNER_ID=$(jq -r '.cookies[]|select(.name=="stel_adowner")|.value' "$ADS_COOKIES_JSON" 2>/dev/null)
  return 0
}

# GET an ads.telegram.org page. $1 = path (e.g. /account/ad/36).
# Output to stdout. Updates jar.
ads_get() {
  local path="$1"
  if [ -z "$ADS_JAR" ]; then
    echo "lib.sh: ads_init not called" >&2
    return 1
  fi
  curl -sS -b "$ADS_JAR" -c "$ADS_JAR" \
    -A "$ADS_UA" \
    "$ADS_BASE$path"
}

# POST to /api endpoint. $1 = referer path (e.g. /account/ad/36), $2 = body (method=X&...).
# Output: server JSON to stdout.
# IMPORTANT: Telegram validates Referer against the method — passing the wrong path
# returns {"error":"Access denied"}. See SKILL.md for method ↔ path mapping.
ads_post() {
  local referer_path="$1"
  local body="$2"
  if [ -z "$ADS_HASH" ]; then
    echo "lib.sh: ads_init not called or hash missing" >&2
    return 1
  fi
  curl -sS -X POST "$ADS_BASE/api?hash=$ADS_HASH" \
    -b "$ADS_JAR" -c "$ADS_JAR" \
    -A "$ADS_UA" \
    -H "X-Requested-With: XMLHttpRequest" \
    -H "Origin: $ADS_BASE" \
    -H "Referer: $ADS_BASE$referer_path" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    -H "Accept: application/json, text/plain, */*" \
    --data "$body"
}

# Extract the inline Aj.init({...}) JSON object from a page (HTML).
# Reads HTML from stdin or $1 path.
ads_extract_state() {
  local input
  if [ -n "${1:-}" ]; then input="$1"; else input=$(cat); fi
  # Aj.init takes a single object literal; we capture from "{ until matching close.
  # The simple grep below works because the object is on one line in Telegram pages.
  if [ -f "$input" ]; then
    grep -oE '\{"version":[0-9]+,"apiUrl":"[^"]+",[^}]*"state":\{.*' "$input" | head -1
  else
    echo "$input" | grep -oE '\{"version":[0-9]+,"apiUrl":"[^"]+",[^}]*"state":\{.*' | head -1
  fi
}

# Cleanup temp files (call on exit).
ads_cleanup() {
  [ -n "$ADS_JAR" ] && [ -f "$ADS_JAR" ] && rm -f "$ADS_JAR"
  [ -n "$ADS_INITIAL_HTML" ] && [ -f "$ADS_INITIAL_HTML" ] && rm -f "$ADS_INITIAL_HTML"
}
