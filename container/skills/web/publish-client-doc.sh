#!/usr/bin/env bash
# publish-client-doc.sh — публикация клиентского документа (КП, договор, счёт)
# на milagpt.cc с секретным URL, noindex-заголовками и записью в ledger.
#
# Usage:
#   publish-client-doc.sh <client-slug> <doc-type> <short-title> <html-file> [note]
#     client-slug:  kebab-case имя клиента (acme-corp, solidrealty)
#     doc-type:     proposal | contract | invoice | doc
#     short-title:  короткое описание kebab-case (ai-director, consulting-q2)
#     html-file:    путь к HTML-документу
#     note:         (опц.) внутренний комментарий в ledger
#
# Возвращает JSON: {"url":"...", "commit":"...", "secret":"...", "ledger_entry":{...}}
#
# Переменные окружения:
#   MILAGPT_CC_DIR   (дефолт: $HOME/apps/milagpt-cc)
#   LEDGER_FILE      (дефолт: /workspace/global/web-projects/client-docs/ledger.jsonl
#                    или $HOME/nanoclaw/nanoclaw/groups/global/web-projects/client-docs/ledger.jsonl)
#   VERCEL_SCOPE     (дефолт: milagpt)
#   NO_DEPLOY=1      — не звать vercel deploy

set -eo pipefail

CLIENT="${1:?usage: publish-client-doc.sh <client-slug> <doc-type> <title> <html-file> [note]}"
DOCTYPE="${2:?doc-type required}"
TITLE="${3:?title required}"
SRC="${4:?html file required}"
NOTE="${5:-}"

case "$DOCTYPE" in
  proposal|contract|invoice|doc) ;;
  *) echo "err: doc-type must be: proposal, contract, invoice, doc" >&2; exit 1 ;;
esac

validate_slug() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,60}$ ]] || { echo "err: '$1' not valid kebab-case slug" >&2; exit 1; }
}
validate_slug "$CLIENT"
validate_slug "$TITLE"

[ -f "$SRC" ] || { echo "err: html file not found: $SRC" >&2; exit 1; }

REPO_DIR="${MILAGPT_CC_DIR:-$HOME/apps/milagpt-cc}"
SCOPE="${VERCEL_SCOPE:-milagpt}"

[ -d "$REPO_DIR/.git" ] || { echo "err: not a git repo: $REPO_DIR" >&2; exit 1; }

# Ledger path: prefer container-mounted global dir, fallback to host dev path
if [ -n "${LEDGER_FILE:-}" ]; then
  LEDGER="$LEDGER_FILE"
elif [ -d "/workspace/global/web-projects/client-docs" ]; then
  LEDGER="/workspace/global/web-projects/client-docs/ledger.jsonl"
elif [ -d "$HOME/nanoclaw/nanoclaw/groups/global/web-projects/client-docs" ]; then
  LEDGER="$HOME/nanoclaw/nanoclaw/groups/global/web-projects/client-docs/ledger.jsonl"
else
  LEDGER="$REPO_DIR/.client-docs-ledger.jsonl"  # fallback
fi
mkdir -p "$(dirname "$LEDGER")"

# секрет: 7 символов base32 без визуально-неоднозначных (01lio)
# tr|head ломает pipefail (SIGPIPE); читаем блоком фиксированного размера и фильтруем
gen_secret() {
  local raw
  raw=$(LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyz23456789' < <(head -c 256 /dev/urandom))
  printf '%s' "${raw:0:7}"
}
SECRET=$(gen_secret)
[ ${#SECRET} -eq 7 ] || { echo "err: failed to generate secret" >&2; exit 1; }

SLUG="${DOCTYPE}-${TITLE}-${SECRET}"
DEST_REL="public/c/${CLIENT}/${SLUG}/index.html"
DEST="$REPO_DIR/$DEST_REL"
URL="https://milagpt.cc/c/${CLIENT}/${SLUG}"

mkdir -p "$(dirname "$DEST")"

# Инжектируем noindex meta, если его нет в HTML
if grep -qiE '<meta[^>]+name=["'\'']?robots' "$SRC"; then
  cp "$SRC" "$DEST"
else
  # вставить сразу после <head> (нечувствительно к регистру)
  awk 'BEGIN{done=0} {
    if (!done && tolower($0) ~ /<head>/) {
      print
      print "<meta name=\"robots\" content=\"noindex, nofollow, noarchive, nosnippet\">"
      done=1
    } else { print }
  }' "$SRC" > "$DEST"
  # если <head> не нашёлся — просто кладём файл
  [ -s "$DEST" ] || cp "$SRC" "$DEST"
fi

cd "$REPO_DIR"
git add "$DEST_REL"

if git diff --cached --quiet; then
  echo "err: no changes staged (файл совпадает с существующим)" >&2
  exit 1
fi

git commit -m "publish(client): ${CLIENT} ${DOCTYPE} ${TITLE}" >/dev/null

PUSH_OK=1
git push origin main >/dev/null 2>&1 || PUSH_OK=0

DEPLOYMENT_URL=""
if [ -z "${NO_DEPLOY:-}" ]; then
  DEPLOYMENT_URL=$(vercel deploy --prod --scope "$SCOPE" --yes 2>&1 | grep -Eo 'https://[a-z0-9-]+\.vercel\.app' | head -1)
fi

COMMIT=$(git rev-parse --short HEAD)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PUBLISHED_BY="${NANOCLAW_GROUP:-host-cli}"

# ledger entry (JSONL)
ENTRY=$(jq -cn \
  --arg ts "$NOW" \
  --arg client "$CLIENT" \
  --arg type "$DOCTYPE" \
  --arg title "$TITLE" \
  --arg secret "$SECRET" \
  --arg url "$URL" \
  --arg commit "$COMMIT" \
  --arg by "$PUBLISHED_BY" \
  --arg note "$NOTE" \
  '{published_at:$ts, client_slug:$client, doc_type:$type, title:$title, secret:$secret, url:$url, commit:$commit, published_by:$by, note:$note}')

echo "$ENTRY" >> "$LEDGER"

cat <<JSON
{"url":"$URL","commit":"$COMMIT","secret":"$SECRET","deployment":"$DEPLOYMENT_URL","push":$([ $PUSH_OK -eq 1 ] && echo true || echo false),"ledger_entry":$ENTRY}
JSON
