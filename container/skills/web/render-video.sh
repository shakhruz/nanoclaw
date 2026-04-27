#!/usr/bin/env bash
# render-video.sh — host-side Remotion renderer wrapper.
# Mila в контейнерах вызывает через admin-ipc action `render_video`.
#
# Usage:
#   render-video.sh <composition> <props-json> [output-name]
#
#   composition  — Reel | Short | TgVideo (см. ~/apps/remotion-videos/src/Root.tsx)
#   props-json   — JSON строка с props композиции
#   output-name  — опциональное имя файла (default: <composition>-<timestamp>.mp4)
#
# Output (JSON):
#   {"path": "/Users/milagpt/apps/remotion-videos/out/<file>.mp4",
#    "size_mb": 1.2, "duration_s": 60, "composition": "Reel"}
#
# Тhe MP4 file is on host filesystem. Caller (admin-ipc executor) копирует
# в /workspace/global/attachments/ или возвращает path для прямого attach в Telegram.

set -eo pipefail

# Ensure node/npx + ffmpeg in PATH (launchd-spawned daemon has minimal PATH)
export PATH="/Users/milagpt/.local/share/fnm/aliases/default/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

COMPOSITION="${1:?usage: render-video.sh <composition> <props-json> [output-name]}"
PROPS_JSON="${2:-}"
[ -z "$PROPS_JSON" ] && PROPS_JSON='{}'
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUT_NAME="${3:-${COMPOSITION}-${TIMESTAMP}.mp4}"

PROJECT_DIR="${REMOTION_PROJECT_DIR:-$HOME/apps/remotion-videos}"
[ -d "$PROJECT_DIR" ] || { echo '{"error":1,"description":"Remotion project not found at '"$PROJECT_DIR"'"}'; exit 1; }

OUT_DIR="$PROJECT_DIR/out"
mkdir -p "$OUT_DIR"
OUT_PATH="$OUT_DIR/$OUT_NAME"

# Validate composition name
case "$COMPOSITION" in
  Reel|Short|TgVideo) ;;
  *) echo "{\"error\":1,\"description\":\"Unknown composition '$COMPOSITION'. Available: Reel, Short, TgVideo\"}"; exit 1 ;;
esac

# Validate props JSON
if ! echo "$PROPS_JSON" | jq empty 2>/dev/null; then
  echo "{\"error\":1,\"description\":\"Invalid props-json (must be valid JSON object)\"}"
  exit 1
fi

# Render
cd "$PROJECT_DIR"
npx remotion render src/index.ts "$COMPOSITION" "$OUT_PATH" \
  --props="$PROPS_JSON" \
  --log=error 2>&1 >/dev/null || {
    echo "{\"error\":1,\"description\":\"Render failed — see remotion stderr\"}"
    exit 1
  }

[ ! -f "$OUT_PATH" ] && { echo "{\"error\":1,\"description\":\"Render claimed success but file missing: $OUT_PATH\"}"; exit 1; }

SIZE_MB=$(python3 -c "import os; print(round(os.path.getsize('$OUT_PATH')/1024/1024, 2))")

# Get duration via ffprobe (already on host)
DURATION_S=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUT_PATH" 2>/dev/null | head -1 | awk '{printf "%.1f", $1}')

jq -n --arg p "$OUT_PATH" --arg c "$COMPOSITION" --arg s "$SIZE_MB" --arg d "$DURATION_S" --arg n "$OUT_NAME" \
  '{path:$p, name:$n, composition:$c, size_mb:($s|tonumber), duration_s:($d|tonumber)}'
