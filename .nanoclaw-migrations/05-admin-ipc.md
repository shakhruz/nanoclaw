# Admin-IPC: file-pipeline → two-DB rewrite

Decision 3A: rewrite immediately, not later. Same protocol semantics, different transport.

## v1 architecture (current)

```
Subagent (container) ──> /workspace/global/admin-ipc/requests/<id>.json
                                          │
                                          ▼ poll 20s
                            scripts/admin-ipc-daemon.js
                                          │
                       ┌──────────────────┴───────────────────┐
                       ▼                                      ▼
              auto-approve actions                escalate to Telegram
              (ping, web_publish, deploy,         inline buttons
               install_skills, render…)                   │
                       │                                  │
                       │                                  ▼
                       │                  /workspace/global/admin-ipc/decisions/<id>.json
                       │                                  │
                       └──────────────────┬───────────────┘
                                          ▼
                       /workspace/global/admin-ipc/responses/<id>.json
                                          │
                                          ▼ poll w/backoff
                                     Subagent reads result
```

State directories:
- `requests/` (pending)
- `pending/` (escalated to human)
- `decisions/` (Telegram callback wrote)
- `archive/` (completed)
- `needs-claude/` (parked for live admin Claude session)
- `responses/` (final result for subagent)
- `ledger.jsonl` (audit log)

## v2 architecture (target)

Replace files with rows in the **agent-group "global" session DB**. v2's per-session DB shape (`messages_in` / `messages_out`) already supports this — admin-IPC requests are just messages of `kind='admin_request'`.

### Schema additions

In `inbound.db`:

```sql
-- Reuses messages_in shape; content is the request JSON
INSERT INTO messages_in (id, seq, kind, timestamp, status, content)
VALUES ('req-<id>', <seq>, 'admin_request', <ts>, 'pending', '<json>');
```

content payload:
```json
{
  "request_id": "req-20260427-a1b2c3",
  "requesting_group": "telegram_main",
  "action": "web_deploy",
  "params": { "project": "milagpt-cc", "reason": "..." },
  "justification": "...",
  "decision": null,
  "decided_by": null,
  "decided_at": null
}
```

When Telegram callback fires, daemon UPDATEs the row:
```sql
UPDATE messages_in
SET content = json_set(content, '$.decision', 'approve',
                              '$.decided_by', '<userId>',
                              '$.decided_at', '<iso>'),
    status = 'pending_execution'
WHERE id = 'req-<id>';
```

In `outbound.db`:

```sql
-- The response, written by the daemon when the action executes (or when human denies)
INSERT INTO messages_out (id, seq, kind, timestamp, status, content)
VALUES ('resp-<id>', <seq>, 'admin_response', <ts>, 'pending_delivery', '<json>');
```

content payload:
```json
{
  "request_id": "req-20260427-a1b2c3",
  "state": "success",
  "approved_by": "auto|<userId>|denied",
  "executed_at": "<iso>",
  "notes": "...",
  "result": { ... }
}
```

The subagent's MCP tool reads `messages_out` matching `request_id` and returns the result.

### Why the global session

v2 sessions are per-(agent_group, session_id). Admin-IPC is cross-group: any specialist can request, the daemon is global. Use a dedicated `global` agent group + a single long-lived session for admin-IPC traffic. All specialists' subagents have an MCP tool that writes to this global session's `inbound.db`.

Path: `data/v2-sessions/global/admin-ipc/inbound.db` and `outbound.db`.

## Files to rewrite

### `scripts/admin-ipc-daemon.js`

