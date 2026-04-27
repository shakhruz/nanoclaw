#!/usr/bin/env bash
# wiki-contributor.sh — safe writes to the shared wiki for sub-agents
#
# Usage:
#   wiki-contributor.sh inbox "<one-line note>"
#   wiki-contributor.sh page <slug>   # body on stdin
#
# Role is read from $NANOCLAW_GROUP (e.g. telegram_channel-promoter).
# Writes are scoped to:
#   - /workspace/global/wiki/inbox.md
#   - /workspace/global/wiki/projects/<role-slug>/<slug>.md
#
# The wiki's pre-commit hook is the hard guard; this script is the
# safe default path for routine cases.

set -euo pipefail

WIKI="/workspace/global/wiki"
CMD="${1:-}"

if [ -z "${NANOCLAW_GROUP:-}" ]; then
  echo "ERROR: NANOCLAW_GROUP env var not set — this skill only runs inside a NanoClaw container" >&2
  exit 2
fi

if [ ! -d "$WIKI" ]; then
  echo "ERROR: wiki not found at $WIKI" >&2
  exit 2
fi

ROLE="${NANOCLAW_GROUP#telegram_}"
ROLE="${ROLE#tg_}"

case "$CMD" in
  inbox)
    NOTE="${2:-}"
    if [ -z "$NOTE" ]; then
      echo "usage: wiki-contributor.sh inbox \"<note>\"" >&2
      exit 2
    fi
    # Strip newlines — inbox entries are one line
    NOTE=$(printf '%s' "$NOTE" | tr '\n' ' ' | sed 's/  */ /g')
    TS=$(date +"%Y-%m-%d %H:%M")
    cd "$WIKI"
    git pull --rebase 2>/dev/null || true
    printf -- '- [%s] [%s] %s\n' "$TS" "$ROLE" "$NOTE" >> inbox.md
    git add inbox.md
    # Short summary: first 60 chars of the note
    SUMMARY=$(printf '%s' "$NOTE" | cut -c1-60)
    git commit -m "inbox(${ROLE}): ${SUMMARY}"
    git push origin master 2>/dev/null || true
    echo "OK: appended to inbox.md"
    ;;

  page)
    SLUG="${2:-}"
    if [ -z "$SLUG" ]; then
      echo "usage: wiki-contributor.sh page <slug>  (body on stdin)" >&2
      exit 2
    fi
    # Validate slug: kebab-case, no slashes
    if ! printf '%s' "$SLUG" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
      echo "ERROR: slug must be kebab-case alphanumeric: $SLUG" >&2
      exit 2
    fi
    BODY=$(cat)
    if [ -z "$BODY" ]; then
      echo "ERROR: no body on stdin" >&2
      exit 2
    fi
    # Require frontmatter
    if ! printf '%s' "$BODY" | head -1 | grep -q '^---$'; then
      echo "ERROR: body must start with YAML frontmatter (---)" >&2
      exit 2
    fi
    cd "$WIKI"
    git pull --rebase 2>/dev/null || true
    mkdir -p "projects/${ROLE}"
    TARGET="projects/${ROLE}/${SLUG}.md"
    printf '%s\n' "$BODY" > "$TARGET"
    git add "$TARGET"
    git commit -m "note(${ROLE}): ${SLUG}"
    git push origin master 2>/dev/null || true
    echo "OK: wrote $TARGET"
    ;;

  *)
    cat <<'USAGE' >&2
usage:
  wiki-contributor.sh inbox "<one-line note>"
  wiki-contributor.sh page <slug>   # body on stdin (must start with YAML frontmatter)
USAGE
    exit 2
    ;;
esac
