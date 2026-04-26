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
const NEEDS_CLAUDE = path.join(IPC, 'needs-claude'); // queued for live Claude Code session
const LEDGER = path.join(IPC, 'ledger.jsonl');

for (const d of [REQS, RESPS, DECS, ARCH, PENDING, NEEDS_CLAUDE]) fs.mkdirSync(d, { recursive: true });

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
  copy_file:           { auto: true,  risk: 'low'    }, // copy between groups/<x>/ paths inside the repo
  fix_agent_browser_permissions: { auto: true, risk: 'low' }, // chmod 777 .agent-browser, idempotent
  // Media Maker — auto-approve all media generation (no money spent, only render time)
  render_video: { auto: true, risk: 'low' },
  video_concat: { auto: true, risk: 'low' },
  video_overlay_audio: { auto: true, risk: 'low' },
  video_add_bgm: { auto: true, risk: 'low' },
  video_extract_frame: { auto: true, risk: 'low' },
  video_trim: { auto: true, risk: 'low' },
  video_to_vertical: { auto: true, risk: 'low' },
  // code_fix routes to /needs-claude/ — see NEEDS_CLAUDE_ACTIONS below (no daemon executor possible)
  web_deploy:          { auto: false, risk: 'medium' },
  schedule_task_create:{ auto: false, risk: 'medium' },
  send_message_to_client: { auto: false, risk: 'medium' },
  publish_to_channel:  { auto: false, risk: 'medium' },
  publish_scheduled_with_image: { auto: false, risk: 'medium' },
  modify_nanoclaw_config: { auto: false, risk: 'high' },
  spend_ads_budget:    { auto: false, risk: 'high'   },
  install_integration: { auto: false, risk: 'high'   },
  delete_data:         { auto: false, risk: 'high'   },
  run_command:         { auto: false, risk: 'high'   }, // legacy schema
};
const DEFAULT = { auto: false, risk: 'high' };

// Actions that REQUIRE a live Claude Code session (writing code, judgment calls
// over multiple files, etc). Daemon parks them in /needs-claude/, notifies admin
// in Telegram, and writes a 'queued' response so subagents stop polling.
const NEEDS_CLAUDE_ACTIONS = new Set([
  'code_fix',
  'delete_and_republish_scheduled', // legacy alias used by channel-promoter
  'modify_skill',
  'patch_skills', // alias for modify_skill — used by Mila octo
  'modify_nanoclaw_config',
  'octofunnel_login_needed', // Воронщик просит Шахруза залогиниться в OctoFunnel — see octofunnel-access skill
  'user_2fa_confirm', // 2FA challenge from telegram-ads (telegram-ads-http skill)
]);

