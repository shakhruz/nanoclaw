---
name: zernio-inbox
description: Monitor and manage comments, DMs, and reviews across all social media platforms via Zernio API. Reply to comments, manage conversations, track customer interactions. Use when asked to check messages, reply to comments, or monitor social media engagement.
---

# Zernio Inbox — Comments, DMs & Reviews

Unified inbox for all social media interactions. Monitor comments, reply to DMs, manage reviews across YouTube, Instagram, Facebook, LinkedIn, Twitter/X.

## Prerequisites

- `$ZERNIO_API_KEY` — env var

## Trigger

- "проверь комментарии", "check comments/inbox"
- "ответь на комментарий", "reply to comment"
- "что пишут в соцсетях", "новые сообщения"
- "отзывы", "reviews"

## Workflow

### Phase 1: Check Comments Inbox

```bash
curl -s "https://zernio.com/api/v1/comments/inbox" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > /tmp/zernio-comments.json
```

Display posts with comment counts. For posts with new comments:

```bash
# Get comments for specific post
curl -s "https://zernio.com/api/v1/comments/inbox/<postId>?accountId=<accountId>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY"
```

Format for user:
```
💬 *Новые комментарии*

*YouTube — «Трафик: где взять людей» (854 просм)*
• @user1: "Классное видео, а как настроить рекламу?" ← *без ответа*
• @user2: "Спасибо за контент!" ← *лайкнут*

*Instagram — Рилс про воркшоп (507 просм)*
• @user3: "Где записаться?" ← *без ответа*
```

### Phase 2: Reply to Comments

```bash
# Reply to a comment
curl -s -X POST "https://zernio.com/api/v1/comments/inbox/<postId>/reply?accountId=<accountId>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "<reply text>", "parentCommentId": "<commentId>"}'
```

**Always show draft reply before sending:**
```
💬 Ответ на комментарий @user1:
"Привет! Про рекламу расскажу в следующем видео. А пока — бесплатный воркшоп на ashotai.uz 🚀"

Отправляем?
```

**Like a comment:**
```bash
curl -s -X POST "https://zernio.com/api/v1/comments/inbox/<commentId>/like?accountId=<accountId>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY"
```

**Private reply (DM to commenter):**
```bash
curl -s -X POST "https://zernio.com/api/v1/comments/inbox/<commentId>/private-reply?accountId=<accountId>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "<private message>"}'
```

### Phase 3: Check DMs (Conversations)

```bash
curl -s "https://zernio.com/api/v1/messages/conversations" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > /tmp/zernio-dms.json
```

For specific conversation:
```bash
curl -s "https://zernio.com/api/v1/messages/conversations/<conversationId>/messages" \
  -H "Authorization: Bearer $ZERNIO_API_KEY"
```

Reply to DM:
```bash
curl -s -X POST "https://zernio.com/api/v1/messages/conversations/<conversationId>/messages" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "<message>"}'
```

### Phase 4: Check Reviews (Google Business & Facebook)

```bash
curl -s "https://zernio.com/api/v1/reviews/inbox" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" > /tmp/zernio-reviews.json
```

Reply to review:
```bash
curl -s -X POST "https://zernio.com/api/v1/reviews/inbox/<reviewId>/reply?accountId=<accountId>" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "<reply>"}'
```

### Phase 5: Summary Report

```
📬 *INBOX ОТЧЁТ*

*Комментарии:*
• Без ответа: *N*
• За сегодня: *N* новых
• Топ вопрос: "<most common question>"

*Личные сообщения:*
• Непрочитанных: *N*
• Активных диалогов: *N*

*Отзывы:*
• Новых: *N*
• Средняя оценка: *X*/5

💡 *Требует ответа:*
1. @user на YouTube: "<вопрос>" — предлагаю ответить: "<draft>"
2. @user на Instagram: "<вопрос>" — предлагаю ответить: "<draft>"
```

## Smart Reply Suggestions

When showing unanswered comments, suggest replies based on context:
- Question about price → link to website/funnel
- Question about schedule → link to booking
- Positive feedback → thank + CTA
- Negative feedback → empathetic response + offer to help in DM

## Safety Rules

- **NEVER send replies without confirmation** — always show draft
- **NEVER delete comments** without explicit request
- **Hide spam** — suggest hiding obvious spam, confirm before action
- **Private replies** — use for sensitive topics (pricing, complaints)

## Cost

Zero — included in Zernio subscription.
