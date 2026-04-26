#!/bin/bash
# Meta Ads — resume a paused campaign
# Usage: resume.sh <campaign_id>
. "$(dirname "$0")/lib.sh"

CID="${1:?campaign_id required}"
RESP=$(meta_post "$CID" '{"status":"ACTIVE"}')
meta_check_error "$RESP" || exit 1
echo "✅ resumed $CID"
echo "$RESP"
