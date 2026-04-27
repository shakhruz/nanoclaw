#!/usr/bin/env bash
# upload-media.sh <file_path> [target] — upload an image/video to Telegram Ads.
#
# target: "ad_media" (default — for the ad's main creative)
#       | "promote_photo" (for the website preview photo)
#
# Output: JSON with `media` field — the media ID to pass to create-ad.sh as
#   {"picture": 1, "media": "<returned_id>"}
#
# Telegram limits (per page state):
#   ad_media photo: typically ≤ 8 MB
#   ad_media video: typically ≤ 32 MB

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
trap ads_cleanup EXIT

[ -z "${1:-}" ] && { echo "usage: upload-media.sh <file_path> [target]" >&2; exit 1; }
FILE="$1"
TARGET="${2:-ad_media}"

[ -f "$FILE" ] || { echo "file not found: $FILE" >&2; exit 1; }
case "$TARGET" in
  ad_media|promote_photo) ;;
  *) echo "target must be ad_media or promote_photo" >&2; exit 1 ;;
esac

ads_init || { echo '{"ok":false,"error":"init_failed"}'; exit 1; }

# /file/upload is multipart — uses curl -F. Referer matters: ad/new for ad_media,
# ad/new for promote_photo too (both fields live on the create form).
curl -sS -X POST "$ADS_BASE/file/upload" \
  -b "$ADS_JAR" -c "$ADS_JAR" \
  -A "$ADS_UA" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Origin: $ADS_BASE" \
  -H "Referer: $ADS_BASE/account/ad/new" \
  -F "owner_id=$ADS_OWNER_ID" \
  -F "target=$TARGET" \
  -F "file=@$FILE"
echo
