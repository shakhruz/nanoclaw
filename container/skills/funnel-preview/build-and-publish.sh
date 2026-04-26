#!/usr/bin/env bash
# funnel-preview/build-and-publish.sh
#
# Compiles ALL workshop artefacts (design/, lead-magnets/, audio/, copy/) into a
# single AshotAI-branded HTML preview page + publishes to milagpt.cc/w/<slug>/
# in ONE atomic operation (single git commit, single vercel deploy, single lock).
#
# Atomicity: всё под flock /tmp/milagpt-cc-publish.lock — race-safe с другими publish-*.
#
# Usage:
#   build-and-publish.sh <slug>
#
# Reads from: /workspace/global/workshops/<slug>/
#   design/*.{png,jpg,jpeg,webp}   — hero, banners, covers, etc
#   lead-magnets/*.pdf             — checklists, templates, workbooks
#   lead-magnets/*-cover.png       — covers
#   audio/*.mp3                    — voiceover, lessons (optional)
#   *.md (brief, copy, strategy)   — context shown in collapsed details
#
# Output:
#   https://milagpt.cc/w/<slug>/  — single-page review with anchor-nav

set -eo pipefail

SLUG="${1:?usage: build-and-publish.sh <slug>}"
[[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]{0,80}$ ]] || { echo "err: invalid slug" >&2; exit 1; }

WORKSHOP_DIR="${WORKSHOP_DIR:-/workspace/global/workshops/$SLUG}"
[ -d "$WORKSHOP_DIR" ] || { echo "err: workshop dir not found: $WORKSHOP_DIR" >&2; exit 1; }

REPO_DIR="${MILAGPT_CC_DIR:-$HOME/apps/milagpt-cc}"
SCOPE="${VERCEL_SCOPE:-milagpt}"
DEST_REL="public/w/$SLUG"
DEST="$REPO_DIR/$DEST_REL"

LOCK_DIR="/tmp/milagpt-cc-publish.lock.d"
LOCK_TIMEOUT="${PUBLISH_LOCK_TIMEOUT:-300}"

# Acquire publish lock — mkdir is atomic on POSIX, works on macOS + Linux without flock
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
  echo "err: failed to acquire publish lock within ${LOCK_TIMEOUT}s" >&2
  exit 75
fi

echo "[funnel-preview] building $SLUG..." >&2

# ── 1. Copy all assets into deploy dir ─────────────────────────────────
mkdir -p "$DEST"
# images
find "$WORKSHOP_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) \
  | while read -r f; do
      cp "$f" "$DEST/$(basename "$f")"
    done
# pdfs
find "$WORKSHOP_DIR" -type f -iname "*.pdf" \
  | while read -r f; do
      cp "$f" "$DEST/$(basename "$f")"
    done
# audio
find "$WORKSHOP_DIR" -type f \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.ogg" \) \
  | while read -r f; do
      cp "$f" "$DEST/$(basename "$f")"
    done

# ── 2. Build index.html ────────────────────────────────────────────────
INDEX="$DEST/index.html"

# Single python invocation: scan dest+workshop, generate HTML, write index
python3 - "$DEST" "$WORKSHOP_DIR" "$SLUG" "$INDEX" <<'PYEOF'
import sys, os
from pathlib import Path
from datetime import datetime, timezone

dest = Path(sys.argv[1])
workshop = Path(sys.argv[2])
slug = sys.argv[3]
index_path = sys.argv[4]

def is_ext(p, exts):
    return p.suffix.lower() in exts

images = sorted([p.name for p in dest.iterdir() if p.is_file() and is_ext(p, {'.png','.jpg','.jpeg','.webp'})])
pdfs = sorted([p.name for p in dest.iterdir() if p.is_file() and is_ext(p, {'.pdf'})])
audios = sorted([p.name for p in dest.iterdir() if p.is_file() and is_ext(p, {'.mp3','.m4a','.ogg'})])

mds = {}
for name in ('brief.md','copy.md','strategy.md','structure.md','methodology.md','targeting.md','funnel.md'):
    p = workshop / name
    if p.exists():
        mds[name] = p.read_text(encoding='utf-8')

now = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #0A0A0A; color: #FFF; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif; line-height: 1.5; }
.wrap { max-width: 980px; margin: 0 auto; padding: 40px 24px; }
header { padding-bottom: 24px; border-bottom: 1px solid #222; margin-bottom: 32px; }
h1 { font-size: 28px; font-weight: 700; letter-spacing: -0.02em; }
.meta { color: #999; font-size: 13px; margin-top: 6px; }
nav { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 32px; padding: 12px 0; border-top: 1px solid #222; border-bottom: 1px solid #222; }
nav a { display: inline-block; padding: 6px 12px; background: #111; color: #C9A84C; text-decoration: none; border-radius: 4px; font-size: 13px; font-weight: 600; }
nav a:hover { background: #C9A84C; color: #0A0A0A; }
section { margin: 40px 0; padding-top: 24px; border-top: 1px solid #222; }
h2 { font-size: 22px; font-weight: 700; margin-bottom: 16px; color: #C9A84C; letter-spacing: -0.01em; }
.imggrid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
.imgcard { background: #111; padding: 12px; border-radius: 6px; }
.imgcard img { width: 100%; height: auto; display: block; border-radius: 4px; }
.imgcard .name { color: #999; font-size: 12px; margin-top: 8px; font-family: ui-monospace, "SF Mono", Menlo, monospace; word-break: break-all; }
audio { width: 100%; margin: 8px 0; }
.audiorow { background: #111; padding: 12px 16px; border-radius: 6px; margin-bottom: 12px; }
.audiorow .name { color: #C9A84C; font-size: 14px; margin-bottom: 6px; font-weight: 600; }
.pdfrow { background: #111; padding: 16px; border-radius: 6px; margin-bottom: 12px; }
.pdfrow a { color: #C9A84C; text-decoration: none; font-weight: 600; }
.pdfrow a:hover { text-decoration: underline; }
iframe.pdf { width: 100%; height: 600px; border: 0; border-radius: 4px; background: #FFF; margin-top: 12px; }
details { background: #111; padding: 14px 18px; border-radius: 6px; margin-bottom: 12px; }
details summary { cursor: pointer; color: #C9A84C; font-weight: 600; }
details pre { white-space: pre-wrap; color: #DDD; font-size: 13px; line-height: 1.55; margin-top: 12px; max-height: 480px; overflow-y: auto; padding: 12px; background: #000; border-radius: 4px; }
footer { margin-top: 48px; padding-top: 24px; border-top: 1px solid #222; color: #666; font-size: 12px; text-align: center; }
"""

parts = []
parts.append(f'<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Funnel Preview — {slug}</title><style>{CSS}</style></head><body><div class="wrap">')
parts.append(f'<header><h1>📋 Funnel Preview — {slug}</h1><div class="meta">Сборка: {now} · Все артефакты воронки в одном месте</div></header>')

nav_links = []
if images: nav_links.append(f'<a href="#images">🖼 Изображения ({len(images)})</a>')
if pdfs: nav_links.append(f'<a href="#pdfs">📄 PDF ({len(pdfs)})</a>')
if audios: nav_links.append(f'<a href="#audios">🔊 Аудио ({len(audios)})</a>')
for name in mds:
    nav_links.append(f'<a href="#md-{name.replace(".md","")}">📝 {name}</a>')
parts.append('<nav>' + ''.join(nav_links) + '</nav>')

if images:
    parts.append('<section id="images"><h2>🖼 Изображения</h2><div class="imggrid">')
    for img in images:
        parts.append(f'<div class="imgcard"><img src="{img}" alt="{img}" loading="lazy"><div class="name">{img}</div></div>')
    parts.append('</div></section>')

if pdfs:
    parts.append('<section id="pdfs"><h2>📄 PDF документы</h2>')
    for pdf in pdfs:
        parts.append(f'<div class="pdfrow"><a href="{pdf}" target="_blank">{pdf} ↓</a><iframe class="pdf" src="{pdf}#view=FitH"></iframe></div>')
    parts.append('</section>')

if audios:
    parts.append('<section id="audios"><h2>🔊 Аудио</h2>')
    for aud in audios:
        parts.append(f'<div class="audiorow"><div class="name">{aud}</div><audio controls preload="none"><source src="{aud}"></audio></div>')
    parts.append('</section>')

for name, content in mds.items():
    anchor = name.replace('.md','')
    safe = content.replace('<','&lt;').replace('>','&gt;')
    parts.append(f'<section id="md-{anchor}"><h2>📝 {name}</h2><details open><summary>Показать содержимое</summary><pre>{safe}</pre></details></section>')

parts.append('<footer>Funnel preview · AshotAI · сгенерировано Mila octo · обновляется автоматически при каждой публикации</footer>')
parts.append('</div></body></html>')

Path(index_path).write_text(''.join(parts), encoding='utf-8')
print(f"index.html written: {index_path} (images={len(images)} pdfs={len(pdfs)} audios={len(audios)})", file=sys.stderr)
PYEOF

# ── 3. Atomic git commit + vercel deploy ───────────────────────────────
cd "$REPO_DIR"
git pull --rebase origin main >/dev/null 2>&1 || true
git add "$DEST_REL"
if git diff --cached --quiet; then
  echo "warn: no changes — preview already up-to-date" >&2
  COMMIT=$(git rev-parse --short HEAD)
  echo "{\"url\":\"https://milagpt.cc/w/$SLUG/\",\"commit\":\"$COMMIT\",\"deployment\":\"\",\"unchanged\":true}"
  exit 0
fi
git commit -m "funnel-preview: $SLUG (assets + index.html)" >/dev/null
PUSH_OK=1; git push origin main >/dev/null 2>&1 || PUSH_OK=0

DEPLOYMENT=""
if [ -z "${NO_DEPLOY:-}" ]; then
  DEPLOYMENT=$(vercel deploy --prod --scope "$SCOPE" --yes 2>/dev/null \
    | grep -Eo 'https://[a-z0-9-]+\.vercel\.app' | head -1 || echo "")
fi

COMMIT=$(git rev-parse --short HEAD)
echo "{\"url\":\"https://milagpt.cc/w/$SLUG/\",\"commit\":\"$COMMIT\",\"deployment\":\"$DEPLOYMENT\",\"push\":$PUSH_OK,\"images\":$(find "$DEST" -name "*.png" -o -name "*.jpg" | wc -l | tr -d ' '),\"pdfs\":$(find "$DEST" -name "*.pdf" | wc -l | tr -d ' '),\"audios\":$(find "$DEST" \( -name "*.mp3" -o -name "*.ogg" -o -name "*.m4a" \) | wc -l | tr -d ' ')}"
