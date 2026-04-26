#!/bin/bash
# sync-skills-all-groups.sh — force-sync container/skills/ → all group caches.
#
# Without this, groups that haven't spawned a container recently keep stale
# skill caches (since sync runs only at spawn time). Run after adding/removing
# skills in container/skills/ to ensure all groups see the new state.

set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/container/skills"
SESSIONS="$REPO/data/sessions"

# Same gating as src/container-runner.ts
PUBLIC_LEAD_SKILLS=(capabilities status formatting telegram-reactions inline-buttons)
TELEGRAM_ADS_BLOCKED=(telegram_ashotai-experts)
WEB_BLOCKED=(telegram_ashotai-experts)

is_in() { local n="$1"; shift; for x; do [ "$x" = "$n" ] && return 0; done; return 1; }
is_telegram_ads() { [[ "$1" == "telegram-ads-http" || "$1" == telegram-ads* ]]; }
is_web()          { [[ "$1" == "web" || "$1" == web-* ]]; }
is_public()       { [[ "$1" == telegram_lead-* || "$1" == tg_lead-* ]]; }
is_main()         { [[ "$1" == "telegram_main" ]]; }

count_synced=0
count_evicted=0

for grp_dir in "$SESSIONS"/*/; do
  grp="$(basename "$grp_dir")"
  dst="$grp_dir.claude/skills"
  [ -d "$dst" ] || continue

  for skill_src in "$SRC"/*/; do
    skill="$(basename "$skill_src")"

    # Apply gating rules
    if is_public "$grp" && ! is_in "$skill" "${PUBLIC_LEAD_SKILLS[@]}"; then continue; fi
    if ! is_main "$grp" && [ "$skill" = "wiki" ]; then continue; fi
    if is_main "$grp" && [ "$skill" = "wiki-contributor" ]; then continue; fi
    if is_telegram_ads "$skill" && is_in "$grp" "${TELEGRAM_ADS_BLOCKED[@]}"; then continue; fi
    if is_web "$skill" && is_in "$grp" "${WEB_BLOCKED[@]}"; then continue; fi

    rsync -a --delete "$skill_src" "$dst/$skill/"
    count_synced=$((count_synced+1))
  done

  # Evict skills that exist in cache but not in src (deleted upstream)
  for cached_skill in "$dst"/*/; do
    [ -d "$cached_skill" ] || continue
    name="$(basename "$cached_skill")"
    if [ ! -d "$SRC/$name" ]; then
      rm -rf "$cached_skill"
      echo "  evicted $grp / $name (no longer in src)"
      count_evicted=$((count_evicted+1))
    fi
    # Evict role-mismatch skills (wiki vs wiki-contributor)
    if ! is_main "$grp" && [ "$name" = "wiki" ]; then
      rm -rf "$cached_skill"; count_evicted=$((count_evicted+1))
    fi
    if is_main "$grp" && [ "$name" = "wiki-contributor" ]; then
      rm -rf "$cached_skill"; count_evicted=$((count_evicted+1))
    fi
    if is_telegram_ads "$name" && is_in "$grp" "${TELEGRAM_ADS_BLOCKED[@]}"; then
      rm -rf "$cached_skill"; count_evicted=$((count_evicted+1))
    fi
    if is_web "$name" && is_in "$grp" "${WEB_BLOCKED[@]}"; then
      rm -rf "$cached_skill"; count_evicted=$((count_evicted+1))
    fi
  done
done

echo "Synced $count_synced skill copies, evicted $count_evicted stale entries"
