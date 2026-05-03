---
name: channel-skills-week
description: Prepare and publish the "Скиллы и промпты" rubric for @ashotonline. Reads ready-to-copy prompt recipes from `wiki/projects/channel/skills-prompts-pool.md`, picks based on Shakhruz approval (Saturday session), publishes via telegram-publish with default scheduled +1h. Use on Saturdays for selection and on Thursdays for publication.
---

# Channel Skills & Prompts of the Week

Еженедельная рубрика «вот промпт, бери и используй». Готовые рецепты с примерами output. Готовится **по субботам**, публикуется **в четверг 11:00 Tashkent**.

## Когда вызывать

- **Суббота (selection)**: «выбери скилл недели», «что публикуем по теме промптов на четверг»
- **Четверг (publish)**: «публикуй skills-week»

## Источник

`/workspace/group/wiki/projects/channel/skills-prompts-pool.md` — копилка готовых промптов с категориями. Каждый со статусом.

## Algorithm

### Saturday selection mode

1. Read pool, фильтр `status: pool`.
2. Возьми 3 кандидата по разным категориям (sales / content / research / dev / analytics / personal-productivity / lead-gen) — стараемся не повторять категорию подряд.
3. Send Шахрузу:

```
🧠 *Скилл недели на <неделя>*

Кандидаты:

1. *<Recipe1>* (#<category>, <простой/средний/продвинутый>) — задача: <one-line>
2. *<Recipe2>* (#<category>) — ...
3. *<Recipe3>* (#<category>) — ...

Какой берём? «1», «2», «3» или «другой».
```

4. После ответа — `status: scheduled-<date>` выбранному.
5. Создай draft `/workspace/group/content/skills-<date>-<slug>.md`. Если у промпта нет actual-output примера — сначала прогони его сама (с placeholder values) и добавь в draft.

### Thursday publish mode

1. Read draft.
2. `humanizer-ru` пасс — но **аккуратно**: не сглаживать сам код-блок промпта, только обвес-текст.
3. Image: опционально (скриншот результата применения промпта или nothing). Если нечего — без image, текстовый пост валиден.
4. Publish:
   ```bash
   bash /app/skills/telegram-publish/publish.sh post ashotonline \
     /workspace/group/content/skills-<date>-<slug>.md \
     [image_path?]
   ```
5. Notify Шахруза.
6. После публикации:
   - `status: published-<date>` в pool
   - Wiki source-page

## Format поста

```
🧠 *<Название>*

<1-2 предложения: задача, для кого>

*Готовый промпт:*
```
<copy-paste промпт с placeholder-ами в `<UPPERCASE>`>
```

*Что получится:* <1-2 предложения про output>

*Адаптация:* <1-2 строки про переменные>

#СкиллыИИ #промпты #<категория>
```

Длина: 800-1500 символов. **Code-block через тройной backtick — Telegram делает monospace.**

⚠️ Внутри code-block — никаких звёздочек/markdown, чистый текст. Иначе Telegram ломает формат.

## Anti-patterns

- ❌ Промпт «напиши хорошо про мой бизнес» — слишком общий, нечему учиться
- ❌ Без примера output — людям нужно увидеть «вот так получится»
- ❌ Слишком сложно для tier-1 категории — простые рецепты идут в простой категории
- ❌ Менять/«улучшать» сам промпт силами humanizer-ru — это испортит работающий рецепт

## Failure modes

- **Pool пуст** — alert Шахрузу
- **Нет example output** — Mila прогоняет промпт сама с placeholder-данными перед публикацией
- **Промпт не работает на актуальной модели** — переписать или снять с публикации

## Связь со скиллами

- `humanizer-ru` — пасс по обвес-тексту (НЕ по code-block)
- `telegram-publish`
- `wiki-contributor` — ingest рецепта в `wiki/skills/<slug>.md` для будущего повторного использования
