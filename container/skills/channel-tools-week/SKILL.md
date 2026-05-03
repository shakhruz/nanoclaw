---
name: channel-tools-week
description: Prepare and publish the "Топ инструментов" rubric for @ashotonline. Reads candidates from `wiki/projects/channel/tools-pool.md`, picks based on Shakhruz approval (Saturday session), drafts the post focused on Mila's actual usage, runs through humanizer-ru, publishes via telegram-publish with default scheduled +1h. Use on Saturdays for selection and on Fridays for publication.
---

# Channel Tools of the Week

Еженедельная рубрика про AI-инструменты которые стек Шахруза реально использует. **Не реклама** — обзор-практика. Готовится **по субботам**, публикуется **в пятницу 11:00 Tashkent** через `telegram-publish`.

## Когда вызывать

- **Суббота (selection)**: «выбери инструмент недели», «приготовь tools-week»
- **Пятница (publish)**: «публикуй tools-week», «отправь пост про <инструмент>»

## Источник

`/workspace/group/wiki/projects/channel/tools-pool.md` — копилка с tier'ами и категориями. Берём `status: pool`.

## Algorithm

### Saturday selection mode

1. Read pool, отфильтруй `status: pool`.
2. Возьми 3 кандидата:
   - 1 из tier-1 (стек Шахруза — Octofunnel, Claude, NanoClaw, Zernio, Composio, Deepgram, Telotv)
   - 1 из tier-2 (популярные дополнения)
   - 1 из tier-3 (экспериментальные/специализированные)
3. Для каждого собери актуальные данные:
   - Use-case Шахруза/Mila — найди в conversations или по логам скиллов
   - Свежее изменение в продукте за последние 30 дней (changelog, новый релиз)
   - Цена сейчас (часто меняется)
4. Send Шахрузу:

```
🛠 *Инструмент недели на <неделя>*

Кандидаты:

1. *<Tool1>* (<category>, tier 1) — наш стек, use-case: <example>
2. *<Tool2>* (<category>, tier 2) — <one-line>
3. *<Tool3>* (<category>, tier 3) — <one-line>

Какой берём? «1», «2», «3» или «другой».
```

5. После ответа — обнови pool (`status: scheduled-<date>` выбранному).
6. Создай draft в `/workspace/group/content/tools-<date>-<slug>.md`.

### Friday publish mode

1. Read draft.
2. `humanizer-ru` пасс.
3. Image: скриншот интерфейса (можно взять с сайта инструмента — публичный) или баннер с логотипом через `design-banner`. Сохранить `/workspace/global/banners/tools-<date>-<slug>.jpg`.
4. Publish:
   ```bash
   bash /app/skills/telegram-publish/publish.sh post ashotonline \
     /workspace/group/content/tools-<date>-<slug>.md \
     /workspace/global/banners/tools-<date>-<slug>.jpg
   ```
5. Notify Шахруза с scheduled_id.
6. После публикации:
   - `status: published-<date>` в pool
   - Wiki source-page `wiki/sources/<date>-tools-<slug>.md`
   - Обновить `wiki/entities/<tool>.md` если есть, или создать через `wiki-contributor`
   - `log.md`

## Format поста

```
🛠 *<Tool name> — <category>*

<2-3 предложения: что делает, кому полезен>

*Как мы используем:* <конкретный use-case Шахруза/Mila — это самое важное>

*Цена:* <актуально на дату>
*Ссылка:* <url>

<Опционально: 1 совет/подсказка по использованию>

#ИИинструменты #<категория> #AshotAI
```

Длина: 600-1200 символов.

## Anti-patterns

- ❌ Маркетинговый pitch — мы не продаём, мы делимся реальным use-case
- ❌ Сравнения «X лучше Y» — провокационно и часто несправедливо
- ❌ Без use-case — если не используем, не пишем
- ❌ Скрин который генерит ошибку из-за nuance — лучше нейтральная страница продукта

## Failure modes

- **Tier-1 закончился** (все опубликованы) — переходим на ротацию tier-2/tier-3 или просим Шахруза дополнить pool
- **Цена изменилась с момента последнего поста** — всегда проверять перед публикацией
- **Use-case не подходит для public** (например, sensitive client info) — выбрать другой angle, не отказываться

## Связь со скиллами

- `wiki-contributor` — entities ingest
- `humanizer-ru` — обязательный пасс
- `design-banner` — баннер с логотипом если скриншот не подходит
- `telegram-publish` — публикация
