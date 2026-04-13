---
name: zernio-monitor
description: Scheduled social media monitoring — weekly performance reports, engagement alerts, competitor tracking. Set up as recurring tasks. Use when asked to set up social media monitoring, weekly reports, or engagement alerts.
---

# Zernio Social Media Monitor

Automated monitoring of social media performance. Set up as scheduled NanoClaw tasks that run on cron.

## Prerequisites

- `$ZERNIO_API_KEY` — env var
- zernio-analytics skill (for data pulling)

## Trigger

- "настрой мониторинг соцсетей", "setup social media monitoring"
- "еженедельный отчёт по соцсетям", "weekly social report"
- "алерты по engagement"

## Available Monitors

### 1. Weekly Performance Report

Schedule as cron task (e.g. every Monday 09:30):

```
prompt: "Выполни еженедельный отчёт по соцсетям используя zernio-analytics скилл. Сравни метрики этой недели с прошлой. Покажи: рост/падение просмотров, лайков, подписчиков по каждой платформе. Выдели топ-3 поста недели. Дай 2-3 рекомендации на следующую неделю."
schedule_type: cron
schedule_value: "30 9 * * 1"
context_mode: isolated
```

Report format:
```
📊 *Еженедельный отчёт — Соцсети*
*Неделя: DD.MM — DD.MM*

*Просмотры:* <N> (▲ +X% vs прошлая неделя)
*Лайки:* <N> (▼ -X%)
*Комментарии:* <N> (= без изменений)
*Новые подписчики:* +<N>

*Топ-3 поста:*
1. 🎬 YT: «<title>» — <N> просм
2. 📸 IG: «<caption>» — <N> просм
3. 💼 LI: «<text>» — <N> просм

*Рекомендации:*
• <recommendation based on data>
```

### 2. Daily Inbox Check

Schedule daily check for unanswered comments/DMs:

```
prompt: "Проверь inbox соцсетей через zernio-inbox скилл. Если есть комментарии без ответа старше 4 часов — пришли список с предложенными ответами."
schedule_type: cron
schedule_value: "0 12 * * *"
context_mode: isolated
script: "curl -s 'https://zernio.com/api/v1/comments/inbox' -H 'Authorization: Bearer $ZERNIO_API_KEY' | node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);const has=r.posts?.some(p=>p.unreadCount>0);console.log(JSON.stringify({wakeAgent:has||false,data:{unreadPosts:r.posts?.filter(p=>p.unreadCount>0)?.length||0}}))})\""
```

### 3. Engagement Alert

Alert when a post gets unusually high engagement:

```
prompt: "Один из постов получил аномально высокий engagement. Проанализируй почему и предложи: как использовать этот тренд, стоит ли boost'ить пост, нужен ли follow-up контент."
schedule_type: interval
schedule_value: "3600"
context_mode: isolated
script: "curl -s 'https://zernio.com/api/v1/analytics?limit=5' -H 'Authorization: Bearer $ZERNIO_API_KEY' | node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const posts=JSON.parse(d).posts||[];const hot=posts.find(p=>(p.analytics?.views||0)>500&&(Date.now()-new Date(p.publishedAt))<86400000);console.log(JSON.stringify({wakeAgent:!!hot,data:hot?{title:hot.content?.slice(0,60),views:hot.analytics?.views,platform:hot.platform}:null}))})\""
```

## Setup Command

When user asks to set up monitoring, create all 3 scheduled tasks:

```bash
# Use mcp__nanoclaw__schedule_task for each:

# 1. Weekly report — Monday 09:30
schedule_task(prompt="...", schedule_type="cron", schedule_value="30 9 * * 1", context_mode="isolated")

# 2. Daily inbox — 12:00
schedule_task(prompt="...", schedule_type="cron", schedule_value="0 12 * * *", context_mode="isolated", script="...")

# 3. Engagement alert — every hour
schedule_task(prompt="...", schedule_type="interval", schedule_value="3600", context_mode="isolated", script="...")
```

Confirm to user:
```
✅ *Мониторинг соцсетей настроен:*
• 📊 Еженедельный отчёт: пн 09:30
• 💬 Проверка inbox: ежедневно 12:00
• 🔥 Алерт engagement: каждый час (скрипт, без токенов)
```

## Cost

Zero — scripts run without waking agent unless condition met. Weekly report uses 1 agent invocation per week.
