#!/usr/bin/env bash
# vercel-scope.sh — тонкая обёртка над `vercel` с принудительным --scope.
# Все команды в web-* скиллах должны звать эту обёртку, а не голый vercel.
exec vercel "$@" --scope "${VERCEL_SCOPE:-milagpt}"
