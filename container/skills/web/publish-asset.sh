#!/usr/bin/env bash
# publish-asset.sh — host-side (main) version using git+vercel CLI.
# For containerised MILA groups, use publish-asset-api.sh instead.
#
# Concurrency: serialized via flock on /tmp/milagpt-cc-publish.lock —
# multiple parallel deploys to milagpt-cc were causing Vercel build
# errors (race condition with prod alias). Now strictly sequential.

set -eo pipefail
CATEGORY="${1:?usage: publish-asset.sh <category> <slug> <src> [dest-filename]}"
SLUG="${2:?slug required}"
SRC="${3:?src required}"
DEST_NAME="${4:-$(basename "$SRC")}"

case "$CATEGORY" in w|campaigns|assets|brand) ;; *) echo "err: invalid category" >&2; exit 1;; esac
[[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]{0,80}$ ]] || { echo "err: invalid slug" >&2; exit 1; }
[ -f "$SRC" ] || { echo "err: src not found" >&2; exit 1; }

REPO_DIR="${MILAGPT_CC_DIR:-$HOME/apps/milagpt-cc}"
SCOPE="${VERCEL_SCOPE:-milagpt}"
DEST_REL="public/$CATEGORY/$SLUG/$DEST_NAME"
DEST="$REPO_DIR/$DEST_REL"
URL="https://milagpt.cc/$CATEGORY/$SLUG/$DEST_NAME"

LOCK_DIR="/tmp/milagpt-cc-publish.lock.d"
LOCK_TIMEOUT="${PUBLISH_LOCK_TIMEOUT:-300}"  # 5 min default

# Cross-platform lock (mkdir-based — atomic on POSIX, works on macOS + Linux)
acquire_lock() {
  local elapsed=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ $elapsed -ge $LOCK_TIMEOUT ]; then return 1; fi
  done
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
  return 0
}
if ! acquire_lock; then
  echo "err: failed to acquire publish lock within ${LOCK_TIMEOUT}s — another publish in progress" >&2
  exit 75
fi

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"

cd "$REPO_DIR"
git pull --rebase origin main >/dev/null 2>&1 || true  # avoid push conflicts
git add "$DEST_REL"
if git diff --cached --quiet; then
  echo "err: no changes — file identical" >&2; exit 1
fi
git commit -m "publish: $CATEGORY/$SLUG/$DEST_NAME" >/dev/null
PUSH_OK=1; git push origin main >/dev/null 2>&1 || PUSH_OK=0

DEPLOYMENT=""
if [ -z "${NO_DEPLOY:-}" ]; then
  DEPLOYMENT=$(vercel deploy --prod --scope "$SCOPE" --yes 2>/dev/null \
    | grep -Eo 'https://[a-z0-9-]+\.vercel\.app' | head -1 || echo "")
fi

COMMIT=$(git rev-parse --short HEAD)
jq -n --arg url "$URL" --arg commit "$COMMIT" --arg deployment "$DEPLOYMENT" --arg path "$DEST_REL" \
  '{url:$url, commit:$commit, deployment:$deployment, path:$path, push:'"$PUSH_OK"'}'
