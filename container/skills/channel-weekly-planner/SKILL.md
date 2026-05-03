---
name: channel-weekly-planner
description: Single-phrase weekly content-plan preparation for @ashotonline. Reads all channel pools (personas/tools/skills/events/hashtags/sales-funnel), drafts the next week's plan, proposes 3 candidates per rubric day for Shakhruz to choose, finalizes file at wiki/projects/content-plan-YYYY-MM-DD.md, schedules daily publishing tasks. Auto-runs every Saturday 12:00 Tashkent. Persists — keeps reminding Shakhruz until the plan is approved.
---

# Channel Weekly Planner

Один скилл — одна фраза от Шахруза. Mila готовит контент-план на следующую неделю, согласует выборы рубрик, фиксирует в wiki, ставит scheduled задачи на каждый день.

## Триггеры — Mila запускает скилл когда видит:

- «давай готовить контент-план на неделю»
- «контент-план», «план на неделю», «план публикаций»
- «приготовь контент-план», «составь план для канала»
- **Каждую субботу 12:00 Tashkent автоматически** (через scheduled task — см. ниже)
- **Reminder loop**: если план для текущей недели не утверждён до Сб 20:00, Сб 22:00, Вс 09:00 — Mila сама пинает Шахруза снова

## Что читать перед началом (обязательные источники)

```bash
WIKI=/workspace/group/wiki/projects/channel
cat $WIKI/master-content-plan.md         # расписание + бренд
cat $WIKI/personas-pool.md                # копилка персон
cat $WIKI/tools-pool.md                   # копилка инструментов
cat $WIKI/skills-prompts-pool.md          # копилка скиллов/промптов
cat $WIKI/events-pool.md                  # копилка тем для эфиров
cat $WIKI/hashtag-system.md               # таксономия тегов
cat $WIKI/sales-funnel.md                 # продающая воронка
cat $WIKI/log.md                          # что уже опубликовано
```

Также найти последние существующие content-plan'ы для формата:
```bash
ls /workspace/group/wiki/projects/content-plan-*.md | tail -3
```

## Algorithm

### Step 1 — Determine week dates

```bash
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)  # 1=Mon, 7=Sun
# Next Monday
DAYS_TO_MON=$(( (8 - DOW) % 7 ))
[ $DAYS_TO_MON -eq 0 ] && DAYS_TO_MON=7  # if today is Monday, plan for next week
WEEK_MON=$(date -v+${DAYS_TO_MON}d +%Y-%m-%d 2>/dev/null || date -d "+$DAYS_TO_MON days" +%Y-%m-%d)
WEEK_SUN=$(date -v+$((DAYS_TO_MON+6))d +%Y-%m-%d 2>/dev/null || date -d "+$((DAYS_TO_MON+6)) days" +%Y-%m-%d)
PLAN_FILE=/workspace/group/wiki/projects/content-plan-${WEEK_MON}.md
```

If `$PLAN_FILE` уже существует и `status: approved` — план уже утверждён, ничего не делаем (только подтверждаем Шахрузу: «План на $WEEK_MON уже утверждён, он работает»).

If существует но `status: draft` — продолжаем с того места (читаем что там есть).

If не существует — создаём с нуля.

### Step 2 — Detect already-published candidates (avoid repeats)

Из `log.md` за последние 90 дней:
- Какие персоны уже публиковались — отметим их `status: published-...` в personas-pool, не предлагаем повторно
- Аналогично для tools и skills-prompts

### Step 3 — Set theme of the week (для пятничного эфира + субботнего мастер-класса)

Если в `events-pool.md` есть тема со `status: scheduled-<этой_недели>` — берём её.

Если нет — предложить 3 темы из tier-1 events-pool:

```
🎯 *Тема недели для эфиров (Пт + Сб)*

Кандидаты:
1. *<Theme1>* — <one-line>
2. *<Theme2>* — ...
3. *<Theme3>* — ...

Какую берём? «1», «2», «3» или предложи свою.
```

После выбора — `status: scheduled-<week_mon>` в events-pool, тема прописывается в шапку content-plan.

### Step 4 — Suggest persona candidates (Ср)

3 кандидата из tier-1 personas-pool со `status: pool` (не published за последние 6 месяцев). Для каждого — свежий research через `parallel-search` или `web_search`: что делал/говорил за последние 14 дней.

```
👤 *Персона на Ср $ВЕДНЕСДЕЙ*

1. *<Name1>* — <angle>. Свежее: <recent>. Tier 1.
2. *<Name2>* — ...
3. *<Name3>* — ...

Какого? «1», «2», «3» или «другого предложи».
```

### Step 5 — Suggest tools candidate (Пт)

3 кандидата из tools-pool: 1 tier-1 (стек Шахруза), 1 tier-2, 1 tier-3. Учитывать тему недели — если возможно, выбрать инструмент связанный с темой.

```
🛠 *Инструмент на Пт $ПЯТНИЦА*

1. *<Tool1>* (tier 1, <category>) — use-case: <example>
2. *<Tool2>* (tier 2)
3. *<Tool3>* (tier 3)

Какой берём?
```

