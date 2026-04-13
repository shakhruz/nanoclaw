---
name: website-analyzer
description: Deep website analysis for business positioning. Browses all key pages, takes screenshots, extracts services, prices, visual identity, and UX/conversion data. Saves structured results to wiki and media catalog. Use when asked to analyze a website, landing page, or online presence.
---

# Website Analyzer

Perform a comprehensive analysis of a business website to understand positioning, services, pricing, visual identity, and conversion paths. Results feed into client profiles, funnel strategy, and competitive analysis.

## Prerequisites

- `$OPENROUTER_API_KEY` — OpenRouter API key (container env var)
- `agent-browser` — browser automation tool
- Auth sessions in `/workspace/group/*-auth.json` (loaded automatically)

## Trigger

When user asks to analyze a website or provides a URL for business analysis. Accept:
- Direct URLs: `https://example.com`, `example.com`
- Linktree/Taplink: `https://linktr.ee/username`, `https://taplink.cc/username`
- "проанализируй сайт", "analyze website", "посмотри сайт"
- Context: when building client profile and a website URL is found in Instagram bio or entity page

## Workflow

### Phase 0: Setup

```bash
export SITE_URL="<normalized-url>"
export SITE_DOMAIN=$(echo "$SITE_URL" | sed 's|https\?://||;s|/.*||')
export WD=/workspace/group/site-analysis/$SITE_DOMAIN
mkdir -p $WD/{screenshots,pages,assets}
```

Load browser auth sessions:
```bash
for f in /workspace/group/*-auth.json; do
  [ -f "$f" ] && agent-browser state load "$f" && echo "Loaded: $f"
done
```

Send progress: "Открываю сайт $SITE_DOMAIN..."

### Phase 1: Homepage Scan

```bash
agent-browser open "$SITE_URL"
agent-browser wait --load networkidle
agent-browser wait 2000
```

**1a. Full page screenshot:**
```bash
agent-browser screenshot --full $WD/screenshots/homepage-full.png
```

**1b. Above-the-fold screenshot:**
```bash
agent-browser screenshot $WD/screenshots/homepage-fold.png
```

**1c. Extract page text and structure:**
```bash
agent-browser snapshot > $WD/pages/homepage-snapshot.txt
agent-browser snapshot -i > $WD/pages/homepage-interactive.txt
agent-browser get title > $WD/pages/homepage-title.txt
agent-browser get text @body > $WD/pages/homepage-text.txt 2>/dev/null
```

**1d. Extract navigation links:**
```bash
agent-browser snapshot -i -s "nav,header,.nav,.menu,.header"
```

Parse all navigation links to build a site map. Identify key sections:
- Services / Products (услуги, каталог, прайс)
- About / Team (о нас, о компании, команда)
- Portfolio / Cases (портфолио, работы, кейсы)
- Reviews / Testimonials (отзывы)
- Pricing (цены, прайс-лист, тарифы)
- Contact (контакты, связь)
- Blog (блог, статьи)
- Booking / Order (записаться, заказать)

Send progress: "Главная страница загружена. Сканирую ключевые разделы..."

### Phase 2: Key Pages Crawl

Visit up to **6 key pages** (prioritize: services, pricing, about, portfolio, reviews, contact). For each page:

```bash
PAGE_SLUG="<page-name>"
agent-browser open "$SITE_URL/<path>"
agent-browser wait --load networkidle
agent-browser wait 1500
agent-browser screenshot --full $WD/screenshots/$PAGE_SLUG-full.png
agent-browser screenshot $WD/screenshots/$PAGE_SLUG-fold.png
agent-browser snapshot > $WD/pages/$PAGE_SLUG-snapshot.txt
agent-browser get text @body > $WD/pages/$PAGE_SLUG-text.txt 2>/dev/null
```

**Extract structured data from each page type:**

**Services page:**
- List all services with descriptions
- Note service categories and hierarchy
- Extract any pricing mentioned inline

**Pricing page:**
- Extract all prices, packages, tiers
- Note currency, discounts, special offers
- Identify upsell/cross-sell structure

**About page:**
- Team members (names, roles, photos)
- Company story, mission, values
- Credentials, certifications, awards

**Portfolio/Cases page:**
- Number of items shown
- Categories of work
- Before/after examples
- Client names (if visible)

**Reviews page:**
- Number of reviews visible
- Platforms sourced (Google, Yandex, internal)
- Average rating if shown
- Notable quotes

**Contact page:**
- Phone numbers, email, messenger links
- Physical address, map
- Working hours
- Booking/order form presence

### Phase 3: Linktree / Taplink Analysis

If the URL is a link aggregator (linktr.ee, taplink.cc, mssg.me, etc.) or if one was found in the Instagram bio:

```bash
agent-browser open "<linktree-url>"
agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/linktree-full.png
agent-browser snapshot -i > $WD/pages/linktree-interactive.txt
```

Extract all links and categorize:
- Main website
- Social media (Instagram, Telegram, YouTube, VK, TikTok)
- Booking/scheduling links
- Payment/shop links
- Messenger links (WhatsApp, Telegram bot)
- Lead magnets (free PDFs, checklists)

