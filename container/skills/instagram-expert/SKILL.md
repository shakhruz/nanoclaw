---
name: instagram-expert
description: Instagram marketing audit and expert recommendations. Reads data collected by instagram-analyzer (wiki entities, media catalogs, scored posts/reels, screenshots) and delivers a comprehensive 8-section audit report with actionable advice. Use when asked to evaluate an Instagram profile, give recommendations, or perform an Instagram audit.
---

# Instagram Marketing Expert

Direct, data-driven Instagram marketing consultant. Reads instagram-analyzer data and produces a comprehensive audit with specific, actionable recommendations.

## Trigger

"оцени профиль", "дай рекомендации", "аудит инстаграм", "analyze profile", "instagram audit", or any IG marketing advice request for a specific account.

## Prerequisites

Data must exist from instagram-analyzer: `wiki/entities/<username>.md`, `wiki/media/instagram/<username>/catalog.md`, `instagram-analysis/<username>/okto-summary.json`, `scored-posts.json`, `scored-reels.json`, screenshots. If missing, tell user to run instagram-analyzer first.

## Workflow

### Phase 0: Load Data

```bash
export WD=/workspace/group/instagram-analysis/<username>
```

1. Read entity page, media catalog, okto-summary, scored-posts/reels
2. Analyze key screenshots via OpenRouter vision:
```bash
B64=$(base64 -i $WD/screenshots/profile-top.png)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Analyze this Instagram profile screenshot. Evaluate: bio clarity, visual first impression, avatar quality, highlight covers consistency, grid aesthetics, brand colors. Be specific and critical."}]}]}'
```

Send progress: "Анализирую данные профиля @<username>..."

### Phase 1: Compute Scores

Calculate 0-100 score per category:

| Category | Weight | Evaluates |
|----------|--------|-----------|
| Bio & First Impression | 15% | Avatar, username, bio structure, highlights, link |
| Visual Identity | 20% | Colors, grid, photo quality, brand elements, fonts |
| Content Strategy | 25% | Frequency, content mix, hashtags, reels, variety |
| Engagement | 15% | ER vs benchmark, comment quality, reply rate, saves |
| Sales & Conversion | 15% | CTA, link in bio, booking path, pricing, social proof |
| Trust & Authority | 10% | Reviews, credentials, BTS content, consistency |

**Overall Score** = weighted average. Use visual bars (10 blocks, `█` filled / `░` empty):
```
Bio:     ████████░░ 80/100
Visual:  ██████░░░░ 60/100
OVERALL: ██████░░░░ 65/100
```

## Audit Report Structure

Deliver in **8 sections** via `send_message` (Telegram formatting). Split into 2-3 messages to avoid wall-of-text.

### Section 1: Score Card
Overall + per-category scores with visual bars. One-line verdict (biggest strength, biggest gap). Niche benchmark comparison.

### Section 2: Bio & First Impression
Evaluate avatar, username, bio structure (Hook, Value Prop, Social Proof, CTA), highlights, link. Provide a **concrete bio rewrite** — not "improve your bio" but the actual improved text.

### Section 3: Visual Identity
Color palette from catalog vs competitors, grid layout patterns, photo quality/consistency, brand elements, carousel design. Give 3-5 specific visual fixes with examples from their content.

### Section 4: Content Strategy
Posting frequency (actual vs recommended). Content mix analysis vs ideal ratio: Educational 40%, Engaging 30%, Sales 20%, Personal 10%. Hashtag analysis, reels strategy (frequency, hooks, audio, view ratio). Propose a weekly content calendar.

### Section 5: Engagement & Growth
ER calculation from scored-posts, ER vs benchmark, comment quality ratio, best posting times, growth signals, community building (replies, Stories interactions).

### Section 6: Sales & Conversion
Path to purchase (steps from profile to sale), CTA analysis, booking friction, social proof visibility, pricing strategy, Story highlights as sales funnel (Reviews, Services, Pricing, How to Book).

### Section 7: Competitive Context
Search for 3-5 similar accounts in same niche/region via `agent-browser`. For each: follower count, ER, what they do better, what analyzed account does better, ideas to borrow. Present as comparison table.

### Section 8: Actionable Roadmap (30-60-90 Days)
**Days 1-30 (Quick Wins):** Bio rewrite, highlight covers, top 3 visual fixes, posting schedule, add CTAs.
**Days 31-60 (Content System):** Content pillars, reels strategy, hashtag sets (provide 3 sets of 15-20), engagement routine (30 min/day).
**Days 61-90 (Growth & Sales):** Lead magnet, A/B test content, UGC strategy, metrics review.
Each item must be specific to THIS account.

## Industry Benchmarks

| Niche | Good ER | Great ER | Post Freq | Reels % |
|-------|---------|----------|-----------|---------|
| Beauty/Salon | 2.5% | 4%+ | 4-5/wk | 40% |
| Fitness/Health | 2% | 3.5%+ | 5-7/wk | 50% |
| Food/Restaurant | 3% | 5%+ | 5-7/wk | 30% |
| Education/Coaching | 2% | 3%+ | 3-5/wk | 35% |
| Fashion | 1.5% | 3%+ | 4-6/wk | 45% |
| Real Estate | 1.5% | 2.5%+ | 3-5/wk | 40% |
| E-commerce | 1% | 2%+ | 5-7/wk | 35% |
| Photography | 3% | 5%+ | 3-4/wk | 25% |
| Medical/Dental | 2% | 3.5%+ | 3-4/wk | 30% |
| IT/Tech | 1.5% | 2.5%+ | 3-4/wk | 30% |
| Events/Wedding | 2.5% | 4%+ | 3-5/wk | 35% |
| Auto/Detailing | 2% | 3.5%+ | 4-5/wk | 40% |
| Home/Interior | 2.5% | 4%+ | 3-5/wk | 30% |
| Travel/Tourism | 3% | 5%+ | 4-6/wk | 40% |
| Handmade/Craft | 3% | 5%+ | 4-5/wk | 30% |

Use closest matching niche. For multi-niche accounts, use weighted average.

## Save Results

```bash
cat > /workspace/group/wiki/entities/<username>-audit.md << 'AUDIT_EOF'
---
title: "Instagram Audit — @<username>"
type: entity
subtype: instagram-audit
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: ["[[entities/<username>]]"]
tags: [instagram, audit, marketing]
confidence: high
---
# Instagram Audit — @<username>
<Full audit content>
AUDIT_EOF
```

Update `wiki/index.md` and `wiki/log.md`, then:
```bash
cd /workspace/group/wiki && git add -A && git commit -m "ingest: instagram audit @<username>"
```

## Tone & Style

Direct and specific (say exactly what to change). Numbers first (every claim backed by data). Constructive but honest. Russian language unless profile is English. Telegram formatting (bold headers, monospace for data, minimal emoji).

## Error Handling

Missing scored-posts: calculate ER from okto-summary. No screenshots: skip visual analysis, note limitation. No media catalog: focus on metrics/strategy. Competitor search fails: skip Section 7, recommend manual research.
