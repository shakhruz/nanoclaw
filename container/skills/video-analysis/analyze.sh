#!/usr/bin/env bash
# video-analysis pipeline: download (if URL) → metadata → frame sampling → audio → whisper → JSON
# See SKILL.md in the same dir for full doc.
set -euo pipefail

INPUT=""
LANGUAGE="auto"
NO_FRAMES=0
NO_TRANSCRIBE=0
NO_CACHE=0
WHISPER_MODEL_OVERRIDE=""
MAX_FRAMES=""
EXTRACT_AT=""
CACHE_DIR="/workspace/group/cache/video-analysis"
OUTPUT_PATH=""
WORK_BASE="${TMPDIR:-/tmp}/va"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2;;
    --language) LANGUAGE="$2"; shift 2;;
    --no-frames) NO_FRAMES=1; shift;;
    --no-transcribe) NO_TRANSCRIBE=1; shift;;
    --no-cache) NO_CACHE=1; shift;;
    --whisper-model) WHISPER_MODEL_OVERRIDE="$2"; shift 2;;
    --max-frames) MAX_FRAMES="$2"; shift 2;;
    --extract-frames-at) EXTRACT_AT="$2"; shift 2;;
    --cache-dir) CACHE_DIR="$2"; shift 2;;
    --output) OUTPUT_PATH="$2"; shift 2;;
    -h|--help) sed -n '/## Options reference/,/## Failure modes/p' "$(dirname "$0")/SKILL.md"; exit 0;;
    *) echo "unknown flag: $1" >&2; exit 2;;
  esac
done

[[ -z "$INPUT" ]] && { echo "usage: analyze.sh --input <path|url> [...flags]" >&2; exit 2; }

WHISPER_MODEL_USE="${WHISPER_MODEL_OVERRIDE:-${WHISPER_MODEL:-small}}"
WHISPER_MODEL_DIR_USE="${WHISPER_MODEL_DIR:-/opt/whisper-models}"
mkdir -p "$CACHE_DIR" "$WORK_BASE"

log() { echo "[video-analysis] $*" >&2; }
err() { echo "[video-analysis ERROR] $*" >&2; }

# --- 1. Resolve input → local file path ----------------------------------------
LOCAL_FILE=""
DOWNLOAD_DIR=""
if [[ "$INPUT" =~ ^https?:// ]]; then
  TMPHASH=$(printf '%s' "$INPUT" | sha256sum | cut -c1-16)
  DOWNLOAD_DIR="$WORK_BASE/dl_$TMPHASH"
  mkdir -p "$DOWNLOAD_DIR"
  log "downloading via yt-dlp: $INPUT"
  if ! yt-dlp -q --no-warnings -f 'bv*[height<=1080]+ba/b[height<=1080]/b' --merge-output-format mp4 \
      -o "$DOWNLOAD_DIR/video.%(ext)s" "$INPUT" 2>&1 | tee "$DOWNLOAD_DIR/dl.log" >&2; then
    err "yt-dlp failed; check $DOWNLOAD_DIR/dl.log"
    exit 3
  fi
  LOCAL_FILE=$(ls "$DOWNLOAD_DIR"/video.* 2>/dev/null | head -1)
  if [[ -z "$LOCAL_FILE" || ! -f "$LOCAL_FILE" ]]; then
    err "yt-dlp completed but no file produced in $DOWNLOAD_DIR"
    exit 3
  fi
else
  if [[ ! -f "$INPUT" ]]; then
    err "file not found: $INPUT"; exit 3
  fi
  LOCAL_FILE="$INPUT"
fi
log "local file: $LOCAL_FILE"

# --- 2. Hash + cache lookup ----------------------------------------------------
FILE_HASH=$(sha256sum "$LOCAL_FILE" | cut -c1-32)
CACHE_FILE="$CACHE_DIR/$FILE_HASH.json"
if [[ "$NO_CACHE" -eq 0 && -f "$CACHE_FILE" ]]; then
  AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ) / 86400 ))
  if (( AGE_DAYS < 30 )); then
    log "cache hit (age ${AGE_DAYS}d): $CACHE_FILE"
    if [[ -n "$OUTPUT_PATH" ]]; then cp "$CACHE_FILE" "$OUTPUT_PATH"; else cat "$CACHE_FILE"; fi
    exit 0
  fi
fi

