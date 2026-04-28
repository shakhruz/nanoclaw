## Wiki — second brain access

A persistent markdown wiki lives at **`/workspace/global/wiki/`** in every container. It is the user's accumulated knowledge — clients, brand guides, decisions, transcripts, source material, project notes, journal entries.

### Two roles, one wiki

The wiki is shared across all agent groups but with role-based access:

#### Curator (the chat owner — typically the one named after the user, e.g. *Mila* in the main DM)
- Read + **write** anywhere in the wiki.
- Owns top-level structure: `index.md`, `log.md`, `essentials.md`, `tags.md`, `inbox.md`.
- Promotes inbox entries from contributors into formal pages.
- Runs `wiki-contributor.sh` lint pass weekly + on demand.

#### Contributors (specialist agents created via `create_agent` — e.g. *marketolog*, *designer*, etc.)
- **Read-only** mount of `/workspace/global/wiki/`. Cannot write.
- May write to `inbox.md` only via the Curator (a2a request — see below).
- Should read `/workspace/global/wiki/index.md` first when working on a task — it's the navigation map.
- Read role-relevant pages: clients, offer catalog, case studies, brand guide, recent decisions.

### When you start a task

1. **First container in a session:** open `/workspace/global/wiki/index.md` to refresh on what's where. Index lists clients, projects, products, sources.
2. Look up role-relevant pages: if you're a sales role — `wiki/projects/sales/`; if marketing — `wiki/projects/marketing/`; if a particular client — `wiki/people/<client>.md` or `wiki/projects/<client>/`.
3. Don't re-derive what's already written. Cite the wiki page when relevant ("По брендбуку — стиль X. Подробности: `wiki/architecture/brand.md`").

### Specialists asking Curator for wiki updates (a2a query pattern)

Sometimes you (a contributor specialist) need information that's not yet in the wiki, or want to ADD a finding. You can NOT write to the wiki directly. Two options:

#### Pattern 1: ask Curator to look up and synthesize

```
send_message({
  to: "parent",
  channel: "agent",
  text: "Маркетолог: для брифа нужна история работы с клиентами в beauty-нише. Можешь поискать в wiki/people и wiki/projects/clients/, дать выжимку: 3-5 кейсов, типичные боли, что сработало?"
})
```

Curator reads the wiki, synthesizes, replies. Faster than reading 30 files yourself.

#### Pattern 2: drop note into inbox via Curator

```
send_message({
  to: "parent",
  channel: "agent",
  text: "Маркетолог: нашёл важное наблюдение по сегменту stomatology — у них средний чек 200k, цикл сделки 7-14 дней. Запиши в wiki/inbox.md, я обработаю при ingest'e позднее."
})
```

Curator promotes it into the right page during the next morning brief / ingest pass.

### When you're the Curator

When a contributor sends an a2a wiki query — **read the wiki, synthesize what's relevant, reply via the contributor's destination** (their local_name from your perspective). Don't dump full pages — extract the bits relevant to their task. Provide page paths so they can dig deeper if needed.

Inbox entries from contributors — accumulate in `inbox.md`. Process on next morning brief / when user explicitly asks. Convert into formal pages (entities, sources, projects) per Karpathy LLM Wiki pattern.

### Anti-patterns

- ❌ Don't write to wiki without curator permission if you're a contributor — the mount is read-only and writes will fail anyway.
- ❌ Don't ask "what's in wiki?" — be specific ("что у тебя в wiki по клиенту X / по нише Y / по продукту Z").
- ❌ Don't store secrets (API keys, tokens, passwords) in wiki. Lint will flag them, and they leak into source control.
- ❌ Binary media >1MB → not in wiki. Use `.md` stub with metadata.

### Path summary

| Path inside container | What it is |
|---|---|
| `/workspace/global/wiki/` | Shared wiki (RO for contributors, RW for curator) |
| `/workspace/agent/` | Your own agent group folder (RW) — your private notes, drafts, artifacts |
| `/workspace/agent/CLAUDE.local.md` | Your role/persona (per-agent memory) |
