---
name: channel-weekly-summary
description: Sunday wrap-up post for @ashotonline summarizing all publications of the past week. Reads from `wiki/projects/channel/log.md` + wiki/sources/ for the week's posts, formats a concise digest, publishes via telegram-publish with default scheduled +1h. Run every Sunday around 17:00 Tashkent so the post lands at 18:00.
---

# Channel Weekly Summary

Воскресный wrap-up для подписчиков @ashotonline. Идея — подписчик мог пропустить часть недели, мы даём ему один пост со всеми важными темами. **Не pure repost** — синтез + что важно запомнить.

## Когда вызывать

- **Воскресенье 17:00 Tashkent** (cron) — autopilot
- По команде: «опубликуй воскресный обзор», «weekly-summary»

## Источники

1. `/workspace/group/wiki/projects/channel/log.md` — все публикации недели (последние 7 дней)
2. `/workspace/global/wiki/sources/` — source-pages по каждой публикации (для глубины)
3. Посты в @ashotonline за неделю — для verification и ссылок (через `mcp__telegram-scanner__get_messages` если доступно, иначе через `log.md` ссылки)

## Algorithm

1. Read `log.md`, фильтр по дате — последние 7 дней.
2. Сгруппируй по типам:
   - AI-дайджесты (4 шт)
   - Персона (1)
   - Скиллы (1)
   - Tools (1)
3. Для каждой публикации возьми:
   - Дата + t.me ссылка
   - 1 главную идею (читай wiki source если нужно)
4. Найди **главные тренды недели** — что больше всего повторялось / двигалось / Шахрузу понравилось (опционально: посмотри reactions/views если уже подгружены)
5. Make draft в `/workspace/group/content/weekly-<YYYY-Www>.md`
6. `humanizer-ru` пасс
7. Publish:
   ```bash
   bash /app/skills/telegram-publish/publish.sh post ashotonline \
     /workspace/group/content/weekly-<YYYY-Www>.md
   ```
   (без картинки обычно — это текстовый рекап)
8. Notify Шахруза, ждём команды.
9. После выхода — обновить `log.md` (записать сам weekly-summary как публикацию).

## Format поста

```
🌙 *Неделя в @ashotonline — <DD-DD month>*

<2-3 предложения вступление, что неделя принесла>

*Главные новости AI ({N} дайджестов):*
• <крутая новость 1> → [подробнее]({date}-link)
• <2>
• <3>

*Персона недели:* <Name> — [пост]({link})
<1 предложение почему запомнили>

*Инструмент недели:* <Tool> — [пост]({link})
<1 предложение про use-case>

*Скилл недели:* <Recipe> — [пост]({link})
<1 предложение что даёт>

*Главный тренд:* <observation 1-2 предложения>

— — —
Если читаешь впервые — подпишись, в @ashotonline ежедневно AI-новости и еженедельно практические рубрики.

#ЕженедельныйОбзор #AIнеделя
```

Длина: 1000-1800 символов.

## Anti-patterns

- ❌ Просто пересказ всех постов — это была бы дублирование, а не синтез
- ❌ Без ссылок — люди должны иметь возможность вернуться к интересному
- ❌ Хайп-итоги «AI меняет мир!» — спокойный, conversational тон
- ❌ Слишком детально про каждый пост — overview, не digest of digests

## Failure modes

- **log.md не обновлялся за неделю** (Mila забывала записывать) — нужно reconstruct из самого канала через scanner. Потом обновить `log.md` ретроспективно.
- **Меньше 5 публикаций за неделю** — это аномалия (что-то ломалось), пишем короче, не растягиваем

## Связь со скиллами

- `wiki-contributor` — для чтения source-pages
- `mcp__telegram-scanner__get_messages` (или `bash $SKILL/publish.sh metrics`) — verification что ссылки актуальны
- `humanizer-ru`
- `telegram-publish`

## Cron / scheduled task

Mila создаёт scheduled-task через `mcp__nanoclaw__schedule_task` при первой настройке:

```
schedule_type: cron
schedule_value: "0 17 * * 0"   # каждое воскресенье 17:00 Ташкент (UTC+5 → cron в local)
context_mode: group
prompt: |
  Запусти channel-weekly-summary скилл.
  Сделай воскресный обзор всех публикаций @ashotonline за прошлую неделю.
  Опубликуй через telegram-publish с default scheduled +1h (post-moderation).
  После этого Шахруз подтвердит — выйдет в 18:00.
```
