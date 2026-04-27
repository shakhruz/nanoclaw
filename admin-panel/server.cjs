// NanoClaw Admin Panel — lightweight local viewer for Mila's lead conversations.
// Reads SQLite store/messages.db, renders list + chat views, generates Claude summaries.
// Local-only, no auth. Run: node admin-panel/server.js

const express = require('express');
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');

const ROOT = path.join(__dirname, '..');
const DB_PATH = path.join(ROOT, 'store', 'messages.db');
const GROUPS_DIR = path.join(ROOT, 'groups');
const PORT = process.env.ADMIN_PORT || 3030;

const db = new Database(DB_PATH, { readonly: true, fileMustExist: true });
const anthropic = new Anthropic(); // uses ANTHROPIC_API_KEY from env

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ---------- Data access ----------

function listLeads() {
  return db
    .prepare(
      `
    SELECT rg.jid, rg.name, rg.folder, rg.added_at, rg.is_public,
      (SELECT MAX(timestamp) FROM messages WHERE chat_jid = rg.jid) AS last_message_at,
      (SELECT COUNT(*) FROM messages WHERE chat_jid = rg.jid) AS message_count,
      (SELECT content FROM messages WHERE chat_jid = rg.jid AND is_from_me = 0 ORDER BY timestamp DESC LIMIT 1) AS last_user_message
    FROM registered_groups rg
    WHERE rg.is_public = 1
    ORDER BY last_message_at DESC
  `,
    )
    .all();
}

function listAllGroups() {
  return db
    .prepare(
      `
    SELECT rg.jid, rg.name, rg.folder, rg.is_main, rg.is_public,
      (SELECT MAX(timestamp) FROM messages WHERE chat_jid = rg.jid) AS last_message_at,
      (SELECT COUNT(*) FROM messages WHERE chat_jid = rg.jid) AS message_count
    FROM registered_groups rg
    ORDER BY last_message_at DESC
  `,
    )
    .all();
}

function getMessages(chatJid, limit = 500) {
  return db
    .prepare(
      `
    SELECT id, sender_name, content, timestamp, is_from_me, is_bot_message
    FROM messages
    WHERE chat_jid = ?
    ORDER BY timestamp ASC
    LIMIT ?
  `,
    )
    .all(chatJid, limit);
}

function getGroupMeta(chatJid) {
  return db
    .prepare('SELECT * FROM registered_groups WHERE jid = ?')
    .get(chatJid);
}

function getLeadProfile(folder) {
  const profilePath = path.join(GROUPS_DIR, folder, 'wiki', 'lead-profile.md');
  if (fs.existsSync(profilePath)) return fs.readFileSync(profilePath, 'utf8');
  return null;
}

// ---------- HTML rendering ----------

const BASE_STYLES = `
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdn.tailwindcss.com"></script>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
  .msg-user { background: #e0f2fe; border-left: 3px solid #0284c7; }
  .msg-mila { background: #f1f5f9; border-left: 3px solid #64748b; }
  .msg-system { background: #fef3c7; border-left: 3px solid #d97706; font-family: monospace; font-size: 0.85em; }
</style>
`;

function layout(title, body) {
  return `<!doctype html>
<html lang="ru">
<head>${BASE_STYLES}<title>${escapeHtml(title)}</title></head>
<body class="bg-gray-50 text-gray-900">
  <header class="bg-white border-b px-4 py-3 sticky top-0 z-10">
    <div class="max-w-5xl mx-auto flex items-center gap-3">
      <a href="/" class="font-semibold">🐚 NanoClaw Admin</a>
      <span class="text-gray-400">/</span>
      <span class="text-sm text-gray-600">${escapeHtml(title)}</span>
    </div>
  </header>
  <main class="max-w-5xl mx-auto p-4">${body}</main>
</body></html>`;
}

