#!/usr/bin/env node
// admin-ipc-daemon.js — host-side background worker for admin-ipc protocol.
//
// Polls groups/global/admin-ipc/{requests,decisions}/ every POLL_MS:
//   • New request → apply policy → auto-execute OR escalate via Telegram inline buttons
//   • New decision (from button click) → finish the paused request
//
// Runs under launchd (~/Library/LaunchAgents/com.nanoclaw.admin-ipc.plist).

import fs from 'fs';
import path from 'path';
import { execFileSync, spawn } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..');
const IPC = path.join(REPO, 'groups', 'global', 'admin-ipc');
const REQS = path.join(IPC, 'requests');
const RESPS = path.join(IPC, 'responses');
const DECS = path.join(IPC, 'decisions');
const ARCH = path.join(IPC, 'archive');
const PENDING = path.join(IPC, 'pending'); // escalated, awaiting decision
const LEDGER = path.join(IPC, 'ledger.jsonl');

for (const d of [REQS, RESPS, DECS, ARCH, PENDING]) fs.mkdirSync(d, { recursive: true });

const POLL_MS = 20_000;
const SHAKHRUZ_CHAT_ID = 33823108;

// ------------------- env / secrets -------------------
function loadBotToken() {
  const envPath = path.join(REPO, '.env');
  const env = fs.readFileSync(envPath, 'utf8');
  const m = env.match(/^TELEGRAM_BOT_TOKEN=(.+)$/m);
  if (!m) throw new Error('TELEGRAM_BOT_TOKEN not in .env');
  return m[1].trim();
}
const BOT_TOKEN = loadBotToken();

// ------------------- policy -------------------
const POLICY = {
  ping:                { auto: true,  risk: 'low'    },
  publish_client_doc:  { auto: true,  risk: 'low'    },
  publish_web_article: { auto: true,  risk: 'low'    },
  web_inventory_refresh: { auto: true, risk: 'low' },
  install_skills:      { auto: true,  risk: 'low'    }, // simple file copy within our repo
  copy_file_to_host:   { auto: true,  risk: 'low'    },
  code_fix:            { auto: false, risk: 'medium' },
  web_deploy:          { auto: false, risk: 'medium' },
  schedule_task_create:{ auto: false, risk: 'medium' },
  send_message_to_client: { auto: false, risk: 'medium' },
  publish_to_channel:  { auto: false, risk: 'medium' },
  modify_nanoclaw_config: { auto: false, risk: 'high' },
  spend_ads_budget:    { auto: false, risk: 'high'   },
  install_integration: { auto: false, risk: 'high'   },
  delete_data:         { auto: false, risk: 'high'   },
  run_command:         { auto: false, risk: 'high'   }, // legacy schema
};
const DEFAULT = { auto: false, risk: 'high' };

// ------------------- helpers -------------------
function nowISO() { return new Date().toISOString(); }
function log(...args) { console.log(`[${nowISO()}]`, ...args); }
function readJSON(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }
function writeJSON(p, obj) { fs.writeFileSync(p, JSON.stringify(obj, null, 2)); }
function appendLedger(entry) {
  fs.appendFileSync(LEDGER, JSON.stringify(entry) + '\n');
}

async function tgSend(text, replyMarkup) {
  const body = {
    chat_id: SHAKHRUZ_CHAT_ID,
    text,
    parse_mode: 'Markdown',
    ...(replyMarkup ? { reply_markup: replyMarkup } : {}),
  };
  const r = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) log('telegram send failed', r.status, await r.text().catch(() => ''));
  return r.json().catch(() => ({}));
}

function writeResponse(reqId, state, approvedBy, notes, result = {}) {
  const resp = {
    request_id: reqId,
    state,
    approved_by: approvedBy,
    executed_at: nowISO(),
    notes,
    result,
  };
  writeJSON(path.join(RESPS, `${reqId}.json`), resp);
  appendLedger({ request_id: reqId, state, approved_by: approvedBy, executed_at: nowISO(), summary: notes.slice(0, 200) });
}

function archiveRequest(reqId) {
  const src = path.join(REQS, `${reqId}.json`);
  const dst = path.join(ARCH, `${reqId}.json`);
  if (fs.existsSync(src)) fs.renameSync(src, dst);
  // also clean pending
  const pend = path.join(PENDING, `${reqId}.json`);
  if (fs.existsSync(pend)) fs.unlinkSync(pend);
  // clean decision
  const dec = path.join(DECS, `${reqId}.json`);
  if (fs.existsSync(dec)) fs.unlinkSync(dec);
}

// ------------------- action executors -------------------
function execBash(cmd, opts = {}) {
  try {
    const out = execFileSync('/bin/bash', ['-c', cmd], { encoding: 'utf8', ...opts });
    return { ok: true, out };
  } catch (e) {
    return { ok: false, err: e.message, stdout: e.stdout?.toString(), stderr: e.stderr?.toString() };
  }
}

