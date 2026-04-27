#!/usr/bin/env bash
# refresh-inventory.sh — собирает /workspace/global/web-projects/inventory.json
# из Vercel (scope milagpt) и GitHub (user shakhruz), плюс склеивает ~/apps/.
#
# Usage: refresh-inventory.sh [--dry-run]
#   --dry-run: печатает в stdout, не пишет файл

set -eo pipefail

STATE_DIR="${TG_WEB_STATE_DIR:-/workspace/global/web-projects}"
APPS_DIR="${APPS_DIR:-$HOME/apps}"
SCOPE="${VERCEL_SCOPE:-milagpt}"
GH_USER="${GH_USER:-shakhruz}"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

if ! command -v vercel >/dev/null; then echo "err: vercel not installed" >&2; exit 1; fi
if ! command -v gh >/dev/null; then echo "err: gh not installed" >&2; exit 1; fi
if ! command -v jq >/dev/null; then echo "err: jq not installed" >&2; exit 1; fi

mkdir -p "$STATE_DIR"

# 1) Vercel projects — текстовый вывод CLI, собираем постранично по хинту
VERCEL_TMP=$(mktemp)
: > "$VERCEL_TMP.full"      # полный вывод всех страниц (с хинтами)
: > "$VERCEL_TMP.projects"  # только строки с проектами

set +eo pipefail
NEXT_ARG=""
MAX_PAGES=10
for i in $(seq 1 $MAX_PAGES); do
  PAGE=$(vercel project ls --scope "$SCOPE" $NEXT_ARG 2>&1)
  [ -z "$PAGE" ] && break
  printf "%s\n" "$PAGE" >> "$VERCEL_TMP.full"
  # строки с проектами: имеют ≥2 колонки, не начинаются с >, не header
  printf "%s\n" "$PAGE" | awk '
    $1 != "" && $1 !~ /^>/ && $1 != "Project" && $1 != "Fetching" && NF>=2 { print }
  ' >> "$VERCEL_TMP.projects"
  NEXT=$(printf "%s\n" "$PAGE" | grep -Eo -- '--next [0-9]+' | tail -1 | awk '{print $2}')
  [ -z "$NEXT" ] && break
  NEXT_ARG="--next $NEXT"
done
set -eo pipefail

# парсим в jsonl
awk '
  NF>=2 {
    name=$1; url=$2
    updated = NF>=3 ? $(NF-1) : ""
    node    = NF>=4 ? $NF     : ""
    gsub(/"/, "\\\"", name); gsub(/"/, "\\\"", url)
    printf("{\"vercel_project\":\"%s\",\"vercel_prod_url\":\"%s\",\"updated\":\"%s\",\"node\":\"%s\"}\n", name, url, updated, node)
  }
' "$VERCEL_TMP.projects" > "$VERCEL_TMP.jsonl"

# 2) Vercel domains — тоже stderr
vercel domains ls --scope "$SCOPE" 2>&1 \
  | awk '$1 != "" && $1 !~ /^>/ && $1 != "Domain" && $1 != "Fetching" && NF>=2 {print $1}' \
  > "$VERCEL_TMP.domains" || true

# 3) GitHub repos
gh repo list "$GH_USER" --limit 200 \
  --json name,url,description,updatedAt,isArchived,defaultBranchRef,sshUrl 2>/dev/null \
  > "$VERCEL_TMP.repos.json" || echo "[]" > "$VERCEL_TMP.repos.json"

# 4) Local clones in ~/apps
LOCAL_JSON="[]"
if [ -d "$APPS_DIR" ]; then
  LOCAL_JSON=$(
    find "$APPS_DIR" -maxdepth 2 -name ".git" -type d 2>/dev/null \
    | while read g; do
        dir=$(dirname "$g")
        slug=$(basename "$dir")
        remote=$(git -C "$dir" remote get-url origin 2>/dev/null | sed -E 's#git@github.com:#https://github.com/#; s#\.git$##' || echo "")
        last=$(git -C "$dir" log -1 --format=%cI 2>/dev/null || echo "")
        jq -n --arg slug "$slug" --arg dir "$dir" --arg remote "$remote" --arg last "$last" \
          '{slug:$slug, local_path:$dir, github_url:$remote, last_commit:$last}'
      done \
    | jq -s '.'
  )
fi

# 5) Склейка
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OUT=$(mktemp)

jq -n \
  --slurpfile vp <(jq -s '.' "$VERCEL_TMP.jsonl" 2>/dev/null || echo "[]") \
  --slurpfile repos "$VERCEL_TMP.repos.json" \
  --argjson locals "$LOCAL_JSON" \
  --rawfile domains "$VERCEL_TMP.domains" \
  --arg now "$NOW" \
  '{
    updated_at: $now,
    vercel_projects: ($vp[0] // []),
    vercel_domains: ($domains | split("\n") | map(select(length>0))),
    github_repos: $repos[0],
    local_clones: $locals
  }' > "$OUT"

if [ "$DRY" = "1" ]; then
  cat "$OUT"
else
  mv "$OUT" "$STATE_DIR/inventory.json"
  echo "$NOW" > "$STATE_DIR/last-refresh.txt"
  # summary на stdout
  jq '{
    updated_at,
    vercel_projects: (.vercel_projects | length),
    vercel_domains: (.vercel_domains | length),
    github_repos: (.github_repos | length),
    local_clones: (.local_clones | length)
  }' "$STATE_DIR/inventory.json"
fi

rm -f "$VERCEL_TMP" "$VERCEL_TMP.full" "$VERCEL_TMP.projects" "$VERCEL_TMP.jsonl" "$VERCEL_TMP.domains" "$VERCEL_TMP.repos.json" 2>/dev/null || true
