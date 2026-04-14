---
name: funnel-strategist
description: OctoFunnel auto-funnel strategist. Reads collected Instagram, website, and YouTube data to recommend specific automated funnels with structure, content plans, channel selection, and revenue projections. Use when asked to recommend funnels, build a sales strategy, or create an OctoFunnel plan for a client.
---

# OctoFunnel Auto-Funnel Strategist

Design automated sales funnels using OctoFunnel (ashotai.uz/crm). Read all collected business data and produce a comprehensive funnel strategy with structure, content, channels, and revenue projections.

## Trigger

When user asks to recommend funnels, build a sales/marketing strategy, create an OctoFunnel plan ("предложи воронки", "стратегия продаж", "funnel strategy"), or after instagram-expert audit / website analysis is complete.

## Prerequisites

Read all available data sources:

**OctoFunnel:** `wiki/entities/octofunnel-platform.md`, `/workspace/group/wiki/`, `/workspace/group/config.json`

**Client data (any that exist):** `wiki/entities/<username>.md` (Instagram), `wiki/entities/<username>-audit.md`, `wiki/entities/<site-slug>.md` (website), `wiki/media/*/catalog.md` (photo/screenshot assets), `instagram-analysis/<username>/okto-summary.json`, `instagram-analysis/<username>/scored-posts.json`, `youtube-analysis/<channel>/channel-summary.json`, `site-analysis/<domain>/site-analysis.json`

Send progress: "Анализирую данные для построения стратегии воронок..."

## OctoFunnel Platform

**Core:** Automated funnels, Okto AI Agent (in-funnel conversations), course builder (drip content), CRM (tags/segments), analytics, payments.

**Channels:** Telegram (best CIS, bots/groups), Instagram DM (warm leads, API limits), VK (Russian audience, declining in UZ), WhatsApp (universal, high open rates, API costs), MAX (UZ local, growing, limited automation).

**Payments:** lava.top (international, cards/crypto), Click.uz (UZ, UzCard/Humo), Payme.uz (UZ, installments).

**Follow-ups:** Timed delays, action triggers (opened/clicked/purchased/abandoned), tag branching, AI-driven via Okto.

## Funnel Types Reference

1. **Lead Magnet** — collect contacts, build trust. Ad/Post → Landing → Free resource → Sequence → Offer. Best: experts, coaching, courses. Conv: 20-40% opt-in → 3-8% purchase.
2. **Webinar/Workshop** — demonstrate expertise, sell high-ticket. Register → Reminders → Event → Offer → Follow-up. Best: education, consulting, B2B. Conv: 30-50% attend → 5-15% purchase.
3. **Direct Sales** — immediate purchase. Ad → Product page → Cart → Upsell → Follow-up. Best: physical products, low-ticket digital. Conv: 2-5% cold → 10-20% warm.
4. **Consultation** — book discovery calls. Content → Application → Qualification → Booking → Follow-up. Best: high-ticket, B2B. Conv: 15-30% apply → 40-60% show → 20-40% close.
5. **Course/Digital Product** — sell educational content. Free mini-lesson → Sequence → Sales page → Onboarding → Upsell. Best: online education. Conv: 25-40% lesson → 5-12% purchase.
6. **Partnership/Affiliate** — recruit sellers. Landing → Application → Onboarding → Dashboard → Commission tracking.
7. **Event** — fill seats. Announce → Register → Pay → Reminders → Post-event upsell. Conv: 40-60% register → 60-80% attend → 10-20% upsell.
8. **Mini-Course** — low-ticket entry + upsell. Ad → $5-20 course → Value → Upsell main program. Conv: 5-10% purchase → 15-25% upgrade.

## Report Structure

Deliver via `send_message` with Telegram formatting, broken into logical message groups.

### Part 1: Business Summary
Synthesize from all data: business type/niche, audience size (IG followers, YT subs, traffic estimate), services/products with pricing, current sales channels, strengths and gaps.

### Part 2: Audience Analysis
- **Primary audience** — demographics, psychographics, pain points
- **2-3 buyer personas** — name, age, situation, motivation, objection
- **Audience temperature** — cold/warm/hot split with estimates

### Part 3: Recommended Funnels (2-4)

For each funnel:

**3a. Overview:** Type, goal, target persona, why it fits, priority (Primary/Secondary/Future).

**3b. Structure diagram** (text-based flow with arrows, e.g.):
```
[Instagram Post/Reel] → [Link in Bio] → [Telegram Bot — Lead Magnet]
  → Day 1: Content → Day 2: Case Study → Day 3: Offer + CTA
  → [Payment — Click.uz / lava.top] → [Onboarding + Upsell]
```

**3c. Content plan:** Exact content for each step (not generic), specific photos from media catalog, video content (existing or to film), copy examples.

**3d. Channel selection:** Which OctoFunnel channels, integration points, automation triggers/timing.

**3e. Revenue projection:**

| Scenario | Audience | Reach% | Click% | Conv% | Price | Revenue/mo |
|----------|----------|--------|--------|-------|-------|------------|
| Pessimistic/Realistic/Optimistic | N | X% | Y% | Z% | $P | $R |

Formula: `Monthly Revenue = Audience x Reach% x Click% x Conversion% x Average Price`

### Part 4: Quick Win Funnel
ONE funnel launchable in 1-2 days using existing content, targeting warmest segment, with step-by-step implementation guide.

### Part 5: Content Assets Mapping

| Funnel Step | Needed | Available Asset | Source | Gap |
|-------------|--------|-----------------|--------|-----|
| (map existing content to funnel needs, identify gaps) |

### Part 6: Revenue Projection Summary

| Timeline | Funnels Active | Pessimistic | Realistic | Optimistic |
|----------|---------------|-------------|-----------|------------|
| Month 1/2/3/6 | (cumulative) | | | |

### Part 7: Implementation Roadmap (30-60-90)

**Days 1-30:** OctoFunnel setup, Quick Win funnel, lead magnet, launch + first data.
**Days 31-60:** Primary funnel, automated sequences, payment processing, targeted content.
**Days 61-90:** Secondary funnels, A/B optimization, paid promotion, review projections.

## Save Results

```bash
export WD=/workspace/group/funnel-strategy/<username-or-domain>
mkdir -p $WD
```

Save `$WD/funnel-strategy.json` with: client, analyzedAt, businessSummary, audienceAnalysis, recommendedFunnels (type, priority, goal, channels, contentPlan, revenueProjection), quickWin, contentMapping, totalProjection, roadmap.

Save wiki page at `wiki/entities/<name>-funnel-strategy.md` with frontmatter (`type: entity`, `subtype: funnel-strategy`, related, tags).

```bash
cd /workspace/group/wiki && git add -A && git commit -m "ingest: funnel strategy <name>"
```

## Tone & Style

- **Strategic but practical** — every recommendation must be implementable
- **Numbers-driven** — projections from real data, not wishful thinking
- **Specific** — reference actual content, prices, audience
- **Russian language** for report (unless client operates in English)
- **Visual structure** — tables, diagrams, checklists, not walls of text
