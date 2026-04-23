#!/usr/bin/env bash
# publish-html.sh — публикует HTML-файл на milagpt.cc.
#
# Usage:
#   publish-html.sh <type> <slug> <html-file>
#     type:  report | article | doc | page
#     slug:  kebab-case идентификатор, например "2026-04-23-cpr-media"
#     html-file: путь к HTML (локальный файл, который скопируется)
#
# Переменные окружения:
#   MILAGPT_CC_DIR   — путь к репо milagpt-cc (дефолт: $HOME/apps/milagpt-cc)
#   VERCEL_SCOPE     — scope для vercel CLI (дефолт: milagpt)
#   NO_DEPLOY=1      — не звать vercel deploy, только git push
#
# Exit:
#   0 успешно, печатает {"url": "https://milagpt.cc/...", "commit": "...", "deployment": "..."}
#   1 ошибка с описанием на stderr

set -eo pipefail

TYPE="${1:?usage: publish-html.sh <type> <slug> <html-file>}"
SLUG="${2:?slug required}"
SRC="${3:?html file path required}"

case "$TYPE" in
  report|article|doc|page) ;;
  *) echo "err: type must be one of: report, article, doc, page" >&2; exit 1 ;;
esac

if [[ ! "$SLUG" =~ ^[a-z0-9][a-z0-9-]{0,80}$ ]]; then
  echo "err: slug must be kebab-case (lowercase, digits, dashes), up to 80 chars" >&2
  exit 1
fi

[ -f "$SRC" ] || { echo "err: html file not found: $SRC" >&2; exit 1; }

REPO_DIR="${MILAGPT_CC_DIR:-$HOME/apps/milagpt-cc}"
SCOPE="${VERCEL_SCOPE:-milagpt}"

[ -d "$REPO_DIR/.git" ] || { echo "err: not a git repo: $REPO_DIR" >&2; exit 1; }

# page = /slug, остальные = /<type>/<slug>
if [ "$TYPE" = "page" ]; then
  DEST_REL="public/$SLUG/index.html"
  URL_PATH="/$SLUG"
else
  DEST_REL="public/${TYPE}s/$SLUG/index.html"
  URL_PATH="/${TYPE}s/$SLUG"
fi

DEST="$REPO_DIR/$DEST_REL"

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"

cd "$REPO_DIR"
git add "$DEST_REL"

if git diff --cached --quiet; then
  echo "err: no changes — file identical to existing" >&2
  exit 1
fi

git commit -m "publish: ${TYPE} ${SLUG}" >/dev/null

# push в remote (если fail — не блокируем deploy)
PUSH_OK=1
git push origin main >/dev/null 2>&1 || PUSH_OK=0

DEPLOYMENT_URL=""
if [ -z "${NO_DEPLOY:-}" ]; then
  # триггерим deploy через Vercel CLI (до интеграции GitHub→Vercel это обязательно)
  DEPLOYMENT_URL=$(vercel deploy --prod --scope "$SCOPE" --yes 2>/dev/null | grep -Eo 'https://[a-z0-9-]+\.vercel\.app' | head -1)
fi

COMMIT=$(git rev-parse --short HEAD)
FINAL_URL="https://milagpt.cc${URL_PATH}"

cat <<JSON
{"url":"$FINAL_URL","commit":"$COMMIT","deployment":"$DEPLOYMENT_URL","push":$([ $PUSH_OK -eq 1 ] && echo true || echo false)}
JSON