// Normalize incoming request: subagents historically used different field
// names ({request_id, task, type} vs canonical {id, action, params}).
// Returns a NEW object with canonical fields filled in (without mutating original).
function normalizeRequest(raw) {
  const req = { ...raw };
  if (!req.id && req.request_id) req.id = req.request_id;
  if (!req.action) req.action = req.task || req.type || null;
  if (!req.requesting_group) req.requesting_group = req.from || null;
  if (!req.justification) req.justification = req.description || req.note || '';
  // Pass-through everything else as params if `params` not explicit
  if (!req.params) {
    const { id, request_id, action, task, type, requesting_group, from,
            justification, description, note, ...rest } = req;
    req.params = rest;
  }
  return req;
}

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

  // Fix /home/node/.agent-browser permissions in one or all live MILA
  // containers. The dir is auto-created root-owned at mount time, blocking
  // agent-browser from making its Unix socket → forces isolated profiles
  // without cookies → telegram-ads-* skills break. Idempotent: chmod 777
  // is safe to apply repeatedly.
  //
  // params:
  //   target: "all" | "<container-name>" | "<group-folder>" (default: "all")
  // Copy a file between paths INSIDE the nanoclaw repo (e.g. between two
  // groups/<x>/attachments dirs). Refuses to read or write outside REPO
  // for safety. Idempotent — overwrites destination.
  copy_file(req) {
    const src = req.params?.src;
    const dst = req.params?.dst;
    if (!src || !dst) return { ok: false, err: 'src and dst required' };
    const REPO_REAL = fs.realpathSync(REPO);
    const safeIn = (p) => {
      try {
        const real = fs.realpathSync.native ? fs.realpathSync(path.dirname(p)) : path.dirname(p);
        return real.startsWith(REPO_REAL);
      } catch {
        return path.resolve(p).startsWith(REPO_REAL);
      }
    };
    if (!safeIn(src) || !safeIn(dst)) {
      return { ok: false, err: 'src/dst must be inside ' + REPO_REAL };
    }
    if (!fs.existsSync(src)) return { ok: false, err: `src not found: ${src}` };
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
    const sz = fs.statSync(dst).size;
    return { ok: true, result: { dst, bytes: sz } };
  },

  fix_agent_browser_permissions(req) {
    // launchd-spawned processes have a minimal PATH that omits /opt/homebrew/bin
    // where the `container` CLI lives — use absolute path.
    const CONTAINER = '/opt/homebrew/bin/container';
    const target = req.params?.target || 'all';
    const list = execBash(`${CONTAINER} list 2>&1 | awk '/running/{print $1}'`);
    if (!list.ok) return { ok: false, err: 'failed to list containers: ' + list.err };
    const all = (list.out || '').trim().split('\n').filter(Boolean);
    let containers;
    if (target === 'all') {
      containers = all.filter(c => c.startsWith('nanoclaw-'));
    } else if (target.startsWith('nanoclaw-')) {
      containers = all.filter(c => c === target);
    } else {
      // group folder name → match container prefix
      containers = all.filter(c => c.includes(target));
    }
    if (containers.length === 0) return { ok: false, err: `no containers matched target=${target}` };

    const results = [];
    for (const c of containers) {
      const r = execBash(
        `${CONTAINER} exec ${c} chmod 777 /home/node/.agent-browser && ` +
        `${CONTAINER} exec ${c} ls -la /home/node/.agent-browser | head -2`
      );
      results.push({ container: c, ok: r.ok, out: (r.out || '').slice(0, 300), err: r.err });
    }
    const allOk = results.every(r => r.ok);
    return {
      ok: allOk,
      result: { fixed: results.filter(r => r.ok).length, total: containers.length, details: results },
      err: allOk ? null : 'some containers failed — see result.details',
    };
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
    // Force-sync to all group caches so groups that haven't spawned recently
    // still pick up the new skills next time (and won't get a stale snapshot).
    let syncOut = '';
    if (installed.length > 0) {
      const r = execBash(`${path.join(REPO, 'scripts/sync-skills-all-groups.sh')}`);
      syncOut = r.ok ? (r.out || '').trim().split('\n').slice(-1)[0] : `sync failed: ${r.err}`;
    }
    return {
      ok: errors.length === 0,
      result: { installed, errors, sync: syncOut, hint: 'all groups synced; live now' },
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

  // publish to a Telegram channel via telegram-scanner MCP, optionally scheduled
  // and with an image from the requester's container-side path.
  async publish_to_channel(req) {
    const p = req.params || {};
    if (!p.channel || !p.text) return { ok: false, err: 'need channel and text' };
    const groupFolder = req.requesting_group?.startsWith('telegram_') ? req.requesting_group : `telegram_${req.requesting_group}`;
    const args = { channel: p.channel, text: p.text };
    if (p.image_path || p.image_host_path) {
      const raw = p.image_host_path || p.image_path;
      const hostPath = raw
        .replace(/^\/workspace\/group/, path.join(REPO, 'groups', groupFolder))
        .replace(/^\/workspace\/global/, path.join(REPO, 'groups', 'global'));
      if (!fs.existsSync(hostPath)) return { ok: false, err: `image not found on host: ${hostPath}` };
      args.image_path = hostPath; // scanner runs on host, sees this path directly
    }
    if (p.image_base64) args.image_base64 = p.image_base64;
    if (p.schedule_date) args.schedule_date = p.schedule_date;
    if (p.disable_notification) args.disable_notification = p.disable_notification;

    // Call telegram-scanner MCP (tool: publish_to_channel)
    const scannerUrl = `http://localhost:${process.env.TELEGRAM_SCANNER_PORT || 3002}/mcp`;
    try {
      const initResp = await fetch(scannerUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream' },
        body: JSON.stringify({
          jsonrpc: '2.0', id: 1, method: 'initialize',
          params: { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'admin-ipc-daemon', version: '1.0' } },
        }),
      });
      const session = initResp.headers.get('mcp-session-id');
      if (!session) return { ok: false, err: 'no mcp session from scanner' };

      const callResp = await fetch(scannerUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json, text/event-stream',
          'Mcp-Session-Id': session,
        },
        body: JSON.stringify({
          jsonrpc: '2.0', id: 2, method: 'tools/call',
          params: { name: 'publish_to_channel', arguments: args },
        }),
      });
      const txt = await callResp.text();
      const m = txt.match(/data:\s*({.*})/);
      if (!m) return { ok: false, err: `scanner response unparseable: ${txt.slice(0, 200)}` };
      const rpc = JSON.parse(m[1]);
      const content = rpc?.result?.content?.[0]?.text || '';
      const isErr = /error|failed|Invalid|not found/i.test(content) && !/Published/i.test(content);
      return {
        ok: !isErr,
        result: { scanner_response: content, args: { ...args, image_base64: args.image_base64 ? '[omitted]' : undefined } },
        err: isErr ? content : null,
      };
    } catch (e) {
      return { ok: false, err: `scanner call failed: ${e.message}` };
    }
  },
};
// alias — Mila-channel использует это имя
executors.publish_scheduled_with_image = executors.publish_to_channel;

