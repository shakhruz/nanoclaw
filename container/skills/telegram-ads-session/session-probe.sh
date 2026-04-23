#!/usr/bin/env bash
# session-probe.sh — live Telegram Ads login state probe via agent-browser
#
# Opens https://ads.telegram.org in a persistent-session browser and inspects
# the FINAL URL (not snapshot text — URL is unaffected by language/theme).
#
# Exit codes:
#   0  logged_in   — final URL under ads.telegram.org/account (or /a/, /ad/, /campaign)
#   1  logged_out  — final URL contains /login, /oauth, or the root /
#   3  probe_error — agent-browser not available or navigation failed
#
# Stdout: JSON  {"status":"logged_in|logged_out|probe_error","final_url":"<url>"}
#
# Usage:
#   session-probe.sh
#   SESSION_PROBE_TIMEOUT=20 session-probe.sh
#
# NOTE: this opens a real browser — use sparingly. Prefer check-session.sh (cookie-only)
# for routine checks. Call session-probe.sh only when check-session.sh returns expired
# AND you want to confirm before alerting the user (catches stale cookie-file writes).

set -eu

if ! command -v agent-browser >/dev/null 2>&1; then
  printf '{"status":"probe_error","final_url":null,"reason":"agent_browser_not_installed"}\n'
  exit 3
fi

TIMEOUT="${SESSION_PROBE_TIMEOUT:-15}"

# Open the page; suppress stderr so we can inspect cleanly
if ! timeout "${TIMEOUT}" agent-browser --session-name telegram-ads open "https://ads.telegram.org" >/dev/null 2>&1; then
  printf '{"status":"probe_error","final_url":null,"reason":"open_failed_or_timeout"}\n'
  exit 3
fi

# Brief settle to let any redirect complete
sleep 2

# agent-browser doesn't expose `url` as a top-level command — get URL via eval.
# Output format: a JSON-encoded string like `"https://ads.telegram.org/account"` —
# strip surrounding quotes and trailing whitespace.
FINAL_URL=$(timeout 10 agent-browser --session-name telegram-ads eval "location.href" 2>/dev/null \
  | sed 's/^"//; s/"$//' | tr -d '\n\r ' || true)

if [ -z "$FINAL_URL" ]; then
  printf '{"status":"probe_error","final_url":null,"reason":"url_unavailable"}\n'
  exit 3
fi

# URL-based decision.
# Tested empirically: ads.telegram.org root (/) IS the authenticated dashboard.
# When NOT logged in, Telegram Ads redirects to /login or oauth.telegram.org.
# So: anything under ads.telegram.org that does NOT contain /login → logged_in.
case "$FINAL_URL" in
  *ads.telegram.org/login*|*oauth.telegram.org*|*tg.dev/login*)
    printf '{"status":"logged_out","final_url":"%s"}\n' "$FINAL_URL"
    exit 1
    ;;
  *ads.telegram.org*)
    # Any ads.telegram.org URL that didn't redirect to /login means we're authenticated.
    # This includes the bare root https://ads.telegram.org/ which serves the dashboard.
    printf '{"status":"logged_in","final_url":"%s"}\n' "$FINAL_URL"
    exit 0
    ;;
  *)
    printf '{"status":"probe_error","final_url":"%s","reason":"unexpected_domain"}\n' "$FINAL_URL"
    exit 3
    ;;
esac