### Step 6 — Suggest skill/prompt candidate (Чт)

3 кандидата из skills-prompts-pool по разным категориям (sales / content / research / dev / analytics / personal-productivity / lead-gen).

```
🧠 *Скилл на Чт $ЧЕТВЕРГ*

1. *<Recipe1>* (#<category>, простой) — задача: <one-line>
2. *<Recipe2>* (#<category>, средний)
3. *<Recipe3>* (#<category>, продвинутый)

Какой берём?
```

### Step 7 — Compose draft plan file

После того как Шахруз сделал все 4 выбора (тема + персона + инструмент + скилл) — Mila собирает черновик `content-plan-${WEEK_MON}.md`:

```markdown
---
title: "Контент-план $WEEK_MON — $WEEK_SUN"
type: project
subtype: content-plan
created: $TODAY
status: draft
goal: "<краткая цель — соответствует теме недели + sales-funnel>"
theme_of_week: "<выбранная тема>"
platforms: [telegram]
related:
  - "[[projects/channel/master-content-plan]]"
  - "[[projects/channel/events-pool]]"
tags: [content, plan, telegram, ashotonline]
---

# Контент-план $WEEK_MON — $WEEK_SUN

**Тема недели:** <выбранная тема>
**Цель:** <обучение по теме + sales-touch к Octo trial / клубу>

---

## Понедельник $DATE — AI-дайджест 09:30

**Тип**: AI-дайджест (morning mode + public)
**Скилл**: ai-news-digest
**Источник**: NEWS-папка + parallel-search EN-web (last 30h)
**Sales-touch**: упомянуть тему недели в подводке («скоро расскажу подробнее в эфире пятницы»)
**Хэштеги**: #AIновости #Тренды

[аналогично для каждого дня...]

## Среда $DATE

### AI-дайджест 09:30
[как Пн]

### Персона недели 11:00 — <Имя>
**Скилл**: channel-persona-week
**Кандидат выбран**: <Имя> (из personas-pool, tier <N>)
**Источники для research**: ...
**Хэштеги**: #ИИперсона #ЛидерыИИ #<имя>

[и так далее для всех дней...]

## Пятница $DATE

### AI-дайджест 09:30
[...]

### Топ инструментов 12:00 — <Tool>
[...]

### Открытый эфир 14:00-15:00 — <Тема>
**Шахруз ведёт live в @ashotonline**
**Содержание**:
- 30 мин: ревью моей бизнес-недели — что сделал, какие инсайты
- 30 мин: тизер темы недели — глубже расскажу в субботу для клуба

### Анонс эфира — Чт 17:00 (накануне)
**Скилл**: channel-friday-announce
**Текст шаблон**: «завтра $TIME эфир по теме <Тема>. Кто хочет углубиться — в субботу 10:00 закрытый мастер-класс для клуба»

### Recap эфира — Пт 15:30-16:30 (после)
**Скилл**: channel-friday-recap
**Содержание**: summary эфира + ссылка на запись + CTA на Octo trial / клуб

## Суббота $DATE

### AI-дайджест 10:00 (weekend mode)
[...]

### Закрытый мастер-класс 10:00-12:00 — <Тема>
**Шахруз ведёт в чате клуба** (НЕ в @ashotonline)
**Только для членов клуба + партнёров**
**Содержание**: углублённый разбор темы, материалы, кейсы

### Выписка для клуба — Сб 12:30-13:00
**Скилл**: channel-saturday-club-recap
**Куда**: внутренний чат клуба (не публично)

### Тренд недели 13:00
**Скилл**: channel-trend-week (динамически выбирает тренд из log.md)

## Воскресенье $DATE — Еженедельный обзор 18:00

**Скилл**: channel-weekly-summary
**Содержание**: recap всей недели + main trend + CTA

---

## Sales-touches (раз в неделю)

- В одном из дайджестов (Вт или Чт) — упомянуть Octo trial в context'е новости
- В Топ инструментов (Пт) — обязательный CTA если выбран Octo
- В пятничном recap'е — обязательный CTA на trial / клуб
- В weekly summary (Вс) — короткий CTA в конце

## Открытые вопросы / TBD

- [ ] Картинки для рубрик — генерировать заранее по сб или ad-hoc в день публикации?
- [ ] Если в выходные не будет горячих новостей — короткий weekend-edition дайджест без 7 stories?

---

## История изменений

- $TODAY — план составлен Mila по запросу Шахруза, status: draft.
```

### Step 8 — Send to Шахрузу для approval

```
📋 *Контент-план $WEEK_MON — $WEEK_SUN готов в драфте*

Тема: <тема>
Все рубрики выбраны.
Файл: /workspace/group/wiki/projects/content-plan-$WEEK_MON.md

Можешь:
• «утвердить» — поставлю scheduled задачи на каждый день, поехали
• «правки: <текст>» — скажи что поменять
• «покажи план» — высылаю текст полный

Жду до утверждения.
```

### Step 9 — On approval

После того как Шахруз сказал «утвердить» / «approve» / «поехали»:

