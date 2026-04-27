#!/usr/bin/env bash
# balance-deposit.sh [<amount_ton>] — generate a TON deposit URL for owner's wallet.
#
# IMPORTANT: Telegram Ads does NOT have an API for arbitrary deposits — top-up
# requires Шахруз to sign a TON transaction in his Telegram Wallet / Tonkeeper.
# This helper outputs the deposit URL/instructions so Mila can dispatch the
# request to him with proper context.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

AMOUNT="${1:-}"

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

# Fetch /account/budget to get current TON wallet address + balance
PAGE=$(mktemp); trap "rm -f $PAGE; ads_cleanup" EXIT
ads_get "/account/budget" > "$PAGE"

# Extract balance from /account header (tolerant — page may differ)
BALANCE_TON=$( (grep -oE '💎</span>[0-9]+<span class="amount-frac">\.[0-9]+' "$ADS_INITIAL_HTML" 2>/dev/null || true) \
  | head -1 | sed -E 's|💎</span>||; s|<span class="amount-frac">||')

# TON deposit address typically in /account/budget page as a copyable field
TON_ADDR=$( (grep -oE 'EQ[A-Za-z0-9_-]{46,}|UQ[A-Za-z0-9_-]{46,}' "$PAGE" 2>/dev/null || true) | head -1)

jq -n \
  --arg balance "$BALANCE_TON" \
  --arg addr "${TON_ADDR:-not_found}" \
  --arg amount "${AMOUNT:-not_specified}" \
  --arg url "$ADS_BASE/account/budget" \
  '{
    ok: true,
    current_balance_ton: $balance,
    deposit_address: $addr,
    requested_top_up_ton: $amount,
    web_ui_url: $url,
    note: "Top-up cannot be automated — Шахруз must sign TON transaction in his wallet (Telegram Wallet, Tonkeeper, or any TON wallet). Send him the deposit address with the requested amount."
  }'
