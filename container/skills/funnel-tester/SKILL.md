---
name: funnel-tester
description: Self-test Mila's sales funnel by emulating user journeys via Telegram Scanner userbot. Sends /start with deep-link params to @mila_gpt_bot, reads responses, evaluates quality, and generates a test report.
---

# Funnel Tester

Tests Mila's sales funnel end-to-end by having the Telegram Scanner userbot (@ashot_ashirov_ai) act as a potential customer.

## Trigger

- "протестируй воронку", "test funnel", "проверь /start"
- Scheduled: after deploying changes to sales CLAUDE.md or product catalog

## Prerequisites

- `telegram-scanner` MCP running with `send_dm` and `read_dm_history` tools
- @mila_gpt_bot running (NanoClaw online)

## Test Scenarios

| # | Deep link | Expected persona | Expected CTA |
|---|-----------|-----------------|--------------|
| 1 | (none) | General greeting, ask about business | Any |
| 2 | uz | UZ market hook | Consultation |
| 3 | expert | Expert packaging | OctoFunnel demo |
| 4 | business | Business analysis | Consultation |
| 5 | startup | Quick funnel | Workshop |
| 6 | marketer | AI tools | MILA GPT |
| 7 | freelancer | Freelancer analysis | Consultation |

## Algorithm

### For each scenario:

**Step 1: Send /start**
```
mcp__telegram-scanner__send_dm(username="mila_gpt_bot", text="/start <param>")
```

For no-param test: `text="/start"`

**Step 2: Wait for response**

Wait 60-90 seconds. The first response is instant (static welcome), the AI response takes 30-60s (cold start).

**Step 3: Read response**
```
mcp__telegram-scanner__read_dm_history(username="mila_gpt_bot", limit=10)
```

**Step 4: Evaluate welcome**

Score 1-5 on each criterion:
- Greeting present and warm?
- Mentions Shakhruz / AshotAI?
- Asks qualification question?
- Language matches expectation?
- Not too long (2-3 paragraphs max)?

**Step 5: Send follow-up (simulate user)**

Send a realistic user message based on the persona:
```
mcp__telegram-scanner__send_dm(username="mila_gpt_bot", text="<follow-up>")
```

Example follow-ups by scenario:
- uz: "У меня магазин одежды в Ташкенте, хочу выйти в онлайн"
- expert: "Я преподаю английский, хочу создать онлайн-курс"
- business: "У меня интернет-магазин, конверсия низкая"
- startup: "Только начинаю, ещё нет продукта"
- marketer: "Веду SMM для 5 клиентов, хочу автоматизировать"
- freelancer: "Делаю дизайн на фрилансе, хочу масштабироваться"

**Step 6: Wait + read AI response**

Wait 60-90 seconds, read history again.

**Step 7: Evaluate sales response**

Score 1-5:
- Acknowledged user's business?
- Identified a pain point?
- Recommended a specific product (not all at once)?
- Product recommendation matches the signal?
- CTA present (link, button, or direct action)?
- Tone: expert but friendly, not pushy?

**Step 8: Score summary**

For each scenario, compute:
- Welcome score (avg of Step 4)
- Sales score (avg of Step 7)
- Overall score (avg of both)

### Generate Report

```
Funnel Test Report — {date}

| Scenario | Welcome | Sales | Overall | Issues |
|----------|---------|-------|---------|--------|
| /start | 4.2 | - | 4.2 | No qualification Q |
| uz | 4.8 | 4.0 | 4.4 | OK |
| expert | 3.5 | 4.5 | 4.0 | Greeting too generic |
| ... | ... | ... | ... | ... |

Top issues:
1. ...
2. ...

Recommendations:
1. ...
2. ...
```

Send report to Shakhruz via `mcp__nanoclaw__send_message`.

## Important Notes

- Add 5-10 second delays between messages to avoid Telegram rate limiting
- Don't test more than 3-4 scenarios per run (each takes ~2 min)
- Clear DM history context: the userbot's prior conversation with @mila_gpt_bot may affect responses
- The test creates real lead registrations — clean up test leads after via main group

## Cleanup After Testing

After test is complete, inform Shakhruz which test leads were created so he can decide whether to keep or remove them.
