#!/usr/bin/env bash
# publish.sh — high-level wrapper around mcp-call.sh for the most common
# telegram-publish operations.
#
# Usage:
#   publish.sh post     <channel> <text-file>           [image_path]   [--silent] [--schedule=ISO|+Nh|+Nm]
#   publish.sh story    <text>    <image_path>                                          # user-story
#   publish.sh ch_story <channel> <image_path>          [caption]                       # channel-story
#   publish.sh pin      <chat>    <message_id>                         [--notify]
#   publish.sh forward  <from>    <message_id> <to>                    [--drop-author]
#   publish.sh subscribe <channel>
#   publish.sh dm        <username> <text>
#   publish.sh metrics
#
# Scheduled-message management (post-moderation flow):
#   publish.sh list_scheduled  <channel>                               [limit]
#   publish.sh publish_now     <channel> <scheduled_id>
#   publish.sh cancel          <channel> <scheduled_id>
#   publish.sh reschedule      <channel> <scheduled_id> <new-iso>
#   publish.sh edit_sched      <channel> <scheduled_id> [--text=file] [--image=path] [--at=ISO]
#
# Defaults & conventions:
#   - Default schedule = +1h (post-moderation by Shakhruz). To publish immediately,
#     pass --schedule=now or pass an empty value, but USUALLY post-moderate first.
#   - <text-file> = absolute path to a markdown file (preferred), or "-" for stdin
#   - Markdown: single *bold*, _italic_, `code`, [text](url). NEVER **double**.
#   - Image paths: prefer /workspace/global/... (auto-translated by scanner).

set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP="$SKILL_DIR/lib/mcp-call.sh"

usage() { sed -n '1,40p' "$0" >&2; exit 1; }

read_text() {
  if [ "$1" = "-" ]; then cat; else cat "$1"; fi
}

# Resolve --schedule argument: ISO, "+Nh", "+Nm", "now", or empty.
# Returns ISO UTC string, or empty for immediate publish.
resolve_schedule() {
  local raw="$1"
  case "$raw" in
    ""|"now") echo "" ;;
    +*h)
      local n="${raw#+}"; n="${n%h}"
      if date -u -v+${n}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :
      else date -u -d "+${n} hours" +%Y-%m-%dT%H:%M:%SZ; fi
      ;;
    +*m)
      local n="${raw#+}"; n="${n%m}"
      if date -u -v+${n}M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :
      else date -u -d "+${n} minutes" +%Y-%m-%dT%H:%M:%SZ; fi
      ;;
    *) echo "$raw" ;;  # assume already ISO
  esac
}

