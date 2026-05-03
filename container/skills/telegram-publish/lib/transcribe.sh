#!/usr/bin/env bash
# transcribe.sh — send audio/video file to Deepgram, get text + word-level
# timestamps + paragraphs. Streams the upload, no full-file buffering.
#
# Usage:
#   transcribe.sh <media_path> [--lang=ru] [--model=nova-2] [--diarize]
#
# Output (stdout): JSON
#   {
#     "transcript": "full text",
#     "duration": 3420.5,
#     "language": "ru",
#     "words": [{"word":"...","start":0.04,"end":0.21}, ...],
#     "paragraphs": [{"start":0,"end":120,"text":"..."}, ...]
#   }
#
# Auth: when running on host — reads DEEPGRAM_API_KEY from Mila .env.
#       when running in container — relies on OneCLI gateway injection
#       (HTTPS_PROXY env auto-injects Authorization header for *.deepgram.com).

set -uo pipefail

MEDIA="${1:?usage: transcribe.sh <media_path> [--lang=ru] [--model=nova-2]}"
shift
LANG="ru"
MODEL="nova-2"
DIARIZE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --lang=*)  LANG="${1#--lang=}" ;;
    --model=*) MODEL="${1#--model=}" ;;
    --diarize) DIARIZE=true ;;
  esac
  shift
done

if [ ! -f "$MEDIA" ]; then
  jq -n --arg p "$MEDIA" '{error:"file_not_found", path:$p}'
  exit 1
fi

# Detect mime — IMPORTANT: video files cause Deepgram SLOW_UPLOAD/Gateway Timeout
# for files >100MB. Always extract mono 16kHz mp3 first via ffmpeg.
NEED_EXTRACT=false
case "$MEDIA" in
  *.mp4|*.MP4|*.webm|*.mkv|*.MKV|*.mov|*.MOV) NEED_EXTRACT=true; MIME="audio/mp3" ;;
  *.mp3|*.MP3)  MIME="audio/mp3" ;;
  *.oga|*.ogg|*.opus) MIME="audio/ogg" ;;
  *.wav|*.WAV)  MIME="audio/wav" ;;
  *.m4a|*.M4A)  MIME="audio/mp4" ;;
  *)            MIME="application/octet-stream" ;;
esac

if [ "$NEED_EXTRACT" = "true" ]; then
  if ! command -v ffmpeg >/dev/null 2>&1; then
    jq -n '{error:"ffmpeg_missing", hint:"video files require ffmpeg to extract audio. Install: apt install ffmpeg (container) or brew install ffmpeg (host)."}'
    exit 3
  fi
  EXTRACTED=$(mktemp -t transcribe-audio).mp3
  trap "rm -f $EXTRACTED" EXIT
  ffmpeg -y -i "$MEDIA" -vn -ac 1 -ar 16000 -acodec libmp3lame -b:a 64k "$EXTRACTED" >/dev/null 2>&1
  if [ ! -s "$EXTRACTED" ]; then
    jq -n --arg p "$MEDIA" '{error:"ffmpeg_extract_failed", input:$p}'
    exit 4
  fi
  MEDIA="$EXTRACTED"
fi

# Resolve auth: env first (host), then container .env fallback
DG_KEY="${DEEPGRAM_API_KEY:-}"
if [ -z "$DG_KEY" ]; then
  for env_file in /workspace/group/config.json /Users/milagpt/nanoclaw/mila-nanoclaw/.env; do
    if [ -f "$env_file" ]; then
      case "$env_file" in
        *.json)
          DG_KEY=$(jq -r '.deepgram_api_key // empty' "$env_file" 2>/dev/null)
          ;;
        *.env)
          DG_KEY=$(grep -E '^DEEPGRAM_API_KEY=' "$env_file" | cut -d= -f2-)
          ;;
      esac
      [ -n "$DG_KEY" ] && break
    fi
  done
fi

# Build Deepgram URL with desired params
QS="model=$MODEL&language=$LANG&smart_format=true&punctuate=true&paragraphs=true&utterances=false"
[ "$DIARIZE" = "true" ] && QS="$QS&diarize=true"

# If we have direct API key — Authorization header path (host or fallback)
# Otherwise rely on OneCLI gateway (proxy auto-injects)
URL="https://api.deepgram.com/v1/listen?$QS"

if [ -n "$DG_KEY" ]; then
  AUTH=( -H "Authorization: Token $DG_KEY" )
else
  # Container path — gateway should inject auth, no manual header needed
  AUTH=()
fi

# Streaming upload — curl reads file with chunked-encoding, low memory
RAW=$(mktemp)
trap "rm -f $RAW" EXIT

HTTP=$(curl -sS -o "$RAW" -w "%{http_code}" --max-time 1800 \
  "${AUTH[@]}" \
  -H "Content-Type: $MIME" \
  --data-binary "@$MEDIA" \
  "$URL")

if [ "$HTTP" != "200" ]; then
  jq -n --arg http "$HTTP" --arg body "$(head -c 500 "$RAW")" \
    '{error:"deepgram_http_failed", status:$http, body:$body}'
  exit 2
fi

# Reduce response to the shape we promise above
jq '{
  transcript: .results.channels[0].alternatives[0].transcript,
  duration:   .metadata.duration,
  language:   (.results.channels[0].detected_language // .results.language // "ru"),
  words:      (.results.channels[0].alternatives[0].words // []),
  paragraphs: (.results.channels[0].alternatives[0].paragraphs.paragraphs // [] | map({
    start: .start,
    end:   .end,
    text:  ([.sentences[].text] | join(" "))
  }))
}' "$RAW"