// ───────── Media Maker executors (audio + video production) ─────────
// All low-risk auto-approved. Output MP4/MP3 копируются в /workspace/global/attachments/
// для inline send_message доступа.

function mediaCopyToAttachments(srcPath) {
  if (!srcPath || !fs.existsSync(srcPath)) {
    return { ok: false, err: `media file not found: ${srcPath}` };
  }
  const filename = path.basename(srcPath);
  const dest = path.join(REPO, 'groups/global/attachments', filename);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(srcPath, dest);
  return { ok: true, host_path: srcPath, attachments_path: dest, container_path: `/workspace/global/attachments/${filename}` };
}

executors.render_video = async function (req) {
  const composition = req.params?.composition;
  const props = req.params?.props || {};
  const output_name = req.params?.output_name || `${composition}-${Date.now()}.mp4`;
  if (!composition) return { ok: false, err: 'composition required (Reel | Short | TgVideo | YouTubeHorizontal | Presentation | TikTok | AvatarSquare)' };

  const SCRIPT = path.join(REPO, 'container/skills/web/render-video.sh');
  const propsJson = JSON.stringify(props);
  const cmd = `${JSON.stringify(SCRIPT)} ${JSON.stringify(composition)} ${JSON.stringify(propsJson)} ${JSON.stringify(output_name)}`;
  const r = execBash(cmd, { timeout: 600_000 });
  if (!r.ok) return { ok: false, err: r.err, stderr: r.stderr };

  let parsed;
  try { parsed = JSON.parse(r.out); } catch { return { ok: false, err: 'render-video.sh non-JSON output', raw: r.out }; }
  if (parsed.error) return { ok: false, err: parsed.description || 'render failed', raw: parsed };

  const copied = mediaCopyToAttachments(parsed.path);
  if (!copied.ok) return { ok: false, err: copied.err };
  return { ok: true, result: { ...parsed, attachments_path: copied.attachments_path, container_path: copied.container_path } };
};

function videoEditExecutor(scriptName, requiredParams) {
  return async function (req) {
    for (const p of requiredParams) {
      if (!req.params?.[p]) return { ok: false, err: `${p} required` };
    }
    const SCRIPT = path.join(REPO, 'container/skills/web', scriptName);
    if (!fs.existsSync(SCRIPT)) return { ok: false, err: `helper not installed yet: ${scriptName}` };
    const args = requiredParams.map((p) => JSON.stringify(req.params[p])).join(' ');
    const cmd = `${JSON.stringify(SCRIPT)} ${args}`;
    const r = execBash(cmd, { timeout: 300_000 });
    if (!r.ok) return { ok: false, err: r.err, stderr: r.stderr };
    let parsed;
    try { parsed = JSON.parse(r.out); } catch { parsed = { raw: r.out }; }
    if (parsed.path) {
      const copied = mediaCopyToAttachments(parsed.path);
      if (copied.ok) Object.assign(parsed, { attachments_path: copied.attachments_path, container_path: copied.container_path });
    }
    return { ok: true, result: parsed };
  };
}

executors.video_concat = videoEditExecutor('video-concat.sh', ['out', 'inputs']);
executors.video_overlay_audio = videoEditExecutor('video-overlay-audio.sh', ['video', 'audio', 'out']);
executors.video_add_bgm = videoEditExecutor('video-add-bgm.sh', ['video', 'music', 'out']);
executors.video_extract_frame = videoEditExecutor('video-extract-frame.sh', ['video', 'time_s', 'out']);
executors.video_trim = videoEditExecutor('video-trim.sh', ['video', 'start_s', 'duration_s', 'out']);
executors.video_to_vertical = videoEditExecutor('video-to-vertical.sh', ['video', 'out']);