**Replace:**
- `fs.readdir(REQ_DIR)` polling → `SELECT * FROM messages_in WHERE kind='admin_request' AND status='pending'`
- `fs.rename(req, pending)` → `UPDATE messages_in SET status='pending_human' WHERE id=...`
- `fs.writeFileSync(responseFile, ...)` → `INSERT INTO messages_out (...)`
- `fs.appendFileSync(LEDGER, ...)` → INSERT into `admin_ipc_ledger` table (new, in central DB so it's auditable)

**Keep verbatim:**
- Action policy table (auto vs escalate vs needs-claude classification)
- All `executors[action]()` functions (ping, web_deploy, web_publish, copy_file, install_skills, render tasks, etc.)
- Telegram notification format (`tgSend(...)` for escalations) — but tgSend now uses v2 channel adapter API instead of direct grammy

**Polling vs events:** SQLite has no native subscriptions. Stay with polling, but at 1s instead of 20s. Indexed query on `(kind, status)` makes this cheap.

### `src/channels/telegram.ts` (in nanoclaw-v2, after `/add-telegram` install)

Extend the `callback_query` handler:

```typescript
// existing v2 handler may not have this — add it
if (data.startsWith('admin:')) {
  const [, decision, reqId] = data.split(':');
  const userId = ctx.from.id.toString();
  const userName = ctx.from.first_name || 'unknown';
  // open inbound.db for global agent_group
  const db = openInboundDb('global', 'admin-ipc'); // helper from src/db/session-db.ts
  db.prepare(`
    UPDATE messages_in
    SET content = json_set(content,
          '$.decision', ?, '$.decided_by', ?, '$.decided_by_name', ?,
          '$.decided_at', ?, '$.via', 'telegram_inline_button'),
        status = 'pending_execution'
    WHERE id = ?
  `).run(decision, userId, userName, new Date().toISOString(), reqId);
  // edit message to show ✓ / ✗
  await ctx.editMessageText(decision === 'approve' ? '✅ approved' : '❌ denied');
  return;
}
```

### Container side: `container/skills/admin-ipc/`

Replace shell scripts (`admin-request.sh`, `admin-await.sh`) with MCP tool calls.

**v1 shell:** writes JSON file, polls JSON file in `responses/`.
**v2 MCP tool:** `admin_request({ action, params, justification, timeout_seconds })` — the agent-runner MCP server INSERTs into inbound.db, polls outbound.db until response arrives or timeout.

Implementation lives in v2's `container/agent-runner/src/` (Bun runtime now, not Node) — add a tool to the IPC MCP server. The container skill SKILL.md tells the agent how to invoke it.

### Custom executors

The v1 daemon has executors for ~15 actions. Each must be reviewed for v2 path correctness:

| Action | v1 path / command | v2 adjustment |
|---|---|---|
| `ping` | reply `pong` | none |
| `publish_client_doc` | calls `web-client-doc` skill | none — skill is container-side |
| `web_publish` | calls `web-publish` skill | none |
| `web_deploy` | spawns `vercel --prod` in admin-panel/ or web-projects | path may shift; verify after stage 3 |
| `copy_file` | host-side `fs.copyFile` | none |
| `install_skills` | shell out to `git merge skill/X` | **needs change** — v2 doesn't merge skills, uses `/add-X` |
| `octofunnel_login` | parked in needs-claude/ | preserve parking semantics in v2 (separate `needs_human` queue) |
| `code_fix`, `modify_skill`, `modify_nanoclaw_config` | parked in needs-claude/ | same |
| Render tasks | spawn `node admin-panel/server.cjs` actions | path adjusts after admin-panel copies |

## Invariants to preserve

1. **Idempotence:** before INSERT, check `WHERE id = ?` — duplicate requests skip.
2. **Single-writer rule:** only the daemon writes to outbound for admin responses. Specialists must never write directly to `messages_out` for admin-IPC results.
3. **Atomic state transitions:** wrap UPDATEs in BEGIN/COMMIT. Specifically the request-claim transition: `UPDATE ... SET status='executing' WHERE id=? AND status='pending'` — if 0 rows affected, another worker grabbed it.
4. **Ledger:** every state change appended to a separate `admin_ipc_ledger` table (in central DB). Audit independent of session DB lifecycle.
5. **Timeout:** subagents that wait > 30 minutes get `state: 'timeout'` instead of hanging forever.

## Testing checklist for stage 5

- [ ] Auto-approve action: `admin_request({ action: 'ping' })` from a test subagent, verify response within 2s
- [ ] Human-approval flow: `admin_request({ action: 'send_message_to_client', ... })`, Telegram message arrives, click ✅, response written, subagent receives
- [ ] Denial: same as above, click ❌, response has `state: 'denied'`
- [ ] needs-Claude park: `admin_request({ action: 'modify_skill', ... })`, daemon parks it, admin gets a notification, manual resolution writes a response
- [ ] Race condition: two subagents send same request_id simultaneously — only one row created, both subagents read same response
- [ ] Daemon restart: pending requests still get processed after daemon restart (state column survives, no in-memory state)
