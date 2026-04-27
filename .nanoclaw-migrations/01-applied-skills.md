# Applied Upstream Skills

Two upstream skill branches were merged into v1.

| Skill | v1 merge commit | Upstream branch | v2 status |
|---|---|---|---|
| `compact` | `767289f` | `upstream/skill/compact` | **Drop merge — re-install via `/add-compact`** if v2 ships it. Otherwise v2's session model has built-in context handling. |
| `apple-container` | `113ef3b` | `upstream/skill/apple-container` | **Re-install via `/convert-to-apple-container`** in v2 — Apple Container is now opt-in instead of merged into trunk. |

## How to apply

After cloning fresh v2:

```bash
# Apple Container (decision: keep)
# Run inside the v2 working tree, after stage 1 verify
claude /convert-to-apple-container
```

The skill takes care of:
- Creating the credential proxy networking (Apple Container has different docker-host semantics than Docker)
- Updating launchd plist to use `container` CLI instead of `docker`
- Rebuilding the image for Apple's runtime

For `compact`: check after cluster install whether `/compact` slash command exists in v2 by default. If yes, no action. If not, install whatever v2 equivalent ships (`/add-compact` or built-in via session-commands).

## Notes

- Do **not** simply re-merge `upstream/skill/apple-container` into v2 main — v2's branch model expects skills to be installed via the `add-*` skills, which copy specific files. A blind merge would conflict.
- `compact` was a simple addition in v1 (session-commands.ts handler). In v2, session commands may have been refactored into the harness. Verify before installing anything.
