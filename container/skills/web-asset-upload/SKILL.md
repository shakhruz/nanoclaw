---
name: web-asset-upload
description: Publish a binary file (PNG, JPG, PDF, etc) from the container to milagpt.cc with a public URL. Use when the Дизайнер pool-agent (or any MILA worker) needs to SHOW an image/PDF to Шахруз or share it externally. Replaces the dead-end of "I've saved the file to /workspace/..." which Шахруз can't open. Returns a clickable https://milagpt.cc/<cat>/<slug>/<file> URL.
trigger: upload image | publish asset | выложи картинку | покажи PDF | share file | public URL for file
---

# web-asset-upload — публикация бинарных ассетов на milagpt.cc

Subagent в контейнере сохранил PNG/JPG/PDF — что дальше? Шахруз не видит `/workspace/global/...`. Этот скилл даёт публичный URL за ~30-60 секунд через GitHub Contents API + Vercel deploy.

## Когда использовать

- *Дизайнер* сгенерил hero-баннер / announce / PDF лид-магнит — хочет показать Шахрузу в чат → публикует → шлёт URL (плюс Telegram привью рендерит изображения и PDF'ы).
- *Копирайтер* / *Таргетолог* / *Методолог* подготовили один файл (например targeting.md экспортировал в PDF) и хотят публичную ссылку.
- *Main Мила* делает отчёт и хочет отдать Шахрузу не только текст, но и связанную картинку/файл.

Для *HTML-страниц* используй `web-publish`, не этот скилл. Для *клиентских документов с secret URL* — `web-client-doc`. Этот скилл — только бинарные ассеты, публичные URL, без секретов.

## URL-схема

```
https://milagpt.cc/<category>/<slug>/<filename>
```

Категории:
| Категория | Для чего | Пример URL |
|---|---|---|
| `w` | Workshop артефакты (визуал, PDF) | `/w/lichnyy-brend-2026-05-15/hero.png` |
| `campaigns` | Креативы рекламных кампаний | `/campaigns/ads-may-2026/banner-v1.jpg` |
| `assets` | Общие ассеты (логотипы, иконки, бренд) | `/assets/logo-dark.png` |
| `brand` | Брендбук-ассеты для партнёров | `/brand/ashotai-kit-v1.pdf` |

Все эти пути помечены `noindex` в репо-robots.txt (публичны, но не в поиске).

## Prerequisites

- *В контейнере MILA-группы:* `/workspace/group/config.json` с полями `github_token` + `vercel_token` (+scope, project). Уже скопировано в telegram_channel-promoter и telegram_octo.
- *На хосте (main):* `gh` + `vercel` CLI в PATH.

## Алгоритм

### Из контейнера (MILA-группа)

```bash
# Пример: Дизайнер публикует hero для воркшопа
/home/node/.claude/skills/web/publish-asset-api.sh \
  w lichnyy-brend-2026-05-15 \
  /workspace/global/workshops/lichnyy-brend-2026-05-15/design/kit/hero.png
```

Возвращает:
```json
{
  "url": "https://milagpt.cc/w/lichnyy-brend-2026-05-15/hero.png",
  "commit": "abc1234",
  "deployment": "https://milagpt-xxx.vercel.app",
  "path": "public/w/lichnyy-brend-2026-05-15/hero.png"
}
```

Опциональное 4-е имя файла (если хочешь переименовать при upload'е):
```bash
publish-asset-api.sh w lichnyy-brend-2026-05-15 /tmp/img.png hero-v1.png
```

### С хоста (main group или Claude Code sessions)

Тот же интерфейс, другой скрипт:
```bash
/home/node/.claude/skills/web/publish-asset.sh w lichnyy-brend-2026-05-15 /tmp/hero.png
```

## Пример workflow: Дизайнер в Mila octo после design-workshop-kit

```bash
# 1. Сгенерила артефакты через design-workshop-kit → файлы в /workspace/global/workshops/<slug>/design/
# 2. Публикует каждый:
SLUG="lichnyy-brend-2026-05-15"
WS="/workspace/global/workshops/$SLUG"
for f in hero.png announce-tg.png announce-ig.png leadmag-cover.png; do
  /home/node/.claude/skills/web/publish-asset-api.sh w "$SLUG" "$WS/design/$f" >> /tmp/published.jsonl
done

# 3. Также PDF лид-магнит:
/home/node/.claude/skills/web/publish-asset-api.sh w "$SLUG" "$WS/lead-magnets/checklist.pdf" >> /tmp/published.jsonl

# 4. Шлёт в чат список URL:
cat /tmp/published.jsonl | jq -r '.url' | \
  xargs -I{} echo "• {}" | \
  xargs mcp__nanoclaw__send_message
```

Или, по-человечески (через send_message с sender="Дизайнер"):

```
Готов визуал-пакет — вот ссылки:

• hero.png → https://milagpt.cc/w/lichnyy-brend-2026-05-15/hero.png
• announce-tg.png → https://milagpt.cc/w/lichnyy-brend-2026-05-15/announce-tg.png
• announce-ig.png → https://milagpt.cc/w/lichnyy-brend-2026-05-15/announce-ig.png
• leadmag-cover.png → https://milagpt.cc/w/lichnyy-brend-2026-05-15/leadmag-cover.png
• checklist.pdf → https://milagpt.cc/w/lichnyy-brend-2026-05-15/checklist.pdf

Telegram автоматически подтянет превью первого URL под сообщением.
```

## Latency и кеш

- GitHub commit: ~1 сек
- Vercel deploy: ~30-60 сек (первый запуск `npx vercel` дольше — скачивает CLI)
- После `curl -I <url>` возвращает `200` — готово
- Если нужно быстро (меньше 10 сек) — передай `NO_DEPLOY=1` в env, URL появится только после следующего pushа, но GitHub будет синхронизирован

## Повторная публикация (перезапись)

GitHub Contents API возвращает 409 при попытке создать существующий файл. Скрипт автоматически читает `sha` и делает `update` вместо `create`. Т.е. повторный вызов с тем же slug+filename *перезаписывает* файл без ошибки.

Если хочешь версионирование — меняй filename: `hero-v1.png`, `hero-v2.png`.

## Анти-паттерны

- ❌ Публиковать конфиденциальные файлы (персональные данные клиентов, внутренние доки) — `milagpt.cc` публичный, даже в `/w/*` URL можно угадать. Для конфиденциального — `web-client-doc` с secret URL.
- ❌ Публиковать оригиналы больших фото (>5MB) без оптимизации — забивает репо и замедляет deploy. Сжимай через `cjpeg`, `oxipng`, `pngquant` до ~1MB.
- ❌ Использовать категорию `assets/` для одноразовых файлов — эта папка для вечнозелёного бренда (лого, иконки). Воркшопы → `w/`, кампании → `campaigns/`.
- ❌ Переделывать URL после публикации — Telegram, email, клиенты могли уже его сохранить. Старый path с 404 = broken link.

## Troubleshooting

| Симптом | Причина | Фикс |
|---|---|---|
| `err: config.json not found` | У этой группы нет config.json с токенами | Скопируй из telegram_client-profiler |
| GitHub push 401 | github_token истёк или не даёт contents write | Перевыпустить через gh auth |
| Vercel deploy висит >2 мин | Сеть медленная / первый `npx vercel` | Подожди или передай `NO_DEPLOY=1`, potem GitHub webhook подхватит |
| URL возвращает 404 | Deploy ещё идёт | `sleep 30; curl -I <url>` снова |
| Файл не перезаписывается | Передал тот же filename с тем же контентом | Это нормально — скрипт скипает identical content (exit 1) |
