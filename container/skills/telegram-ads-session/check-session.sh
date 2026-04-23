#!/usr/bin/env bash
# check-session.sh — authoritative Telegram Ads session check (cookie-only, no browser)
#
# Reads the agent-browser session file and inspects stel_ssid cookie on ads.telegram.org.
# Fast (~50ms), no side effects. The SINGLE source of truth for "is the session alive?"
#
# Exit codes:
#   0  alive    — stel_ssid exists and expires more than 1 hour from now
#   1  expired  — stel_ssid missing or expires within 1 hour
#   2  unknown  — session file not found (never authenticated or wrong path)
#
# Stdout: JSON  {"status":"alive|expired|unknown","expires_at":"ISO|null","days_left":N|null,"cookie_file":"<path>"}
#
# Usage:
#   check-session.sh                     # uses default path
#   CHECK_SESSION_FILE=/path/to/session check-session.sh
#
# Defaults to /home/node/.agent-browser/sessions/telegram-ads-default.json
# (the path where NanoClaw mounts the session dir in containers — see src/container-runner.ts).

set -eu

DEFAULT_PATH="${HOME:-/home/node}/.agent-browser/sessions/telegram-ads-default.json"
SESSION_FILE="${CHECK_SESSION_FILE:-$DEFAULT_PATH}"

if [ ! -f "$SESSION_FILE" ]; then
  printf '{"status":"unknown","expires_at":null,"days_left":null,"cookie_file":"%s","reason":"file_not_found"}\n' "$SESSION_FILE"
  exit 2
fi

node --input-type=module -e "
  import fs from 'fs';
  const file = process.argv[1];
  const out = (s, expires_at, days_left, reason) =>
    process.stdout.write(JSON.stringify({status:s, expires_at, days_left, cookie_file:file, reason:reason||null})+'\n');
  let data;
  try { data = JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (e) { out('unknown', null, null, 'parse_error'); process.exit(2); }
  const cookies = Array.isArray(data.cookies) ? data.cookies : [];
  const cookie = cookies.find(c =>
    c && c.name === 'stel_ssid' && typeof c.domain === 'string' && c.domain.includes('ads.telegram.org')
  );
  if (!cookie || typeof cookie.expires !== 'number' || cookie.expires <= 0) {
    out('expired', null, null, 'cookie_missing_or_session'); process.exit(1);
  }
  const now = Date.now() / 1000;
  const secondsLeft = cookie.expires - now;
  const expires_at = new Date(cookie.expires * 1000).toISOString();
  const days_left = Math.floor(secondsLeft / 86400);
  if (secondsLeft > 3600) { out('alive', expires_at, days_left); process.exit(0); }
  out('expired', expires_at, days_left, 'within_one_hour'); process.exit(1);
" "$SESSION_FILE"
