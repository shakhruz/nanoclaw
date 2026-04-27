---
name: website-analyzer
description: Deep website analysis for business positioning. Browses all key pages, takes screenshots, extracts services, prices, visual identity, and UX/conversion data. Saves structured results to wiki and media catalog. Use when asked to analyze a website, landing page, or online presence.
---

# Website Analyzer

Comprehensive analysis of a business website: positioning, services, pricing, visual identity, conversion paths. Results feed into client profiles, funnel strategy, and competitive analysis.

## Prerequisites

- `$OPENROUTER_API_KEY` — OpenRouter API key (container env var)
- `agent-browser` — browser automation tool
- Auth sessions in `/workspace/group/*-auth.json` (loaded automatically)

## Trigger

When user asks to analyze a website or provides a URL. Accept direct URLs, Linktree/Taplink URLs, or keywords like "проанализируй сайт", "analyze website". Also triggered when building a client profile and a website URL is found in bio.

## Workflow

### Phase 0: Setup

```bash
export SITE_URL="<normalized-url>"
export SITE_DOMAIN=$(echo "$SITE_URL" | sed 's|https\?://||;s|/.*||')
export WD=/workspace/group/site-analysis/$SITE_DOMAIN
mkdir -p $WD/{screenshots,pages,assets}
for f in /workspace/group/*-auth.json; do [ -f "$f" ] && agent-browser state load "$f"; done
```

Send progress: "Открываю сайт $SITE_DOMAIN..."

### Phase 1: Homepage Scan

```bash
agent-browser open "$SITE_URL" && agent-browser wait --load networkidle && agent-browser wait 2000
agent-browser screenshot --full $WD/screenshots/homepage-full.png
agent-browser screenshot $WD/screenshots/homepage-fold.png
agent-browser snapshot > $WD/pages/homepage-snapshot.txt
agent-browser snapshot -i > $WD/pages/homepage-interactive.txt
agent-browser get title > $WD/pages/homepage-title.txt
agent-browser get text @body > $WD/pages/homepage-text.txt 2>/dev/null
agent-browser snapshot -i -s "nav,header,.nav,.menu,.header"
```

Parse navigation links to build site map. Identify key sections: Services, About/Team, Portfolio/Cases, Reviews, Pricing, Contact, Blog, Booking/Order (check both EN and RU variants).

Send progress: "Главная страница загружена. Сканирую ключевые разделы..."

### Phase 2: Key Pages Crawl

Visit up to **6 key pages** (prioritize: services, pricing, about, portfolio, reviews, contact). For each page:

```bash
PAGE_SLUG="<page-name>"
agent-browser open "$SITE_URL/<path>" && agent-browser wait --load networkidle && agent-browser wait 1500
agent-browser screenshot --full $WD/screenshots/$PAGE_SLUG-full.png
agent-browser screenshot $WD/screenshots/$PAGE_SLUG-fold.png
agent-browser snapshot > $WD/pages/$PAGE_SLUG-snapshot.txt
agent-browser get text @body > $WD/pages/$PAGE_SLUG-text.txt 2>/dev/null
```

**Extract from each page type:** Services (list, categories, inline pricing) | Pricing (packages, tiers, currency, discounts, upsells) | About (team members, story, credentials) | Portfolio (item count, categories, before/after, client names) | Reviews (count, platforms, rating, notable quotes) | Contact (phone, email, messengers, address, hours, booking form).

### Phase 3: Linktree / Taplink Analysis

If the URL is a link aggregator (linktr.ee, taplink.cc, mssg.me) or one was found in bio:

```bash
agent-browser open "<linktree-url>" && agent-browser wait --load networkidle
agent-browser screenshot --full $WD/screenshots/linktree-full.png
agent-browser snapshot -i > $WD/pages/linktree-interactive.txt
```

Extract and categorize all links: main website, social media, booking, payment/shop, messenger, lead magnets. Follow each important link and note destination.

### Phase 4: Data Extraction & Analysis

**4a. Visual analysis via OpenRouter** — for each key screenshot:
```bash
B64=$(base64 -i $WD/screenshots/homepage-fold.png)
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":[
    {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,'"$B64"'"}},
    {"type":"text","text":"Analyze this website screenshot for a business audit. Evaluate: 1) Visual design quality 2) Brand identity 3) Above-fold content 4) Trust signals 5) Mobile responsiveness 6) Professionalism 1-10. Be specific."}]}]}'
```

**4b-d. Compile structured JSON** from all page texts — three objects:

- **Business info:** businessName, tagline, industry, location, services [{name, description, price}], team [{name, role}], contacts {phone, email, address, messengers}, socialLinks, workingHours, paymentMethods, languages
- **Visual identity:** primaryColors, secondaryColors, logoDescription, typography {headings, body}, imageStyle, overallAesthetic, professionalismScore
- **UX/Conversion:** loadTime, mobileResponsive, ctaPresence, ctaText[], bookingPath {steps, friction}, socialProof {reviews, testimonials, clientLogos, caseStudies}, leadCapture {form, popup, chatWidget, whatsapp}, seoBasics {title, metaDescription, h1}

### Phase 5: Save to Wiki & Media Catalog

**5a.** Save `$WD/site-analysis.json` with url, domain, analyzedAt, business, visualIdentity, uxConversion, pages [{url, type, keyFindings}], linktree.

**5b.** Copy screenshots to `wiki/media/website/$SITE_DOMAIN/screenshots/`.

**5c.** Create media catalog at `wiki/media/website/$SITE_DOMAIN/catalog.md` with YAML frontmatter (title, type: media-catalog, dates, source: website, total_images, color_palette, tags) and table: File | Page | Description | Key Elements | Funnel Use.

**5d.** Create/update wiki entity page at `wiki/entities/<site-slug>.md` with YAML frontmatter (title, type: entity, subtype: website, dates, related, tags). Sections: Overview, Business Info, Services & Pricing, Visual Identity, UX & Conversion, Social Links, Key Findings, Recommendations.

**5e.** Cross-reference with Instagram entity if it exists — add bidirectional `related:` links, compare visual identity and services/pricing, note discrepancies.

**5f.** Update wiki index, log, media-index.json, then:
```bash
cd /workspace/group/wiki && git add -A && git commit -m "ingest: website analysis $SITE_DOMAIN"
```

### Phase 6: Report to User

Send structured summary via `send_message`: site overview with first impression score, services found with prices, visual identity summary with professionalism rating, conversion analysis (CTA strength, booking friction, lead capture), key strengths (2-3), key issues (3-5 prioritized), cross-platform consistency (if Instagram data exists).

Send key screenshots via `send_file`.

## Error Handling

Site timeout: retry once, note slow loading. Login-gated: skip, note in report. Single-page: analyze all sections on one page. Site down: report to user. Linktree-only: analyze thoroughly, note absence of website. Foreign language: analyze regardless, translate key findings.

## Cost

~$0.05-0.15 per site (OpenRouter vision).