cmd="${1:-}"; shift || usage
case "$cmd" in
  post)
    CHANNEL="${1:?channel required}"
    TEXT_SRC="${2:?text-file or - required}"
    shift 2
    IMAGE_PATH=""
    SILENT=false
    SCHEDULE_RAW="+1h"   # default: post-moderate, give Shakhruz 1h to review
    while [ $# -gt 0 ]; do
      case "$1" in
        --silent) SILENT=true ;;
        --schedule=*) SCHEDULE_RAW="${1#--schedule=}" ;;
        --no-schedule|--immediate) SCHEDULE_RAW="" ;;
        *) IMAGE_PATH="$1" ;;
      esac
      shift
    done
    SCHEDULE_ISO=$(resolve_schedule "$SCHEDULE_RAW")
    TEXT=$(read_text "$TEXT_SRC")
    ARGS=$(jq -n \
      --arg ch "$CHANNEL" --arg t "$TEXT" --arg ip "$IMAGE_PATH" \
      --argjson silent "$SILENT" --arg sch "$SCHEDULE_ISO" \
      '{channel:$ch, text:$t} +
       (if $ip != "" then {image_path:$ip} else {} end) +
       (if $silent then {disable_notification:true} else {} end) +
       (if $sch != "" then {schedule_date:$sch} else {} end)')
    bash "$MCP" publish_to_channel "$ARGS"
    ;;

  story)
    TEXT="${1:?caption required}"
    IMAGE_PATH="${2:?image_path required}"
    bash "$MCP" publish_story "$(jq -n --arg t "$TEXT" --arg ip "$IMAGE_PATH" '{text:$t, image_path:$ip}')"
    ;;

  ch_story)
    CHANNEL="${1:?channel required}"
    IMAGE_PATH="${2:?image_path required}"
    CAPTION="${3:-}"
    bash "$MCP" publish_channel_story \
      "$(jq -n --arg ch "$CHANNEL" --arg ip "$IMAGE_PATH" --arg c "$CAPTION" \
        '{channel:$ch, image_path:$ip, caption:$c}')"
    ;;

  pin)
    CHAT="${1:?chat required}"
    MSGID="${2:?message_id required}"
    NOTIFY=false
    [ "${3:-}" = "--notify" ] && NOTIFY=true
    bash "$MCP" pin_message \
      "$(jq -n --arg c "$CHAT" --argjson m "$MSGID" --argjson n "$NOTIFY" \
        '{chat_id:$c, message_id:$m, notify:$n}')"
    ;;

  forward)
    FROM="${1:?from required}"
    MSGID="${2:?message_id required}"
    TO="${3:?to required}"
    DROP_A=false
    [ "${4:-}" = "--drop-author" ] && DROP_A=true
    bash "$MCP" forward_message \
      "$(jq -n --arg f "$FROM" --argjson m "$MSGID" --arg t "$TO" --argjson d "$DROP_A" \
        '{from_chat:$f, message_id:$m, to_chat:$t, drop_author:$d}')"
    ;;

  subscribe)
    bash "$MCP" subscribe_to_channel "$(jq -n --arg c "${1:?channel required}" '{channel:$c}')"
    ;;

  dm)
    USER="${1:?username required}"
    TEXT_SRC="${2:?text required}"
    if [ -f "$TEXT_SRC" ]; then TEXT=$(cat "$TEXT_SRC"); else TEXT="$TEXT_SRC"; fi
    bash "$MCP" send_dm "$(jq -n --arg u "$USER" --arg t "$TEXT" '{username:$u, text:$t}')"
    ;;

  metrics)
    bash "$MCP" get_telegram_metrics
    ;;

  download)
    CHAT="${1:?chat_id required}"
    MSGID="${2:?message_id required}"
    DEST_DIR="${3:?dest_dir required}"
    FNAME="${4:-}"
    mkdir -p "$DEST_DIR"
    # Long-running — bump timeout to 30 min for ~2GB files
    MCP_TIMEOUT=1800 bash "$MCP" download_media \
      "$(jq -n --arg c "$CHAT" --argjson m "$MSGID" --arg dd "$DEST_DIR" --arg fn "$FNAME" \
        '{chat_id:$c, message_id:$m, dest_dir:$dd} +
         (if $fn != "" then {filename:$fn} else {} end)')"
    ;;

  transcribe)
    MEDIA="${1:?media_path required}"
    shift
    bash "$SKILL_DIR/lib/transcribe.sh" "$MEDIA" "$@"
    ;;

  extract-segments)
    INPUT="${1:?transcript.json required}"
    shift
    bash "$SKILL_DIR/lib/extract-segments.sh" "$INPUT" "$@"
    ;;

  list_scheduled)
    CH="${1:?channel required}"
    LIMIT="${2:-20}"
    bash "$MCP" list_scheduled "$(jq -n --arg c "$CH" --argjson l "$LIMIT" '{channel:$c, limit:$l}')"
    ;;

  publish_now)
    CH="${1:?channel required}"
    SID="${2:?scheduled_id required}"
    bash "$MCP" send_scheduled_now \
      "$(jq -n --arg c "$CH" --argjson s "$SID" '{channel:$c, scheduled_id:$s}')"
    ;;

  cancel)
    CH="${1:?channel required}"
    SID="${2:?scheduled_id required}"
    bash "$MCP" delete_scheduled \
      "$(jq -n --arg c "$CH" --argjson s "$SID" '{channel:$c, scheduled_id:$s}')"
    ;;

  reschedule)
    CH="${1:?channel required}"
    SID="${2:?scheduled_id required}"
    NEW_RAW="${3:?new schedule required (ISO or +Nh / +Nm)}"
    NEW_ISO=$(resolve_schedule "$NEW_RAW")
    bash "$MCP" reschedule_scheduled \
      "$(jq -n --arg c "$CH" --argjson s "$SID" --arg d "$NEW_ISO" \
        '{channel:$c, scheduled_id:$s, new_schedule_date:$d}')"
    ;;

  edit_sched)
    CH="${1:?channel required}"; SID="${2:?scheduled_id required}"; shift 2
    NEW_TEXT=""; NEW_IMG=""; NEW_AT_RAW=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --text=*)  NEW_TEXT=$(cat "${1#--text=}") ;;
        --image=*) NEW_IMG="${1#--image=}" ;;
        --at=*)    NEW_AT_RAW="${1#--at=}" ;;
      esac
      shift
    done
    NEW_AT_ISO=""
    [ -n "$NEW_AT_RAW" ] && NEW_AT_ISO=$(resolve_schedule "$NEW_AT_RAW")
    bash "$MCP" edit_scheduled \
      "$(jq -n --arg c "$CH" --argjson s "$SID" --arg t "$NEW_TEXT" --arg i "$NEW_IMG" --arg a "$NEW_AT_ISO" \
        '{channel:$c, scheduled_id:$s} +
         (if $t != "" then {new_text:$t} else {} end) +
         (if $i != "" then {new_image_path:$i} else {} end) +
         (if $a != "" then {new_schedule_date:$a} else {} end)')"
    ;;

  *) usage ;;
esac
