#!/bin/bash
# Periodically copy fresh Claude OAuth credentials from macOS Keychain into
# data/anthropic-creds/.credentials.json so containers always have a valid
# access_token. The host-side claude CLI keeps the Keychain entry rotated;
# we just mirror its current state into the mounted file.
#
# Run via launchd (StartInterval=1800) — see launchd/com.nanoclaw.refresh-claude-creds.plist.

set -e

CREDS_FILE="/Users/milagpt/nanoclaw/nanoclaw-v2/data/anthropic-creds/.credentials.json"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! security find-generic-password -s "Claude Code-credentials" -a milagpt -w >"$TMP" 2>/dev/null; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ERROR keychain read failed" >&2
  exit 1
fi

python3 -c "
import json, sys
src = json.load(open('$TMP'))
out = {'claudeAiOauth': src['claudeAiOauth']}
json.dump(out, open('$CREDS_FILE', 'w'))
" || { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ERROR json transform" >&2; exit 1; }

chmod 600 "$CREDS_FILE"

EXP_MIN=$(python3 -c "
import json, time
d = json.load(open('$CREDS_FILE'))['claudeAiOauth']
print(int((d['expiresAt']/1000 - time.time()) / 60))
")
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ok expires_in=${EXP_MIN}min"