# --- 3. Metadata via ffprobe ---------------------------------------------------
PROBE_JSON=$(ffprobe -v quiet -print_format json -show_format -show_streams "$LOCAL_FILE")
DURATION=$(echo "$PROBE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(float(d['format'].get('duration', 0)))")
WIDTH=$(echo "$PROBE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); v=[s for s in d['streams'] if s['codec_type']=='video']; print(v[0]['width'] if v else 0)")
HEIGHT=$(echo "$PROBE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); v=[s for s in d['streams'] if s['codec_type']=='video']; print(v[0]['height'] if v else 0)")
HAS_AUDIO=$(echo "$PROBE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print('true' if any(s['codec_type']=='audio' for s in d['streams']) else 'false')")

IS_ROUND="false"
if [[ "$WIDTH" -gt 0 && "$HEIGHT" -gt 0 && "$WIDTH" -eq "$HEIGHT" && "${DURATION%.*}" -le 60 ]]; then
  IS_ROUND="true"
fi
log "duration=${DURATION}s ${WIDTH}x${HEIGHT} round=$IS_ROUND audio=$HAS_AUDIO"

# Hard limit at 2h — caller should have warned the user
DURATION_INT=${DURATION%.*}
if (( DURATION_INT > 7200 )); then
  err "video > 2h (${DURATION_INT}s) — refusing without explicit override"
  exit 4
fi

# --- 4. Frame sampling ---------------------------------------------------------
FRAMES_DIR="$WORK_BASE/frames_$FILE_HASH"
mkdir -p "$FRAMES_DIR"
FRAME_COUNT=0

extract_at_timestamps() {
  # $1 = csv of seconds; emit JPEGs frame_<sec>.jpg, downscaled to 1024px max side
  local csv="$1" sec
  IFS=',' read -ra TS <<< "$csv"
  for sec in "${TS[@]}"; do
    sec=$(printf '%s' "$sec" | tr -d ' ')
    [[ -z "$sec" ]] && continue
    ffmpeg -nostdin -loglevel error -ss "$sec" -i "$LOCAL_FILE" -frames:v 1 \
      -vf "scale='min(1024,iw)':'-2'" -q:v 4 -y "$FRAMES_DIR/frame_$(printf '%05d' "${sec%.*}").jpg" || true
  done
  FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.jpg 2>/dev/null | wc -l | tr -d ' ')
}

if [[ "$NO_FRAMES" -eq 1 ]]; then
  log "frame extraction skipped (--no-frames)"
elif [[ -n "$EXTRACT_AT" ]]; then
  log "extracting at custom timestamps: $EXTRACT_AT"
  extract_at_timestamps "$EXTRACT_AT"