// ------------------- escalation (send inline buttons) -------------------
async function escalate(req, srcFp) {
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
  // Write the NORMALIZED req to /pending so processDecisions sees canonical fields.
  const dst = path.join(PENDING, `${reqId}.json`);
  fs.writeFileSync(dst, JSON.stringify(req, null, 2));
  if (srcFp && fs.existsSync(srcFp)) fs.unlinkSync(srcFp);
  log('escalated', reqId);
}

// ------------------- loop -------------------
async function processNewRequests() {
  const files = fs.readdirSync(REQS).filter(f => f.endsWith('.json'));
  for (const f of files) {
    const fp = path.join(REQS, f);
    let raw;
    try { raw = readJSON(fp); } catch (e) { log('unparseable', f, e.message); continue; }
    const req = normalizeRequest(raw);
    const action = req.action;
    const reqId = req.id;

    // Always give subagent feedback — never silently swallow a request.
    if (!reqId) {
      const synthId = `orphan-${Date.now()}-${f.replace(/\.json$/, '')}`;
      writeResponse(synthId, 'rejected', 'auto',
        'Schema invalid: missing id (or request_id). Use {id,action,params}. ' +
        `Filename: ${f}`, { received: raw });
      log('rejected (no id)', f);
      fs.renameSync(fp, path.join(ARCH, f));
      continue;
    }
    if (!action) {
      writeResponse(reqId, 'rejected', 'auto',
        'Schema invalid: missing action (or task/type). Use {id,action,params}.',
        { received: raw });
      log('rejected (no action)', reqId);
      fs.renameSync(fp, path.join(ARCH, f));
      continue;
    }

    // idempotence: if response already exists, skip
    if (fs.existsSync(path.join(RESPS, `${reqId}.json`))) {
      log('already has response, archiving', reqId);
      fs.renameSync(fp, path.join(ARCH, `${reqId}.json`));
      continue;
    }

    // Park requests that need a live Claude Code session in /needs-claude/
    if (NEEDS_CLAUDE_ACTIONS.has(action)) {
      const dst = path.join(NEEDS_CLAUDE, `${reqId}.json`);
      fs.renameSync(fp, dst);
      writeResponse(reqId, 'queued', 'auto',
        `Parked in /needs-claude/ — requires live Claude Code session for ${action}.`,
        { queued_path: dst });
      await tgSend(
        `🛠 *Admin-IPC: needs Claude Code*\n\n` +
        `От: \`${req.requesting_group || '?'}\`\n` +
        `Действие: \`${action}\`\n` +
        `Запрос: \`${reqId}\`\n` +
        `Файл: \`groups/global/admin-ipc/needs-claude/${reqId}.json\`\n\n` +
        `_${(req.justification || '').slice(0, 300)}_\n\n` +
        `Запусти /admin-inbox или открой файл.`
      );
      log('queued for claude', reqId, action);
      continue;
    }

    const policy = POLICY[action] || DEFAULT;

    if (policy.auto) {
      const exec = executors[action];
      if (!exec) {
        writeResponse(reqId, 'failure', 'auto', `No executor for action: ${action}`, {});
        fs.renameSync(fp, path.join(ARCH, `${reqId}.json`));
        continue;
      }
      try {
        const res = await exec(req);
        if (res.ok) {
          writeResponse(reqId, 'success', 'auto', `Auto-approved ${action}`, res.result || {});
        } else {
          writeResponse(reqId, 'failure', 'auto', res.err || 'executor failed', res.result || {});
        }
      } catch (e) {
        writeResponse(reqId, 'failure', 'auto', e.message, {});
      }
      fs.renameSync(fp, path.join(ARCH, `${reqId}.json`));
      log(action, reqId, 'auto-done');
    } else {
      await escalate(req, fp);
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
    log('executing approved', reqId, req.action);
    try {
      const res = await exec(req);
      if (res.ok) {
        writeResponse(reqId, 'success', 'shakhruz', `Approved+executed ${req.action}`, res.result || {});
        await tgSend(`✅ Готово: \`${req.action}\` (\`${reqId.slice(-8)}\`)`);
        log('done', reqId);
      } else {
        writeResponse(reqId, 'failure', 'shakhruz', res.err || 'executor failed', res.result || {});
        await tgSend(`⚠️ Одобрено, но executor упал: \`${res.err || '?'}\``);
        log('failed', reqId, res.err);
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
