#!/usr/bin/env bash
# extract-segments.sh — turn a Deepgram transcript into chapter-style
# timecodes suitable for YouTube descriptions and Telegram posts.
#
# Usage:
#   extract-segments.sh <transcript.json> [--target=10]   # ~10 chapters
#
# Strategy:
#   1. Read paragraphs from transcript (already produced by transcribe.sh).
#   2. Cluster paragraphs into ~target chapters, balancing duration ~equal.
#   3. For each chapter — pick a heading from the longest sentence in cluster
#      (truncated to 60 chars) as a placeholder. The agent should then refine
#      headings using Claude — this script's output is the structural skeleton.
#
# Output (stdout): JSON
#   {
#     "chapters": [
#       {"start_seconds": 0, "start_timestamp": "00:00", "headline_draft": "..."},
#       ...
#     ],
#     "total_duration": 3420.5,
#     "youtube_description_draft": "00:00 ...\n05:30 ..."
#   }

set -uo pipefail

INPUT="${1:?usage: extract-segments.sh <transcript.json> [--target=N]}"
TARGET=10
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --target=*) TARGET="${1#--target=}" ;;
  esac
  shift
done

if [ ! -f "$INPUT" ]; then
  jq -n --arg p "$INPUT" '{error:"file_not_found", path:$p}'
  exit 1
fi

jq --argjson target "$TARGET" '
  def fmt_ts:
    (. | floor) as $s
    | ($s / 60 | floor) as $m
    | ($m / 60 | floor) as $h
    | if $h > 0
        then "\($h):" + (($m % 60) | tostring | if length == 1 then "0" + . else . end)
            + ":" + (($s % 60) | tostring | if length == 1 then "0" + . else . end)
        else (($m | tostring | if length == 1 then "0" + . else . end))
            + ":" + (($s % 60) | tostring | if length == 1 then "0" + . else . end)
      end;

  .paragraphs as $paras
  | .duration as $dur
  | (if ($paras | length) < $target then ($paras | length) else $target end) as $n
  | (if $n == 0 then 1 else $n end) as $n
  | ($paras | length / $n | ceil) as $bucket
  | [range(0; $n) as $i | $paras[$i*$bucket : ($i+1)*$bucket]
       | select(length > 0)
       | (.[0].start) as $start
       | (.[-1].end) as $end
       | {
           start_seconds: $start,
           start_timestamp: ($start | fmt_ts),
           end_seconds:    $end,
           headline_draft: ([.[].text] | join(" ") | .[0:80] | gsub("[\\n\\r]"; " ") | .[0:60]),
         }
     ]
  | {
      chapters: .,
      total_duration: $dur,
      youtube_description_draft: (
        [.[] | "\(.start_timestamp) \(.headline_draft)"] | join("\n")
      )
    }
' "$INPUT"