function escapeHtml(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderLeadList(leads) {
  if (!leads.length) {
    return `<div class="text-gray-500 p-8 text-center">Пока ни одного лида. Как только кто-то напишет боту @mila_gpt_bot — появится здесь.</div>`;
  }
  const rows = leads
    .map((l) => {
      const last = l.last_message_at
        ? new Date(l.last_message_at).toLocaleString('ru-RU', {
            timeZone: 'Asia/Tashkent',
            dateStyle: 'short',
            timeStyle: 'short',
          })
        : '—';
      const preview = (l.last_user_message || '').slice(0, 80);
      return `
      <a href="/lead/${encodeURIComponent(l.jid)}" class="block bg-white rounded-lg border p-4 mb-2 hover:border-blue-400 transition">
        <div class="flex items-center justify-between">
          <div class="font-semibold">${escapeHtml(l.name)}</div>
          <div class="text-xs text-gray-500">${last}</div>
        </div>
        <div class="text-sm text-gray-600 mt-1">${escapeHtml(preview) || '<em class="text-gray-400">нет сообщений</em>'}</div>
        <div class="text-xs text-gray-400 mt-2">
          ${l.message_count} сообщений · ${escapeHtml(l.folder)}
        </div>
      </a>
    `;
    })
    .join('');
  return `<h1 class="text-2xl font-bold mb-4">Лиды (${leads.length})</h1>${rows}`;
}

function renderChat(group, messages, profile) {
  const msgHtml = messages
    .map((m) => {
      const ts = new Date(m.timestamp).toLocaleString('ru-RU', {
        timeZone: 'Asia/Tashkent',
        dateStyle: 'short',
        timeStyle: 'short',
      });
      const isSystem = (m.content || '').startsWith('[System:');
      const cls = isSystem
        ? 'msg-system'
        : m.is_from_me
          ? 'msg-mila'
          : 'msg-user';
      const who = isSystem
        ? 'System'
        : m.is_from_me
          ? 'Мила'
          : m.sender_name || 'Лид';
      return `
      <div class="${cls} p-3 rounded my-1">
        <div class="flex justify-between text-xs text-gray-500 mb-1">
          <span class="font-semibold">${escapeHtml(who)}</span>
          <span>${ts}</span>
        </div>
        <div class="whitespace-pre-wrap text-sm">${escapeHtml(m.content || '')}</div>
      </div>
    `;
    })
    .join('');

  const profileHtml = profile
    ? `<pre class="bg-white border p-3 rounded text-xs overflow-x-auto">${escapeHtml(profile)}</pre>`
    : `<div class="text-gray-400 text-sm">Профиль ещё не создан (Мила добавит после первых сообщений)</div>`;

  return `
    <div class="flex items-center gap-3 mb-4">
      <a href="/" class="text-blue-600 hover:underline">← Назад</a>
      <h1 class="text-xl font-bold">${escapeHtml(group.name)}</h1>
      <span class="text-sm text-gray-500">${escapeHtml(group.folder)}</span>
    </div>

    <div class="grid md:grid-cols-[1fr,340px] gap-4">
      <div>
        <div class="flex items-center justify-between mb-2">
          <h2 class="font-semibold">Диалог (${messages.length} сообщений)</h2>
          <button onclick="genSummary()" class="text-sm bg-blue-600 text-white px-3 py-1 rounded">⚡ Summary</button>
        </div>
        <div id="summary" class="hidden mb-3 p-3 bg-amber-50 border border-amber-200 rounded text-sm whitespace-pre-wrap"></div>
        <div class="space-y-1">${msgHtml}</div>
      </div>

      <aside class="space-y-4">
        <div>
          <h3 class="font-semibold text-sm mb-2">Lead Profile</h3>
          ${profileHtml}
        </div>
        <div>
          <h3 class="font-semibold text-sm mb-2">Meta</h3>
          <div class="bg-white border rounded p-3 text-xs space-y-1">
            <div><span class="text-gray-500">JID:</span> ${escapeHtml(group.jid)}</div>
            <div><span class="text-gray-500">Added:</span> ${new Date(group.added_at).toLocaleString('ru-RU', { timeZone: 'Asia/Tashkent' })}</div>
            <div><span class="text-gray-500">Public lead:</span> ${group.is_public ? '✓' : '✗'}</div>
          </div>
        </div>
      </aside>
    </div>

    <script>
      async function genSummary() {
        const box = document.getElementById('summary');
        box.classList.remove('hidden');
        box.textContent = '⏳ Генерирую summary...';
        try {
          const r = await fetch('/api/summary/${encodeURIComponent(group.jid)}', { method: 'POST' });
          const d = await r.json();
          box.textContent = d.summary || d.error || 'пусто';
        } catch (e) {
          box.textContent = 'Ошибка: ' + e.message;
        }
      }
    </script>
  `;
}

// ---------- Routes ----------

app.get('/', (req, res) => {
  const leads = listLeads();
  res.send(layout('Лиды', renderLeadList(leads)));
});

app.get('/all', (req, res) => {
  const groups = listAllGroups();
  const rows = groups
    .map(
      (g) => `
    <a href="/lead/${encodeURIComponent(g.jid)}" class="block bg-white rounded-lg border p-3 mb-1 hover:border-blue-400">
      <div class="flex justify-between">
        <div><b>${escapeHtml(g.name)}</b> <span class="text-xs text-gray-500">${escapeHtml(g.folder)}</span></div>
        <div class="text-xs text-gray-500">${g.message_count} msg · ${g.is_main ? 'MAIN ' : ''}${g.is_public ? 'public' : ''}</div>
      </div>
    </a>
  `,
    )
    .join('');
  res.send(
    layout(
      'Все группы',
      `<h1 class="text-xl font-bold mb-4">Все зарегистрированные группы</h1>${rows}`,
    ),
  );
});

app.get('/lead/:jid', (req, res) => {
  const jid = req.params.jid;
  const group = getGroupMeta(jid);
  if (!group) return res.status(404).send(layout('Не найдено', 'Group not found'));
  const messages = getMessages(jid);
  const profile = getLeadProfile(group.folder);
  res.send(layout(group.name, renderChat(group, messages, profile)));
});

app.post('/api/summary/:jid', async (req, res) => {
  try {
    const jid = req.params.jid;
    const group = getGroupMeta(jid);
    if (!group) return res.status(404).json({ error: 'group not found' });
    const messages = getMessages(jid, 200);
    if (!messages.length) return res.json({ summary: 'Нет сообщений для анализа' });

    const transcript = messages
      .map((m) => {
        const who = (m.content || '').startsWith('[System:')
          ? 'System'
          : m.is_from_me
            ? 'Мила'
            : m.sender_name || 'Лид';
        return `${who}: ${m.content}`;
      })
      .join('\n');

    const prompt = `Это диалог AI-ассистента Милы с потенциальным клиентом. Дай короткий структурированный summary на русском:

1. Кто этот лид (имя, ниша, статус)
2. Что его беспокоит (боль, запрос)
3. Где в воронке (qualifying / interested / hot / стагнация)
4. Что Мила сделала хорошо
5. Что можно улучшить (если есть явное)
6. Рекомендуемое следующее действие

Диалог:
---
${transcript.slice(0, 50000)}
---

Summary:`;

    const resp = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 800,
      messages: [{ role: 'user', content: prompt }],
    });

    const summary = resp.content
      .filter((b) => b.type === 'text')
      .map((b) => b.text)
      .join('\n');

    res.json({ summary });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (req, res) => res.json({ ok: true, leads: listLeads().length }));

app.listen(PORT, '127.0.0.1', () => {
  console.log(`NanoClaw Admin Panel: http://127.0.0.1:${PORT}`);
});
