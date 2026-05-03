---
name: channel-persona-week
description: Prepare and publish the "Персона недели" rubric for @ashotonline. Reads candidates from `wiki/projects/channel/personas-pool.md`, picks based on Shakhruz approval (Saturday session), drafts the post, runs through humanizer-ru, publishes via telegram-publish with default scheduled +1h. Use on Saturdays for selection and on Wednesdays for publication.
---

# Channel Persona of the Week

Еженедельная рубрика про лидера AI-индустрии. Готовится **по субботам** (выбор из copilки), публикуется **в среду 10:00 Tashkent** через `telegram-publish` (с default scheduled +1h post-moderation).

## Когда вызывать

- **Суббота (selection mode)**: «приготовь персону недели на следующую неделю», «выбери кандидата для рубрики персона»
- **Среда (publish mode)**: «публикуй персону недели», «отправь пост про <Имя>» — если уже выбран

## Источник кандидатов

`/workspace/group/wiki/projects/channel/personas-pool.md` — копилка персон с status. Берём только `status: pool`. Tier-1 в первую очередь, потом tier-2, потом tier-3.

## Algorithm

### Saturday selection mode

1. Read pool, фильтруй `status: pool`. Сортируй по tier (tier-1 → tier-2 → tier-3) и алфавит.
2. Возьми top-3 кандидата.
3. Для каждого кандидата:
   - Прочитай wiki-page если уже есть (`wiki/people/<name>.md`)
   - Сделай свежий research через `parallel-search` или `web_search`: что они выпустили / сказали за последние 14 дней?
   - Если ничего интересного — снимаем с шорт-листа, берём следующего из pool
4. Send Шахрузу сообщение через `mcp__nanoclaw__send_message`:

```
🎯 *Персона недели на <неделя>*

Кандидаты из copilки (top non-published):

1. *<Name1>* — <one-line angle>. Свежий контекст: <recent>. Tier <N>.
2. *<Name2>* — ...
3. *<Name3>* — ...

Какого выбираешь? Напиши «1», «2» или «3», или скажи «другого» — предложу следующих.
```

5. После ответа Шахруза — обнови `personas-pool.md`: выбранному `status: scheduled-<date>`, остальным оставь `pool`.
6. Создай drafft в `/workspace/group/content/persona-<date>-<slug>.md` с готовой структурой (см. ниже) на основе данных. Сохрани источники.
7. Подтверди Шахрузу: «Драфт готов в `<path>`. Опубликуем в среду 10:00, я поставлю scheduled +1h в среду утром.»

### Wednesday publish mode

1. Read draft из `/workspace/group/content/persona-<date>-<slug>.md`
2. Run через `humanizer-ru` — обязательно
3. Generate preview-image — фото персоны (берём из public sources / Wikipedia / conference talk poster) или стилизованный портрет через `design-banner`
4. Сохрани в `/workspace/global/banners/persona-<date>-<slug>.jpg`
5. Publish через `telegram-publish`:
   ```bash
   bash /app/skills/telegram-publish/publish.sh post ashotonline \
     /workspace/group/content/persona-<date>-<slug>.md \
     /workspace/global/banners/persona-<date>-<slug>.jpg
   ```
6. Notify Шахрузу с scheduled_id и превью (как обычный publish flow)
7. После выхода (auto или по publish_now):
   - Обнови `personas-pool.md`: `status: published-<actual-date>`
   - Создай wiki source-page `wiki/sources/<date>-persona-<slug>.md` со ссылкой на t.me/ashotonline/<id>
   - Обнови `wiki/projects/channel/log.md`
   - Если у персоны нет wiki-page в `wiki/people/<name>.md` — создай через `wiki-contributor`

## Format поста

```
👤 *Персона недели — <Имя>*

<2-3 предложения: кто такой, чем известен, текущая роль>

*Почему за ним следить:* <1-2 предложения, конкретно под нашу аудиторию>

*Что почитать/посмотреть свежее:*
• <свежий material 1 со ссылкой>
• <свежий material 2>

<Опционально: цитата 1-2 предложения>

#ИИперсона #ЛидерыИИ #<имя_кириллицей>
```

Длина: 800-1500 символов. Без двойных звёздочек. Single * для bold, _ для italic.

## Anti-patterns

- ❌ Биография всю жизнь — берём только релевантное для аудитории
- ❌ Восхищение без анализа — предприниматели ценят bias-free взгляд
- ❌ Реклама их продуктов — мы про лидера, не про company
- ❌ Без свежего контента — если за 2 недели ничего не происходило, переходим к следующему кандидату

## Failure modes

- **Pool пуст** (все опубликованы) — прислать Шахрузу alert «копилка персон пуста, добавь новых в `personas-pool.md`»
- **Не получается найти свежий контент** — снимаем кандидата на эту неделю, берём следующего, оставляем в pool
- **Image generation падает** — публикуем без картинки (текстовый пост — тоже валидно)

## Связь с другими скиллами

- `parallel-search` / `web_search` — research свежего контекста
- `wiki-contributor` — ingest персоны в wiki/people/
- `humanizer-ru` — обязательный пасс перед публикацией
- `design-banner` — стилизованный портрет если фото не подходит
- `telegram-publish` — фактическая публикация
