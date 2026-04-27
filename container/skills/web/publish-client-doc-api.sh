#!/usr/bin/env bash
# publish-client-doc-api.sh — публикация клиентского документа из MILA-контейнера,
# БЕЗ host-CLI (gh/vercel). Использует только:
#   • git (уже в контейнере)
#   • curl (уже в контейнере)
#   • npx (скачает vercel CLI при первом запуске, ~30 сек)
#
# Credentials читаются из /workspace/group/config.json:
#   github_token, github_repo (e.g. shakhruz/milagpt-cc)
#   vercel_token, vercel_scope, vercel_project
#
# Usage: publish-client-doc-api.sh <client-slug> <doc-type> <title> <html-file> [note]
#
# Возвращает JSON через stdout:
#   {"url":"https://milagpt.cc/c/.../...","commit":"abc1234","secret":"a7f3k9m"}

set -eo pipefail

CLIENT="${1:?usage: publish-client-doc-api.sh <client> <type> <title> <html> [note]}"
DOCTYPE="${2:?doc-type required}"
TITLE="${3:?title required}"
SRC="${4:?html file required}"
NOTE="${5:-}"

case "$DOCTYPE" in proposal|contract|invoice|doc) ;; *) echo "err: type must be proposal|contract|invoice|doc" >&2; exit 1;; esac
[[ "$CLIENT" =~ ^[a-z0-9][a-z0-9-]{0,60}$ ]] || { echo "err: client slug invalid" >&2; exit 1; }
[[ "$TITLE"  =~ ^[a-z0-9][a-z0-9-]{0,60}$ ]] || { echo "err: title slug invalid" >&2; exit 1; }
[ -f "$SRC" ] || { echo "err: html file not found: $SRC" >&2; exit 1; }

CONFIG="${CONFIG:-/workspace/group/config.json}"
[ -f "$CONFIG" ] || { echo "err: config.json not found at $CONFIG" >&2; exit 1; }

GH_TOKEN=$(jq -r .github_token "$CONFIG")
GH_REPO=$(jq -r '.github_repo // "shakhruz/milagpt-cc"' "$CONFIG")
VC_TOKEN=$(jq -r .vercel_token "$CONFIG")
VC_SCOPE=$(jq -r '.vercel_scope // "milagpt"' "$CONFIG")
VC_PROJECT=$(jq -r '.vercel_project // "milagpt-cc"' "$CONFIG")

[ -n "$GH_TOKEN" ] && [ "$GH_TOKEN" != "null" ] || { echo "err: github_token missing in config.json" >&2; exit 1; }
[ -n "$VC_TOKEN" ] && [ "$VC_TOKEN" != "null" ] || { echo "err: vercel_token missing in config.json" >&2; exit 1; }

# Secret: 7 chars base32 без 01lio
gen_secret() {
  local raw
  raw=$(LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyz23456789' < <(head -c 256 /dev/urandom))
  printf '%s' "${raw:0:7}"
}
SECRET=$(gen_secret)
[ ${#SECRET} -eq 7 ] || { echo "err: secret gen failed" >&2; exit 1; }

SLUG="${DOCTYPE}-${TITLE}-${SECRET}"
DEST_REL="public/c/${CLIENT}/${SLUG}/index.html"
URL="https://milagpt.cc/c/${CLIENT}/${SLUG}"

# Инжект noindex meta если отсутствует
TMPHTML=$(mktemp /tmp/publish-XXXXXX.html)
if grep -qiE '<meta[^>]+name=["'\'']?robots' "$SRC"; then
  cp "$SRC" "$TMPHTML"
else
  awk 'BEGIN{done=0} {
    if (!done && tolower($0) ~ /<head>/) {
      print
      print "<meta name=\"robots\" content=\"noindex, nofollow, noarchive, nosnippet\">"
      done=1
    } else { print }
  }' "$SRC" > "$TMPHTML"
fi

# === Клонирование через HTTPS+token ===
WORK=$(mktemp -d /tmp/publish-work-XXXXXX)
trap "rm -rf '$WORK' '$TMPHTML'" EXIT

REPO_URL="https://x-access-token:${GH_TOKEN}@github.com/${GH_REPO}.git"
git clone --depth=1 --quiet "$REPO_URL" "$WORK" 2>&1 | sed 's/'"${GH_TOKEN}"'/[REDACTED]/g' >&2 || {
  echo "err: git clone failed" >&2; exit 1;
}

# Пишем файл
DEST="$WORK/$DEST_REL"
mkdir -p "$(dirname "$DEST")"
cp "$TMPHTML" "$DEST"

# Commit
cd "$WORK"
git config user.email "mila-clients@milagpt.cc"
git config user.name "Mila Clients (auto-publish)"
git add "$DEST_REL"

if git diff --cached --quiet; then
  echo "err: no changes staged (file identical)" >&2; exit 1;
fi

git commit -q -m "publish(client): ${CLIENT} ${DOCTYPE} ${TITLE}

published-by: ${NANOCLAW_GROUP:-mila-clients}
note: ${NOTE}"

PUSH_OK=1
git push -q origin main 2>&1 | sed 's/'"${GH_TOKEN}"'/[REDACTED]/g' >&2 || PUSH_OK=0

COMMIT=$(git rev-parse --short HEAD)

# === Vercel deploy через npx ===
# Первый запуск скачивает vercel (~30 сек), потом кэшируется в ~/.npm
DEPLOYMENT=""
if [ -z "${NO_DEPLOY:-}" ]; then
  # npx vercel хочет .vercel/project.json для link-а; создаём его вручную
  mkdir -p .vercel
  cat > .vercel/project.json <<VJ
{"projectId":"$(curl -sS -H "Authorization: Bearer $VC_TOKEN" "https://api.vercel.com/v9/projects/${VC_PROJECT}?teamId=${VC_SCOPE}" | jq -r .id)","orgId":"$(curl -sS -H "Authorization: Bearer $VC_TOKEN" "https://api.vercel.com/v2/teams/${VC_SCOPE}" | jq -r .id)"}
VJ
  DEPLOY_OUT=$(npx --yes vercel@latest deploy --prod --token "$VC_TOKEN" --scope "$VC_SCOPE" --yes 2>&1 || true)
  DEPLOYMENT=$(printf '%s' "$DEPLOY_OUT" | grep -Eo 'https://[a-z0-9-]+\.vercel\.app' | head -1)
fi

# === Ledger ===
LEDGER="${LEDGER_FILE:-/workspace/global/web-projects/client-docs/ledger.jsonl}"
mkdir -p "$(dirname "$LEDGER")"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PUBLISHED_BY="${NANOCLAW_GROUP:-mila-clients}"

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
{"url":"$URL","commit":"$COMMIT","secret":"$SECRET","deployment":"$DEPLOYMENT","push":$([ $PUSH_OK -eq 1 ] && echo true || echo false),"ledger_entry":$ENTRY}
JSON