else
  # Pick strategy by duration
  if (( DURATION_INT < 30 )); then
    STRAT="fps1"; LIMIT_DEFAULT=30
    ffmpeg -nostdin -loglevel error -i "$LOCAL_FILE" \
      -vf "fps=1,scale='min(1024,iw)':'-2'" -q:v 4 \
      "$FRAMES_DIR/frame_%05d.jpg" -y 2>&1 | grep -v "deprecated" >&2 || true
  elif (( DURATION_INT < 300 )); then
    STRAT="iframes"; LIMIT_DEFAULT=30
    ffmpeg -nostdin -loglevel error -skip_frame nokey -i "$LOCAL_FILE" \
      -vsync vfr -frame_pts true -vf "scale='min(1024,iw)':'-2'" -q:v 4 \
      "$FRAMES_DIR/frame_%05d.jpg" -y 2>&1 | grep -v "deprecated" >&2 || true
  elif (( DURATION_INT < 1800 )); then
    STRAT="iframes_plus_30s"; LIMIT_DEFAULT=40
    ffmpeg -nostdin -loglevel error -skip_frame nokey -i "$LOCAL_FILE" \
      -vsync vfr -frame_pts true -vf "scale='min(1024,iw)':'-2'" -q:v 4 \
      "$FRAMES_DIR/iframe_%05d.jpg" -y 2>&1 | grep -v "deprecated" >&2 || true
    ffmpeg -nostdin -loglevel error -i "$LOCAL_FILE" \
      -vf "fps=1/30,scale='min(1024,iw)':'-2'" -q:v 4 \
      "$FRAMES_DIR/sparse_%05d.jpg" -y 2>&1 | grep -v "deprecated" >&2 || true
  else
    # > 30 min — caller should use 2-pass (--no-frames first, then --extract-frames-at)
    STRAT="long_video_two_pass_required"
    LIMIT_DEFAULT=60
    log "video > 30 min: emitted no frames; caller should run 2-pass via --extract-frames-at"
  fi

  CAP=${MAX_FRAMES:-$LIMIT_DEFAULT}
  # Trim to CAP — sort by name and remove extras
  mapfile -t ALL_FRAMES < <(ls "$FRAMES_DIR"/*.jpg 2>/dev/null | sort)
  if (( ${#ALL_FRAMES[@]} > CAP )); then
    log "trimming ${#ALL_FRAMES[@]} → $CAP frames (every Nth)"
    STRIDE=$(( ${#ALL_FRAMES[@]} / CAP ))
    (( STRIDE < 1 )) && STRIDE=1
    KEEP_DIR="$FRAMES_DIR.kept"
    mkdir -p "$KEEP_DIR"
    i=0
    for f in "${ALL_FRAMES[@]}"; do
      if (( i % STRIDE == 0 )); then mv "$f" "$KEEP_DIR/"; fi
      i=$(( i + 1 ))
    done
    rm -rf "$FRAMES_DIR"
    mv "$KEEP_DIR" "$FRAMES_DIR"
  fi
  FRAME_COUNT=$(ls "$FRAMES_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
  log "frames extracted: $FRAME_COUNT (strategy=$STRAT)"
fi

# --- 5. Whisper transcript -----------------------------------------------------
TRANSCRIPT_JSON='{}'
if [[ "$NO_TRANSCRIBE" -eq 1 ]]; then
  log "transcript skipped (--no-transcribe)"
  TRANSCRIPT_JSON='null'
elif [[ "$HAS_AUDIO" != "true" ]]; then
  log "no audio track; transcript empty"
  TRANSCRIPT_JSON='{"text":"","segments":[],"language":""}'
else
  WAV="$WORK_BASE/audio_$FILE_HASH.wav"
  ffmpeg -nostdin -loglevel error -i "$LOCAL_FILE" -vn -ac 1 -ar 16000 -f wav -y "$WAV" >&2
  log "transcribing with faster-whisper model=$WHISPER_MODEL_USE lang=$LANGUAGE"
  TRANSCRIPT_JSON=$(WHISPER_MODEL_USE="$WHISPER_MODEL_USE" WHISPER_MODEL_DIR_USE="$WHISPER_MODEL_DIR_USE" LANG_USE="$LANGUAGE" \
    "${WHISPER_VENV:-/opt/whisper-venv}/bin/python3" - "$WAV" <<'PY'
import json, os, sys
from faster_whisper import WhisperModel
wav = sys.argv[1]
model_size = os.environ.get("WHISPER_MODEL_USE", "small")
model_dir = os.environ.get("WHISPER_MODEL_DIR_USE", "/opt/whisper-models")
lang = os.environ.get("LANG_USE", "auto")
model = WhisperModel(model_size, device="cpu", compute_type="int8", download_root=model_dir)
kwargs = {"vad_filter": True}
if lang != "auto":
    kwargs["language"] = lang
segments, info = model.transcribe(wav, **kwargs)
segs = [{"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip()} for s in segments]
out = {"text": " ".join(s["text"] for s in segs), "segments": segs, "language": info.language}
print(json.dumps(out, ensure_ascii=False))
PY
)
  rm -f "$WAV"
fi

# --- 6. Final JSON -------------------------------------------------------------
RESULT=$(python3 - <<PY
import json, os
out = {
  "duration_sec": float($DURATION),
  "resolution": "${WIDTH}x${HEIGHT}",
  "is_round_note": ${IS_ROUND},
  "has_audio": ${HAS_AUDIO},
  "frame_count": int("$FRAME_COUNT"),
  "frames_dir": "$FRAMES_DIR" if int("$FRAME_COUNT") > 0 else None,
  "transcript": json.loads('''$TRANSCRIPT_JSON''') if '''$TRANSCRIPT_JSON''' != 'null' else None,
  "source": "$INPUT",
  "local_file": "$LOCAL_FILE",
  "cached": False
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
)

# Cache
mkdir -p "$CACHE_DIR"
echo "$RESULT" > "$CACHE_FILE"

if [[ -n "$OUTPUT_PATH" ]]; then
  echo "$RESULT" > "$OUTPUT_PATH"
  log "wrote $OUTPUT_PATH"
else
  echo "$RESULT"
fi
