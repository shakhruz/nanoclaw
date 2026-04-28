---
name: team-mode
description: Team orchestration via v2 create_agent + a2a messaging. Director (you) spawns role-specific specialists on demand, delegates work, synthesizes their replies into user-facing answers.
---

# Team mode

This skill ships an `instructions.md` fragment that is auto-included in every
group's composed CLAUDE.md. It teaches the director (Mila or whoever owns
this chat) how to use `create_agent` + a2a destinations correctly so:

- Specialists are created on demand with chat-specific context.
- Specialist replies (a2a follow-ups) are properly forwarded to the user.
- No `<internal>` notes that get silently dropped by the SDK.

There is no shell tool — the skill is purely a CLAUDE fragment. Activation
is automatic when the file exists under `container/skills/team-mode/`.
