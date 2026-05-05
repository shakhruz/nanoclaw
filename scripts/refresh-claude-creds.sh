#!/bin/bash
# Refresh Claude OAuth credentials directly via the OAuth refresh endpoint,
# without depending on the host-side `claude` CLI being active.
#
# Old behaviour (broken by 2026-05-02): mirror keychain → file. That only
# worked while the host `claude` CLI was running and rotating the keychain
# entry itself. If the host was idle for >8h, both keychain and mirror
# expired simultaneously and every container started returning 401.
#
# New behaviour: read refresh_token from the mirror file, POST to
# https://platform.claude.com/v1/oauth/token, write the response back.
# Keychain is also kept in sync for compatibility with the host `claude` CLI.
#
# Run via launchd (StartInterval=1800) — see launchd/com.nanoclaw.refresh-claude-creds.plist.

set -e

CREDS_FILE="/Users/milagpt/nanoclaw/mila-nanoclaw/data/anthropic-creds/.credentials.json"
KEYCHAIN_SERVICE="Claude Code-credentials"
KEYCHAIN_ACCOUNT="milagpt"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
TOKEN_URL="https://platform.claude.com/v1/oauth/token"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
err() { echo "$(ts) ERROR $*" >&2; exit 1; }

[ -f "$CREDS_FILE" ] || err "creds file missing: $CREDS_FILE"

# Pick refresh_token: prefer mirror file (it's our authoritative state); if
# absent, fall back to keychain so we can self-heal after a wipe.
REFRESH_TOKEN=$(python3 -c "
import json
try:
  d = json.load(open('$CREDS_FILE'))
  print(d['claudeAiOauth'].get('refreshToken',''))
except Exception:
  print('')
")
if [ -z "$REFRESH_TOKEN" ]; then
  KC=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null || true)
  REFRESH_TOKEN=$(echo "$KC" | python3 -c "
import json, sys
try:
  print(json.load(sys.stdin)['claudeAiOauth'].get('refreshToken',''))
except Exception:
  print('')
")
fi
[ -n "$REFRESH_TOKEN" ] || err "no refresh_token available in mirror or keychain"

NEW_OAUTH=$(REFRESH_TOKEN="$REFRESH_TOKEN" CLIENT_ID="$CLIENT_ID" TOKEN_URL="$TOKEN_URL" python3 - <<'PY'
import json, os, sys, time, urllib.request, urllib.error
data = json.dumps({
  'grant_type': 'refresh_token',
  'refresh_token': os.environ['REFRESH_TOKEN'],
  'client_id': os.environ['CLIENT_ID'],
}).encode()
req = urllib.request.Request(os.environ['TOKEN_URL'], data=data, headers={
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'User-Agent': 'claude-cli/2.1.121 (cli, v2.1.121)',
})
try:
  body = json.loads(urllib.request.urlopen(req, timeout=15).read().decode())
except urllib.error.HTTPError as e:
  print(f'HTTP {e.code}: {e.read().decode()[:500]}', file=sys.stderr)
  sys.exit(2)
out = {
  'accessToken': body['access_token'],
  'refreshToken': body.get('refresh_token', os.environ['REFRESH_TOKEN']),
  'expiresAt': int((time.time() + body['expires_in']) * 1000),
  'scopes': (body.get('scope','') or '').split() if isinstance(body.get('scope',''), str) else body.get('scope', []),
  'subscriptionType': 'max',
}
print(json.dumps(out))
PY
)
[ -n "$NEW_OAUTH" ] || err "refresh response empty"

# Merge into mirror file (preserve any extra keys claude CLI may add)
NEW_OAUTH="$NEW_OAUTH" python3 - <<PY
import json, os
new = json.loads(os.environ['NEW_OAUTH'])
try:
  d = json.load(open('$CREDS_FILE'))
except Exception:
  d = {}
oauth = d.get('claudeAiOauth', {})
oauth.update(new)
d['claudeAiOauth'] = oauth
json.dump(d, open('$CREDS_FILE','w'))
PY

chmod 600 "$CREDS_FILE"

# Mirror back to keychain so the host `claude` CLI keeps working too
NEW_JSON=$(cat "$CREDS_FILE")
echo "$NEW_JSON" | security add-generic-password \
  -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -U \
  -w "$NEW_JSON" 2>/dev/null || true

EXP_MIN=$(python3 -c "
import json, time
d = json.load(open('$CREDS_FILE'))['claudeAiOauth']
print(int((d['expiresAt']/1000 - time.time()) / 60))
")
echo "$(ts) ok expires_in=${EXP_MIN}min"