Follow each important link and note where it leads.

### Phase 4: Data Extraction & Analysis

**4a. Visual analysis via OpenRouter:**

For each key screenshot, analyze visually:
```bash
B64=$(base64 -i $WD/screenshots/homepage-fold.png)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Analyze this website screenshot for a business audit. Evaluate:\n1) Visual design quality (modern/outdated, colors, typography)\n2) Brand identity elements (logo, color scheme, fonts)\n3) Above-fold content (headline clarity, value proposition, CTA)\n4) Trust signals (reviews, certifications, social proof)\n5) Mobile responsiveness indicators\n6) Overall professionalism rating 1-10\nBe specific and critical."}]}]}'
```

**4b. Business information extraction:**

Compile from all page texts:
```json
{
  "businessName": "",
  "tagline": "",
  "industry": "",
  "location": "",
  "services": [{"name":"","description":"","price":""}],
  "team": [{"name":"","role":""}],
  "contacts": {"phone":"","email":"","address":"","messengers":[]},
  "socialLinks": {},
  "workingHours": "",
  "paymentMethods": [],
  "languages": []
}
```

**4c. Visual identity extraction:**
```json
{
  "primaryColors": ["#hex"],
  "secondaryColors": ["#hex"],
  "logoDescription": "",
  "typography": {"headings":"","body":""},
  "imageStyle": "",
  "overallAesthetic": "",
  "professionalismScore": 0
}
```

**4d. UX/Conversion analysis:**
```json
{
  "loadTime": "fast|medium|slow",
  "mobileResponsive": true,
  "ctaPresence": "strong|weak|missing",
  "ctaText": [],
  "bookingPath": {"steps":0,"friction":"low|medium|high"},
  "socialProof": {"reviews":false,"testimonials":false,"clientLogos":false,"caseStudies":false},
  "leadCapture": {"form":false,"popup":false,"chatWidget":false,"whatsapp":false},
  "seoBasics": {"title":"","metaDescription":"","h1":""}
}
```

### Phase 5: Save to Wiki & Media Catalog

**5a. Save structured analysis:**
```bash
cat > $WD/site-analysis.json << 'EOF'
{
  "url": "<SITE_URL>",
  "domain": "<SITE_DOMAIN>",
  "analyzedAt": "YYYY-MM-DD",
  "business": { ... },
  "visualIdentity": { ... },
  "uxConversion": { ... },
  "pages": [{"url":"","type":"","keyFindings":[]}],
  "linktree": { ... }
}
EOF
```

**5b. Copy media to wiki:**
```bash
MEDIA_DIR=/workspace/group/wiki/media/website/$SITE_DOMAIN
mkdir -p $MEDIA_DIR/{screenshots}
cp $WD/screenshots/* $MEDIA_DIR/screenshots/ 2>/dev/null
```

**5c. Create media catalog** at `wiki/media/website/$SITE_DOMAIN/catalog.md`:
```yaml
---
title: "Media Catalog — $SITE_DOMAIN"
type: media-catalog
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: website
total_images: N
color_palette: ["#hex1", "#hex2"]
tags: [website, site-analysis]
confidence: high
---
```

Table: File | Page | Description | Key Elements | Funnel Use

**5d. Create or update wiki entity page** at `wiki/entities/<site-slug>.md`:
```yaml
---
title: "Website — <domain>"
type: entity
subtype: website
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: ["[[entities/<instagram-username>]]"]
tags: [website, business, analysis]
confidence: high
---
```

Sections: Overview, Business Info, Services & Pricing, Visual Identity, UX & Conversion, Social Links, Key Findings, Recommendations.

**5e. Cross-reference with Instagram entity** if it exists:
- Add `related:` link in both directions
- Compare visual identity (colors, fonts, brand consistency)
- Compare services/pricing between platforms
- Note any discrepancies

**5f. Update wiki index, log, media-index.json, git commit:**
```bash
cd /workspace/group/wiki && git add -A && git commit -m "ingest: website analysis $SITE_DOMAIN"
```

### Phase 6: Report to User

Send a structured summary via `send_message`:

1. **Site overview** — what the business is, first impression score
2. **Services found** — list with prices if available
3. **Visual identity** — colors, style, professionalism rating
4. **Conversion analysis** — CTA strength, booking friction, lead capture
5. **Key strengths** — what works well (2-3 points)
6. **Key issues** — what needs fixing (3-5 points, prioritized)
7. **Cross-platform consistency** — if Instagram data exists, compare

Send key screenshots via `send_file` to show what was analyzed.

## Error Handling

- **Site loads slowly / times out:** increase wait time, retry once, note "slow loading" in analysis
- **Page requires login:** note as "gated content", skip, mention in report
- **Single-page site:** analyze all sections on the one page, note lack of structure
- **Site is down / 404:** report to user, suggest checking URL
- **Non-standard tech (Flash, heavy JS):** screenshot what renders, note limitation
- **Linktree only (no website):** analyze Linktree thoroughly, note absence of proper website as finding
- **Foreign language site:** analyze regardless, note language, translate key findings

## Cost

~$0.05-0.15 per site: OpenRouter vision ~$0.03-0.10, no external API costs (browser-based).
