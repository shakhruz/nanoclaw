---
name: client-prep
description: Pre-meeting preparation — assembles all client intelligence into a sales briefing with talking points, objection handlers, and optionally creates a demo funnel via OctoFunnel. Use before a client meeting to have full context, strategy, and a ready demo.
---

# Client Prep — Pre-Meeting Sales Briefing

Prepare for a client meeting by assembling all collected intelligence into an actionable briefing with context, analysis, strategy, and optionally a ready demo funnel.

## Trigger

"подготовь меня к встрече с @username", "клиент-преп", "client prep", "козыри на @username", "briefing for meeting with..."

## Workflow

### Phase 1: Check Available Data

```bash
NAME="<client-name-or-username>"
for f in entities/$NAME.md entities/$NAME-audit.md entities/$NAME-funnel-strategy.md entities/client-$NAME.md; do
  echo "$f: $([ -f /workspace/group/wiki/$f ] && echo FOUND || echo MISSING)"
done
for d in website-analysis/*/site-analysis.json youtube-analysis/*/channel-summary.json; do
  echo "$d: $(ls /workspace/group/$d 2>/dev/null && echo FOUND || echo MISSING)"
done
echo "okto-summary: $([ -f /workspace/group/instagram-analysis/$NAME/okto-summary.json ] && echo FOUND || echo MISSING)"
echo "media-catalog: $([ -f /workspace/group/wiki/media/instagram/$NAME/catalog.md ] && echo FOUND || echo MISSING)"
```

**CRITICAL: Do NOT generate a weak briefing.** If key analyses are missing, run them first:

| Missing | Action |
|---------|--------|
| Instagram Analysis | Run instagram-analyzer |
| Instagram Audit | Run instagram-expert |
| Website Analysis | Extract URLs from okto-summary/bio, run website-analyzer |
| YouTube | Ask user for channel link, run youtube-analyzer |
| Funnel Strategy | Run funnel-strategist |
| Client Profile | Run client-profile workflow |

**Minimum required:** Instagram Analysis + Instagram Audit + Funnel Strategy.

Send progress: "Проверяю готовность данных... Найдено: IG ✅, Audit ❌, YouTube ❌. Запускаю недостающие анализы..."

### Phase 1.5: Web Presence Discovery + Search Analysis

**1.** Ask user for additional social links (YouTube, Facebook, TikTok, LinkedIn, VK, Telegram). Don't wait long — proceed with search.

**2.** Search via `mcp__parallel-search__*` if available, otherwise `agent-browser`. Queries: `"<name> <niche> <city>"`, `"<name> instagram"`, `"<domain>"`, `"<name> отзывы"`. Run for both Google and Yandex.

**3.** Analyze: page 1 results, Knowledge Panel / Yandex business card, negative results, site position, competitors in SERP.

**4.** Build platform presence map (table: Platform | URL | Status | Notes) covering Instagram, YouTube, Telegram, Facebook, TikTok, LinkedIn, VK, Website, 2GIS/Yandex Maps.

Offer to analyze newly discovered platforms.

### Phase 2: Read All Intelligence

Read every available file. Build mental model of: who they are, what they sell/to whom/at what price, strengths (to acknowledge), weaknesses (our opportunity), existing assets for funnels.

### Phase 3: Generate Sales Briefing

**IMPORTANT:** Incorporate specific data from audit, funnel strategy, okto-summary, and media catalog. Use actual numbers, not generic advice.

Send via `send_message` (respect Telegram 4096 char limit):

**Message 1 — Client Overview:** Header (name, niche, geography). Key metrics (IG followers/ER, YouTube subs, website domain/platform, price range). Business summary (2-3 sentences). Target audience.

**Message 2 — Web Presence & Search:** Platform presence list with status icons. Google and Yandex results (site position, Knowledge Panel, SERP landscape). SEO opportunity note.

**Message 3 — Strengths & Weaknesses:** Strengths with specific numbers (3 items). Weaknesses paired with our solutions (3 items). Lost revenue estimate with specific problem.

**Message 4 — Talking Points:** Opener (cite impressive metric). Key argument (pain to solution with numbers). Demo pitch. Close (timeline, price, ROI). Objection handlers for "too expensive" (show ROI), "I can do it myself" (show time cost), "need to think" (show competitor urgency).

**Message 5 — Recommended Funnels:** Quick Win (1 day launch), Main funnel (1 week), Scale funnel (1-2 months). Each with name, service, price, potential revenue. Total monthly potential.

**Message 6 — Available Assets:** Photo count (banner-worthy), video count, reviews, prices, adaptable post texts. Note everything is ready for funnel use.

### Phase 4: Create Demo Funnel

Propose creating a demo funnel. If user agrees (or funnel-strategy exists):
1. Read client-profile.json, pick Quick Win funnel
2. Select best author photo from catalog
3. Use real services/prices
4. If OctoFunnel CRM access: create via agent-browser + Okto AI chat (brief: name, service, price, audience, photo)
5. If no CRM: create funnel brief document with all content ready
6. Send demo link/brief to user

### Phase 5: Save to Wiki

Save to `wiki/entities/client-<name>-prep.md` with YAML frontmatter (title, type: entity, subtype: client-prep, dates, related, tags). Update index + log. Git commit.

## Re-prep (repeat meetings)

If prep exists, read previous and note changes since last meeting (follower growth, new posts, price changes).

## Cost

Zero API cost — reads existing data. Demo funnel may use OctoFunnel (free for account owner).