1. Update `$PLAN_FILE` — `status: approved`
2. Update pools — `status: scheduled-<date>` для всех выбранных
3. Schedule daily tasks через `mcp__nanoclaw__schedule_task` для каждого пункта плана:

```
schedule_type: cron
schedule_value: "30 9 * * 1-5"   # пример для AI-дайджеста Пн-Пт 09:30
context_mode: group
prompt: "Запусти ai-news-digest скилл с public_publish=true. Опубликуй в @ashotonline через telegram-publish с default --schedule=+1h."
```

И аналогично для рубрик, обзора, эфирных скиллов.

4. Reply Шахрузу:
```
✅ План $WEEK_MON — $WEEK_SUN утверждён, scheduled задачи поставлены.

Расписание (всего N задач):
• Пн-Пт 09:30 — AI-дайджест × 5
• Ср 11:00 — Персона
• Чт 11:30 — Скиллы
• Чт 17:00 — Анонс эфира
• Пт 12:00 — Инструменты
• Пт 15:30 — Recap эфира
• Сб 10:00 — AI-дайджест weekend
• Сб 12:30 — Выписка для клуба
• Сб 13:00 — Тренд недели
• Вс 18:00 — Еженедельный обзор

Каждая публикация будет приходить тебе на post-moderation за час до выхода.
```

### Step 10 — Persistence loop (если Шахруз не отвечает)

После Step 8 Mila ждёт. Если в течение 4 часов нет ответа Шахруза — повторный пинг:

```
🔔 Напоминаю — план $WEEK_MON ждёт твоего утверждения.
Файл: /workspace/group/wiki/projects/content-plan-$WEEK_MON.md
Что делаем — утверждаем, правим, или показать полностью?
```

Каскад reminder'ов:
- Sat 16:00 — первый напомнить (если первое предложение было в 12:00)
- Sat 20:00 — второй
- Sat 22:00 — третий
- Sun 09:00 — четвёртый («план не утверждён, неделя без плана начнётся с понедельника — поспеши»)
- Sun 13:00 — пятый («план срочно нужен, сейчас Mon-Wed без задач»)
- Mon 06:00 — escalate с сообщением «без плана дальше работаю на defaults — AI-дайджест каждый день, рубрики не запускаю»

После approval — петля останавливается.

## Implementation скиллa — основной поток

Скилл — это инструкция-алгоритм, не отдельный bash-скрипт. Mila сама исполняет шаги выше через свои tools (Read для pools, send_message для коммуникации, schedule_task для финального schedule).

Однако для cron-trigger'а нужна **scheduled task** созданная при первой настройке:

```python
# Один раз — Mila создаёт скиллу собственный cron при первой инициализации
mcp__nanoclaw__schedule_task(
  schedule_type="cron",
  schedule_value="0 12 * * 6",   # каждую субботу 12:00 Tashkent
  context_mode="group",
  prompt="Запусти channel-weekly-planner скилл — подготовь контент-план следующей недели. Полный алгоритм в /app/skills/channel-weekly-planner/SKILL.md. Если план уже утверждён — просто подтверди, ничего нового не делай.",
  series_id="channel-weekly-planner-saturday"
)
```

И отдельно — reminder cron'ы (одноразовые, Mila создаёт после первого предложения плана):

```python
# Reminder через 4ч если план не approved
mcp__nanoclaw__schedule_task(
  schedule_type="once",
  run_once_at="<saturday>T16:00:00+05:00",
  context_mode="group",
  prompt="Если контент-план для следующей недели ещё не approved — пнул Шахруза вторым reminder'ом."
)
# и так далее для 20:00, 22:00, Sun 09:00, Sun 13:00, Mon 06:00
```

## Failure modes

- **Pool пуст для какой-то рубрики** — Mila говорит Шахрузу «копилка персон/инструментов/скиллов пуста, добавь новых в `<file>`»
- **Все темы tier-1 events-pool опубликованы** — переходим на tier-2, или просим Шахруза предложить
- **Шахруз молчит >24ч после первого предложения** — Mila сама ставит план с **default** выборами (top-1 из каждой копилки), помечает `status: provisional-default`, отчитывается «работаю с дефолтами, можешь поправить когда вернёшься»

## Связь со скиллами

- `parallel-search` / `web_search` — research свежего контекста для персон
- `mcp__nanoclaw__schedule_task` — scheduled task creation
- `mcp__nanoclaw__send_message` — коммуникация с Шахрузом
- `wiki-contributor` — обновление pool-страниц со status'ами

## Что Mila НЕ делает в этом скилле

- ❌ Не сама создаёт контент по выбранным рубрикам — она его планирует. Создание идёт в день публикации соответствующим скиллом (`channel-persona-week`, `channel-tools-week`, и т.д.)
- ❌ Не публикует ничего сама — только планирует и schedules
- ❌ Не выбирает темы за Шахруза без его approval (кроме escalation в default-mode после 24ч)

## История изменений

- **2026-05-02** — создан скилл по запросу Шахруза («единый скилл — одна фраза»). Cron каждую субботу 12:00. Persistence loop через scheduled-task reminders.
