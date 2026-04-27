#!/bin/bash
# Meta Ads — pause a campaign by id
# Usage: pause.sh <campaign_id>
. "$(dirname "$0")/lib.sh"

CID="${1:?campaign_id required}"
RESP=$(meta_post "$CID" '{"status":"PAUSED"}')
meta_check_error "$RESP" || exit 1
echo "✅ paused $CID"
echo "$RESP"
