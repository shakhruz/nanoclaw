#!/usr/bin/env bash
# test-smoke.sh — regression test for check-session.sh + session-probe.sh
#
# Run inside a container OR on host with CHECK_SESSION_FILE pointing at a real session.
# Tests 4 scenarios: alive, expired, missing, empty.
#
# Exit 0 if all 4 pass; exit 1 on any failure.

set -u

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

echo "Test 1: alive cookie"
ALIVE_TS=$(node -e "console.log(Math.floor(Date.now()/1000) + 86400 * 90)")  # 90 days
echo "{\"cookies\":[{\"name\":\"stel_ssid\",\"domain\":\"ads.telegram.org\",\"expires\":$ALIVE_TS}]}" > "$TMP/alive.json"
CHECK_SESSION_FILE="$TMP/alive.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "alive exit code" "0" "$?"
RESULT=$(CHECK_SESSION_FILE="$TMP/alive.json" "$SKILL_DIR/check-session.sh")
STATUS=$(echo "$RESULT" | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>console.log(JSON.parse(d).status))")
assert_eq "alive status field" "alive" "$STATUS"

echo ""
echo "Test 2: expired cookie (in past)"
echo '{"cookies":[{"name":"stel_ssid","domain":"ads.telegram.org","expires":1}]}' > "$TMP/expired.json"
CHECK_SESSION_FILE="$TMP/expired.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "expired exit code" "1" "$?"

echo ""
echo "Test 3: missing file"
CHECK_SESSION_FILE="$TMP/nonexistent.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "missing exit code" "2" "$?"

echo ""
echo "Test 4: empty cookies array"
echo '{"cookies":[]}' > "$TMP/empty.json"
CHECK_SESSION_FILE="$TMP/empty.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "empty cookies exit code" "1" "$?"

echo ""
echo "Test 5: cookie expires within 1 hour (treated as expired by helper)"
SOON_TS=$(node -e "console.log(Math.floor(Date.now()/1000) + 1800)")  # 30 min
echo "{\"cookies\":[{\"name\":\"stel_ssid\",\"domain\":\"ads.telegram.org\",\"expires\":$SOON_TS}]}" > "$TMP/soon.json"
CHECK_SESSION_FILE="$TMP/soon.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "within-1-hour exit code" "1" "$?"

echo ""
echo "Test 6: wrong cookie name (not stel_ssid)"
echo "{\"cookies\":[{\"name\":\"stel_token\",\"domain\":\"ads.telegram.org\",\"expires\":$ALIVE_TS}]}" > "$TMP/wrong-name.json"
CHECK_SESSION_FILE="$TMP/wrong-name.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "wrong cookie name → expired" "1" "$?"

echo ""
echo "Test 7: stel_ssid on wrong domain"
echo "{\"cookies\":[{\"name\":\"stel_ssid\",\"domain\":\"web.telegram.org\",\"expires\":$ALIVE_TS}]}" > "$TMP/wrong-domain.json"
CHECK_SESSION_FILE="$TMP/wrong-domain.json" "$SKILL_DIR/check-session.sh" >/dev/null
assert_eq "wrong domain → expired" "1" "$?"

echo ""
echo "================================="
echo "Results: $PASS passed, $FAIL failed"
echo "================================="
[ "$FAIL" = "0" ]