const executors = {
  ping(req) {
    return { ok: true, result: { pong: true, echo: req.params } };
  },

  install_skills(req) {
    const skills = req.params?.skills || [];
    const installed = [];
    const errors = [];
    for (const s of skills) {
      // `src` like /workspace/group/skills-pending/X.md — translate to host path
      const groupFolder = req.requesting_group || '';
      const srcHost = s.src?.replace(
        /^\/workspace\/group/,
        path.join(REPO, 'groups', groupFolder)
      );
      // `dst` like /home/node/.claude/skills/<name>/SKILL.md — install to container/skills/<name>/SKILL.md
      const m = s.dst?.match(/\/skills\/([^/]+)\//);
      const name = s.name || m?.[1];
      if (!srcHost || !name || !fs.existsSync(srcHost)) {
        errors.push({ skill: s.name || name, error: `src not found: ${srcHost}` });
        continue;
      }
      const dstDir = path.join(REPO, 'container', 'skills', name);
      fs.mkdirSync(dstDir, { recursive: true });
      fs.copyFileSync(srcHost, path.join(dstDir, 'SKILL.md'));
      installed.push(name);
    }
    return {
      ok: errors.length === 0,
      result: { installed, errors, hint: 'next container spawn picks them up' },
      err: errors.length ? `some installs failed: ${errors.length}` : null,
    };
  },

  publish_client_doc(req) {
    const p = req.params || {};
    const helper = path.join(REPO, 'container', 'skills', 'web', 'publish-client-doc.sh');
    if (!p.client || !p.doc_type || !p.title || !p.draft_path) {
      return { ok: false, err: 'missing params: client, doc_type, title, draft_path required' };
    }
    // translate draft_path
    const draftHost = p.draft_path.replace(/^\/workspace\/global/, path.join(REPO, 'groups', 'global'));
    if (!fs.existsSync(draftHost)) return { ok: false, err: `draft not found: ${draftHost}` };
    const res = execBash(
      `LEDGER_FILE="${path.join(REPO, 'groups', 'global', 'web-projects', 'client-docs', 'ledger.jsonl')}" ` +
      `"${helper}" "${p.client}" "${p.doc_type}" "${p.title}" "${draftHost}" "${p.note || ''}"`,
      { timeout: 120_000 }
    );
    if (!res.ok) return { ok: false, err: res.stderr || res.err };
    try {
      const parsed = JSON.parse(res.out.trim().split('\n').pop());
      return { ok: true, result: parsed };
    } catch {
      return { ok: true, result: { raw: res.out } };
    }
  },

  publish_web_article(req) {
    const p = req.params || {};
    const helper = path.join(REPO, 'container', 'skills', 'web', 'publish-html.sh');
    if (!p.type || !p.slug || !p.html_path) {
      return { ok: false, err: 'need type, slug, html_path' };
    }
    const htmlHost = p.html_path.replace(/^\/workspace\/global/, path.join(REPO, 'groups', 'global'));
    if (!fs.existsSync(htmlHost)) return { ok: false, err: `html not found: ${htmlHost}` };
    const res = execBash(`"${helper}" "${p.type}" "${p.slug}" "${htmlHost}"`, { timeout: 120_000 });
    if (!res.ok) return { ok: false, err: res.stderr || res.err };
    return { ok: true, result: { raw: res.out } };
  },

  copy_file_to_host(req) {
    const p = req.params || {};
    const srcCont = p.src_container_path;
    const dst = p.dest_host_path;
    if (!srcCont || !dst) return { ok: false, err: 'need src_container_path, dest_host_path' };
    const groupFolder = req.requesting_group || '';
    const srcHost = srcCont.replace(/^\/workspace\/group/, path.join(REPO, 'groups', groupFolder))
                           .replace(/^\/workspace\/global/, path.join(REPO, 'groups', 'global'));
    // security: dst must be /tmp/...
    if (!dst.startsWith('/tmp/')) return { ok: false, err: 'dest_host_path must be under /tmp/' };
    if (!fs.existsSync(srcHost)) return { ok: false, err: `src not found: ${srcHost}` };
    fs.copyFileSync(srcHost, dst);
    return { ok: true, result: { src: srcHost, dst, size: fs.statSync(dst).size } };
  },

  web_inventory_refresh(req) {
    const script = path.join(REPO, 'container', 'skills', 'web', 'refresh-inventory.sh');
    const res = execBash(`TG_WEB_STATE_DIR="${path.join(REPO, 'groups', 'global', 'web-projects')}" "${script}"`, { timeout: 60_000 });
    return res.ok ? { ok: true, result: { summary: res.out.trim() } } : { ok: false, err: res.err };
  },
};

// ------------------- escalation (send inline buttons) -------------------
async function escalate(req) {
  const reqId = req.id;
  const summary = [
    `📋 *Admin-IPC: требуется разрешение*`,
    ``,
    `От: \`${req.requesting_group || '?'}\``,
    `Действие: \`${req.action}\``,
    `Риск: ${(POLICY[req.action] || DEFAULT).risk}`,
    ``,
    `_${(req.justification || '(без обоснования)').slice(0, 300)}_`,
    ``,
    `req: \`${reqId}\``,
  ].join('\n');

  const replyMarkup = {
    inline_keyboard: [[
      { text: '✅ Одобрить', callback_data: `admin:approve:${reqId}` },
      { text: '❌ Отказать', callback_data: `admin:deny:${reqId}` },
    ]],
  };
  await tgSend(summary, replyMarkup);
  // move request to pending — we'll check for decision later
  const src = path.join(REQS, `${reqId}.json`);
  const dst = path.join(PENDING, `${reqId}.json`);
  fs.renameSync(src, dst);
  log('escalated', reqId);
}

// ------------------- loop -------------------
async function processNewRequests() {
  const files = fs.readdirSync(REQS).filter(f => f.endsWith('.json'));
  for (const f of files) {
    const fp = path.join(REQS, f);
    let req;
    try { req = readJSON(fp); } catch (e) { log('unparseable', f, e.message); continue; }
    const action = req.action;
    const policy = POLICY[action] || DEFAULT;

    // idempotence: if response already exists, skip
    const reqId = req.id;
    if (!reqId) { log('req without id', f); fs.renameSync(fp, path.join(ARCH, f)); continue; }
    if (fs.existsSync(path.join(RESPS, `${reqId}.json`))) {
      log('already has response, archiving', reqId);
      archiveRequest(reqId);
      continue;
    }

    if (policy.auto) {
      const exec = executors[action];
      if (!exec) {
        writeResponse(reqId, 'failure', 'auto', `No executor for action: ${action}`, {});
        archiveRequest(reqId);
        continue;
      }
      try {
        const res = exec(req);
        if (res.ok) {
          writeResponse(reqId, 'success', 'auto', `Auto-approved ${action}`, res.result || {});
        } else {
          writeResponse(reqId, 'failure', 'auto', res.err || 'executor failed', res.result || {});
        }
      } catch (e) {
        writeResponse(reqId, 'failure', 'auto', e.message, {});
      }
      archiveRequest(reqId);
      log(action, reqId, 'auto-done');
    } else {
      await escalate(req);
    }
  }
}

async function processDecisions() {
  const files = fs.readdirSync(DECS).filter(f => f.endsWith('.json'));
  for (const f of files) {
    const dp = path.join(DECS, f);
    let dec;
    try { dec = readJSON(dp); } catch { continue; }
    const reqId = dec.request_id;
    const pendPath = path.join(PENDING, `${reqId}.json`);
    if (!fs.existsSync(pendPath)) {
      // pending не найден — возможно, таймаут был. Удаляем decision.
      fs.unlinkSync(dp);
      continue;
    }
    const req = readJSON(pendPath);

    if (dec.decision === 'deny') {
      writeResponse(reqId, 'denied', 'shakhruz', `Denied via inline button`, { decided_at: dec.decided_at });
      archiveRequest(reqId);
      await tgSend(`❌ Отклонено: ${reqId}`);
      continue;
    }

    // approve → execute
    const exec = executors[req.action];
    if (!exec) {
      writeResponse(reqId, 'failure', 'shakhruz', `Approved but no executor for ${req.action}`, {});
      archiveRequest(reqId);
      await tgSend(`⚠️ Одобрено, но нет executor для \`${req.action}\` — требует manual (Claude Code).`);
      continue;
    }
    try {
      const res = exec(req);
      if (res.ok) {
        writeResponse(reqId, 'success', 'shakhruz', `Approved+executed ${req.action}`, res.result || {});
        await tgSend(`✅ Готово: \`${req.action}\` (\`${reqId.slice(-8)}\`)`);
      } else {
        writeResponse(reqId, 'failure', 'shakhruz', res.err || 'executor failed', res.result || {});
        await tgSend(`⚠️ Одобрено, но executor упал: \`${res.err || '?'}\``);
      }
    } catch (e) {
      writeResponse(reqId, 'failure', 'shakhruz', e.message, {});
      await tgSend(`⚠️ Exception во время executor: ${e.message}`);
    }
    archiveRequest(reqId);
  }
}

async function tick() {
  try { await processDecisions(); } catch (e) { log('processDecisions err', e.message); }
  try { await processNewRequests(); } catch (e) { log('processNewRequests err', e.message); }
}

log('admin-ipc-daemon starting, poll every', POLL_MS, 'ms');
tick();
setInterval(tick, POLL_MS);
