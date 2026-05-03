---
name: channel-trend-week
description: Saturday afternoon deep-dive into ONE recurring AI trend from the past 5 weekday digests. Reads `wiki/projects/channel/log.md` + source-pages, identifies the most-repeated meaningful theme, writes 1500-2000 char analytical post (not digest, not summary), publishes via telegram-publish at ~13:00 Tashkent with default scheduled +1h. Differs from `channel-weekly-summary`: that one recaps posts, this one analyzes ONE trend deeply.
---

# Channel Trend of the Week

Субботняя глубокая рубрика. Mila смотрит на собственный недельный поток AI-дайджестов (Пн-Пт), находит **ОДНУ сквозную тему** которая повторялась несколько раз и развивалась — и пишет аналитический разбор: что происходит, почему это сдвиг, что предпринимателю с этим делать.

## Когда вызывать

- **Сб ~12:00 Tashkent** (cron) — Mila готовит и отправляет на post-moderation, выходит в 13:00
- По команде: «сделай тренд недели», «опубликуй trend-week»

## Источники

1. `/workspace/group/wiki/projects/channel/log.md` — фильтр по последним 5 дням (Пн-Пт текущей недели)
2. `/workspace/global/wiki/sources/<date>-*.md` — глубокие версии каждого поста
3. **Опционально**: `mcp__nanoclaw__schedule_task` history / `parallel-search` для свежего контекста по тренду

## Algorithm

### 1. Identify trend (не «вытаскивай произвольное», а реально ищи паттерн)

Прочитай за неделю все AI-дайджесты:
- Какая компания упоминалась 3+ раз (developing story)?
- Какая категория из «Models / Companies / Products / People / Trends / Relevant for us» доминировала?
- Был ли явный thread (например, всю неделю что-то про регуляцию AI, про raises, про новые модели)?

**Heuristic для выбора тренда:**
- Тема упоминается ≥3 раза в дайджестах недели — кандидат
- Тема **развивалась** (не статичная) — есть progression от начала к концу недели
- Тема **значима** для нашей аудитории (предприниматели с AI) — не academic-only
- Если несколько кандидатов — выбираем самый коммерчески релевантный

**Если нет явного тренда** (редкая, тихая неделя) — выбираем самую интересную из категории `Trends` в текущем digest weekly summary, либо переключаемся на формат «What I'm watching this week» — мини-обзор 2-3 sub-themes.

### 2. Collect material

Для выбранного тренда:
- Все упоминания в недельных дайджестах (с датами)
- Source-pages с ключевыми ссылками
- Опционально parallel-search — что упустили из EN-source за неделю
- Цитаты ключевых игроков, цифры, конкретика

### 3. Draft

Структура:

```
🔍 *Тренд недели: <короткое название>*

<Сетап — 1-2 предложения, что произошло за неделю>

*Что мы видели:*
• <Дата>: <что случилось> ([source]({url}))
• <Дата>: <что случилось>
• <Дата>: <что случилось>

*Почему это сдвиг:*
<2-3 предложения — что меняется фундаментально, не просто новость>

*Что это значит для предпринимателя:*
• <конкретный вывод 1>
• <конкретный вывод 2>

*Что смотреть дальше на следующей неделе:*
<1-2 предложения — конкретный prediction или signal который ждать>

#Тренд #AIнеделя #<тема>
```

Длина: 1500-2000 символов.

### 4. Humanizer + image

- `humanizer-ru` пасс
- Image: концептуальный визуал (не скриншот) через `design-banner` — например, диаграмма развития темы за неделю, или абстрактный визуальный символ. Опционально, если получается за разумное время.

### 5. Publish

```bash
bash /app/skills/telegram-publish/publish.sh post ashotonline \
  /workspace/group/content/trend-<YYYY-Www>.md \
  /workspace/global/banners/trend-<YYYY-Www>.jpg
```

(image_path можно не передавать — текстовый пост валиден)

### 6. Notify Шахрузу

```
🔍 Поставила «Тренд недели» в @ashotonline на 13:00 (через ~1 час).
scheduled_id: NNN

Тема: <Название тренда>

Превью (первые 200 символов):
[превью]

Команды как обычно: «опубликуй сейчас» / «передвинь» / «замени X на Y» / «удали».
```

### 7. После публикации

- Обновить `log.md`
- Создать `wiki/sources/<date>-trend-<slug>.md` — это становится cornerstone-source для будущих weekly-summary'ев и контекстной памяти

## Format anti-patterns

- ❌ Это **не digest** — никаких «вот 5 новостей». Это анализ ОДНОЙ темы.
- ❌ **Не summary** — `channel-weekly-summary` (Вс) это делает. Не пересказываем посты, а выделяем сквозную тему.
- ❌ Без конкретики — «AI развивается» это не trend, это truism. Нужны цифры, имена, события.
- ❌ Без actionable вывода — «that's interesting» не помогает предпринимателю. Что **делать** с этим знанием?

## Failure modes

- **Реально нет тренда** (редкая неделя) — fallback на «What I'm watching»
- **Слишком много трендов** — выбираем один, остальные mention'им в weekly-summary в воскресенье
- **Тренд слишком технический** — переключаем angle на «что это значит для нашей аудитории»

## Связь со скиллами

- `humanizer-ru` — обязательный пасс
- `design-banner` — концептуальный visual (опционально)
- `parallel-search` — добавить EN-context если в наших дайджестах не хватало
- `wiki-contributor` — ingest как cornerstone-source
- `telegram-publish`

## Соотношение с другими рубриками

| Рубрика | Когда | Формат | Источник |
|---|---|---|---|
| AI-дайджест | Пн-Сб утро | 5-7 новостей с короткими комментариями | NEWS-папка + EN-web |
| **Тренд недели** | Сб день | Один тренд глубоко с actionable выводом | log + sources за прошедшие 5 дней |
| Еженедельный обзор | Вс вечер | Recap всех постов недели + main trend mention | log + sources за всю неделю |

«Тренд недели» — это **углубление**, в Sunday's обзор он становится 1-2 строчкой со ссылкой.
