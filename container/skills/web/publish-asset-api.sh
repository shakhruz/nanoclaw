#!/usr/bin/env bash
# publish-asset-api.sh — публикация бинарного ассета (PNG/JPG/PDF/etc)
# из MILA-контейнера на milagpt.cc, БЕЗ host-CLI (gh/vercel).
#
# Использует только:
#   • curl (уже в контейнере) — GitHub Contents API
#   • npx (скачает vercel CLI при первом запуске) — для deploy
#   • jq + base64 (стандартные)
#
# Credentials — из /workspace/group/config.json:
#   github_token, github_repo (e.g. shakhruz/milagpt-cc)
#   vercel_token, vercel_scope, vercel_project
#
# Usage:
#   publish-asset-api.sh <category> <slug> <src-file> [dest-filename]
#     category — `w` (workshops) | `campaigns` | `assets` | `brand`
#     slug     — подпапка внутри категории, kebab-case
#                (e.g. `lichnyy-brend-2026-05-15`, `ads-may-2026`)
#     src-file — путь к локальному файлу в контейнере
#     dest-filename — опционально, имя файла в репо (default: basename src)
#
# URL:
#   https://milagpt.cc/<category>/<slug>/<filename>
#
# Идемпотентность: если файл уже существует, перезапишется.
# noindex: все пути под /<category>/ исключены в robots.txt / vercel.json.
#
# Возвращает JSON:
#   {"url":"https://milagpt.cc/w/.../hero.png","commit":"abc1234","deployment":"..."}

set -eo pipefail

CATEGORY="${1:?usage: publish-asset-api.sh <category> <slug> <src-file> [dest-filename]}"
SLUG="${2:?slug required}"
SRC="${3:?src file required}"
DEST_NAME="${4:-$(basename "$SRC")}"

case "$CATEGORY" in w|campaigns|assets|brand) ;; *) echo "err: category must be one of: w|campaigns|assets|brand" >&2; exit 1;; esac
[[ "$SLUG"      =~ ^[a-z0-9][a-z0-9-]{0,80}$ ]] || { echo "err: slug invalid (lowercase, digits, dashes, ≤80)" >&2; exit 1; }
[[ "$DEST_NAME" =~ ^[a-zA-Z0-9._-]{1,100}$    ]] || { echo "err: dest filename invalid" >&2; exit 1; }
[ -f "$SRC" ] || { echo "err: src file not found: $SRC" >&2; exit 1; }

CONFIG="${CONFIG:-/workspace/group/config.json}"
[ -f "$CONFIG" ] || { echo "err: config.json not found at $CONFIG" >&2; exit 1; }

GH_TOKEN=$(jq -r .github_token "$CONFIG")
GH_REPO=$(jq -r '.github_repo // "shakhruz/milagpt-cc"' "$CONFIG")
VC_TOKEN=$(jq -r .vercel_token "$CONFIG")
VC_SCOPE=$(jq -r '.vercel_scope // "milagpt"' "$CONFIG")

[ -n "$GH_TOKEN" ] && [ "$GH_TOKEN" != "null" ] || { echo "err: github_token missing in config.json" >&2; exit 1; }
[ -n "$VC_TOKEN" ] && [ "$VC_TOKEN" != "null" ] || { echo "err: vercel_token missing in config.json" >&2; exit 1; }

REPO_PATH="public/$CATEGORY/$SLUG/$DEST_NAME"
URL="https://milagpt.cc/$CATEGORY/$SLUG/$DEST_NAME"

# Encode file as base64 for GitHub Contents API.
B64=$(base64 -w0 "$SRC" 2>/dev/null || base64 "$SRC" | tr -d '\n')

# Check if file already exists (we need SHA for update, not create).
SHA=$(curl -sS -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/$GH_REPO/contents/$REPO_PATH" \
  | jq -r '.sha // empty')

COMMIT_MSG="publish: $CATEGORY/$SLUG/$DEST_NAME"
if [ -n "$SHA" ]; then
  COMMIT_MSG="update: $CATEGORY/$SLUG/$DEST_NAME"
fi

# Payload — GitHub's PUT /contents/<path> creates or updates a file.
PAYLOAD=$(jq -n \
  --arg msg "$COMMIT_MSG" \
  --arg content "$B64" \
  --arg branch "main" \
  --arg sha "$SHA" \
  'if $sha != "" then {message:$msg, content:$content, branch:$branch, sha:$sha}
   else {message:$msg, content:$content, branch:$branch} end')

RESP=$(curl -sS -X PUT \
  -H "Authorization: token $GH_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/$GH_REPO/contents/$REPO_PATH" \
  -d "$PAYLOAD")

COMMIT=$(echo "$RESP" | jq -r '.commit.sha // empty' | cut -c1-7)
[ -n "$COMMIT" ] || { echo "err: github push failed: $RESP" >&2; exit 1; }

# Trigger Vercel deploy. Without GitHub→Vercel OAuth integration this is
# still required; after that's set up, just git-push would auto-deploy.
DEPLOYMENT=""
if [ -z "${NO_DEPLOY:-}" ]; then
  DEPLOYMENT=$(cd /tmp && VERCEL_TOKEN="$VC_TOKEN" npx --yes vercel@latest deploy --prod \
    --token "$VC_TOKEN" --scope "$VC_SCOPE" --yes /tmp 2>&1 \
    | grep -Eo 'https://[a-z0-9-]+\.vercel\.app' | head -1 || echo "")
fi

jq -n \
  --arg url "$URL" \
  --arg commit "$COMMIT" \
  --arg deployment "$DEPLOYMENT" \
  --arg path "$REPO_PATH" \
  '{url:$url, commit:$commit, deployment:$deployment, path:$path}'
