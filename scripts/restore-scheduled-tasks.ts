/**
 * One-shot migration: restore v1 scheduled tasks into v2 sessions.
 *
 * Reads `.nanoclaw-migrations/v1-data/scheduled-tasks.json`, maps each task's
 * v1 group_folder to the matching v2 agent_group, finds an active session for
 * that agent_group, and INSERTs a row into that session's inbound.db with
 * kind='task', recurrence=cron expression, series_id=task.id.
 *
 * Idempotent — re-running skips tasks already inserted (matched by id).
 *
 *   pnpm exec tsx scripts/restore-scheduled-tasks.ts
 */
import Database from 'better-sqlite3';
import { CronExpressionParser } from 'cron-parser';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

interface V1Task {
  id: string;
  group_folder: string;
  chat_jid: string;
  prompt: string;
  schedule_type: 'cron' | 'once';
  schedule_value: string;
  context_mode: string;
  status: string;
  created_at: string;
}

const ROOT = path.resolve(__dirname, '..');
const TZ = 'Asia/Tashkent';

const tasksPath = path.join(ROOT, '.nanoclaw-migrations', 'v1-data', 'scheduled-tasks.json');
const tasks: V1Task[] = JSON.parse(fs.readFileSync(tasksPath, 'utf-8'));

const central = new Database(path.join(ROOT, 'data', 'v2.db'), { readonly: true });

const agentGroupForFolder = new Map<string, string>();
for (const row of central.prepare('SELECT id, folder FROM agent_groups').all() as Array<{ id: string; folder: string }>) {
  agentGroupForFolder.set(row.folder, row.id);
}

const sessionForAgentGroup = new Map<string, string>();
for (const row of central.prepare("SELECT id, agent_group_id, created_at FROM sessions WHERE status = 'active' ORDER BY created_at").all() as Array<{ id: string; agent_group_id: string; created_at: string }>) {
  if (!sessionForAgentGroup.has(row.agent_group_id)) {
    sessionForAgentGroup.set(row.agent_group_id, row.id);
  }
}

central.close();

console.log(`Loaded ${tasks.length} v1 tasks. Mapped ${agentGroupForFolder.size} agent_groups, ${sessionForAgentGroup.size} sessions.`);

let inserted = 0;
let skipped = 0;
let missingSession = 0;
let missingAgent = 0;

const now = new Date();

for (const t of tasks) {
  if (t.status !== 'active') {
    skipped++;
    continue;
  }

  const agId = agentGroupForFolder.get(t.group_folder);
  if (!agId) {
    console.warn(`  ✗ ${t.id}: no agent_group for folder "${t.group_folder}"`);
    missingAgent++;
    continue;
  }

  const sessId = sessionForAgentGroup.get(agId);
  if (!sessId) {
    console.warn(`  ⚠ ${t.id}: no active session for agent_group ${agId} (folder "${t.group_folder}") — skipping (send a message in that chat to create one, then re-run)`);
    missingSession++;
    continue;
  }

  let processAfter: string;
  let recurrence: string | null;

  if (t.schedule_type === 'cron') {
    try {
      const interval = CronExpressionParser.parse(t.schedule_value, { tz: TZ, currentDate: now });
      processAfter = interval.next().toDate().toISOString();
      recurrence = t.schedule_value;
    } catch (err) {
      console.warn(`  ✗ ${t.id}: bad cron "${t.schedule_value}": ${(err as Error).message}`);
      skipped++;
      continue;
    }
  } else {
    const parsed = new Date(t.schedule_value);
    if (parsed.getTime() <= now.getTime()) {
      console.log(`  - ${t.id}: one-shot in the past (${t.schedule_value}) — skipping`);
      skipped++;
      continue;
    }
    processAfter = parsed.toISOString();
    recurrence = null;
  }

  const sessDir = path.join(ROOT, 'data', 'v2-sessions', agId, sessId);
  const inboundPath = path.join(sessDir, 'inbound.db');
  if (!fs.existsSync(inboundPath)) {
    console.warn(`  ✗ ${t.id}: inbound.db missing at ${inboundPath}`);
    skipped++;
    continue;
  }

  const inDb = new Database(inboundPath);

  const existing = inDb.prepare("SELECT id FROM messages_in WHERE id = ? AND kind = 'task'").get(t.id);
  if (existing) {
    inDb.close();
    skipped++;
    continue;
  }

  const maxSeq = (inDb.prepare('SELECT COALESCE(MAX(seq), -2) AS m FROM messages_in').get() as { m: number }).m;
  const nextSeq = (Math.floor(maxSeq / 2) + 1) * 2;

  inDb
    .prepare(
      `INSERT INTO messages_in (id, seq, timestamp, status, tries, process_after, recurrence, kind, platform_id, channel_type, thread_id, content, series_id, trigger)
       VALUES (?, ?, datetime('now'), 'pending', 0, ?, ?, 'task', ?, 'telegram', NULL, ?, ?, 1)`,
    )
    .run(
      t.id,
      nextSeq,
      processAfter,
      recurrence,
      t.chat_jid.replace(/^tg:/, 'telegram:'),
      JSON.stringify({ prompt: t.prompt }),
      t.id,
    );

  inDb.close();
  console.log(`  ✓ ${t.id}: ${t.group_folder} → ${sessId.slice(0, 12)}… (next: ${processAfter}, cron: ${recurrence ?? 'once'})`);
  inserted++;
}

console.log();
console.log(`Done. inserted=${inserted}  skipped=${skipped}  missing_session=${missingSession}  missing_agent=${missingAgent}`);
