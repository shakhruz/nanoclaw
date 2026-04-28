#!/usr/bin/env bash
# wiki-contributor.sh — v2 stub
#
# In v2 the shared wiki is mounted read-only into sub-agent containers.
# Direct filesystem writes (and git commits) no longer work for contributors.
# All writes go through the curator via a2a messaging — see the SKILL.md
# next to this file for the recommended pattern.
#
# Curator (the agent owning groups/telegram_main) DOES have RW on the wiki
# and may use this script for its own appends as before.

set -euo pipefail

WIKI="/workspace/global/wiki"
CMD="${1:-}"

# Detect whether this container can actually write to the wiki.
if [ ! -w "$WIKI" ]; then
  cat >&2 <<'EOF'
ERROR: /workspace/global/wiki is mounted read-only in this container — you are
a contributor, not the curator. Direct writes via this script are not the v2
path.

Use agent-to-agent messaging instead:

  send_message({
    to: "parent",
    channel: "agent",
    text: "[wiki-inbox] [<your-role>] <one-line note>"
  })

For a full page, use [wiki-promote] with the body. See container skill
`wiki-contributor/SKILL.md` for both patterns and examples.
EOF
  exit 2
fi

# Curator path — same behavior as v1 wiki-contributor.sh.
if [ -z "${NANOCLAW_GROUP:-}" ]; then
  echo "ERROR: NANOCLAW_GROUP env var not set" >&2
  exit 2
fi

ROLE="${NANOCLAW_GROUP#telegram_}"
ROLE="${ROLE#tg_}"

cd "$WIKI"
git pull --rebase 2>/dev/null || true

case "$CMD" in
  inbox)
    NOTE="${2:-}"
    if [ -z "$NOTE" ]; then
      echo "usage: wiki-contributor.sh inbox \"<note>\"" >&2
      exit 2
    fi
    TS=$(date +"%Y-%m-%d %H:%M")
    echo "- [$TS] [${ROLE}] ${NOTE}" >> inbox.md
    git add inbox.md
    git commit -m "inbox(${ROLE}): ${NOTE:0:60}" 2>/dev/null || true
    git push origin master 2>/dev/null || true
    echo "ok"
    ;;
  page)
    SLUG="${2:-}"
    if [ -z "$SLUG" ]; then
      echo "usage: wiki-contributor.sh page <slug>   # body on stdin" >&2
      exit 2
    fi
    mkdir -p "projects/${ROLE}"
    cat > "projects/${ROLE}/${SLUG}.md"
    git add "projects/${ROLE}/${SLUG}.md"
    git commit -m "note(${ROLE}): ${SLUG}" 2>/dev/null || true
    git push origin master 2>/dev/null || true
    echo "ok: projects/${ROLE}/${SLUG}.md"
    ;;
  *)
    echo "usage: wiki-contributor.sh {inbox \"<note>\" | page <slug>}" >&2
    exit 2
    ;;
esac
