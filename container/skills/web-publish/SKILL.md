---
name: web-publish
description: Publish an HTML page to https://milagpt.cc — reports, articles, client documents. Generates a public URL within ~60 seconds. Use whenever the user says "опубликуй", "запости на milagpt.cc", "сделай публичную ссылку для клиента", or provides a piece of HTML/analysis that should be shared as a public page.
version: 1.0.0
---

# web-publish — публикация на milagpt.cc

Готовая статическая страница кладётся в репо `milagpt-cc`, коммитится, и `vercel deploy --prod` публикует её на `https://milagpt.cc/<type>/<slug>`.

## Когда использовать

- Шахруз просит «выложи онлайн», «отправь клиенту ссылку», «сохрани в публикации».
- Результат работы — аналитика, отчёт, статья, пресс-релиз — требует постоянного URL.
- Нужно зашарить HTML-прототип / лендинг-черновик для обсуждения.

## Типы публикаций

| type | путь | назначение |
|---|---|---|
| `report` | `/reports/<slug>` | регулярные отчёты (CPR, telegram-ads-аналитика, KPI) |
| `article` | `/articles/<slug>` | статьи, разборы, заметки, мысли |
| `doc` | `/docs/<slug>` | документы для клиентов (КП, предложения, презентации в HTML) |
| `page` | `/<slug>` | обычная страница в корне (реже) |

## Алгоритм

1. **Подготовь HTML.** Полный валидный документ с `<!doctype html>`, `<meta viewport>`, `<title>`. Минималистичный CSS inline (без внешних CDN для офлайн-надёжности). Если есть картинки — сначала сохрани их в `/workspace/global/web-projects/assets-staging/` и впиши относительные пути.

2. **Придумай slug.** Формат: `YYYY-MM-DD-короткое-название`, kebab-case. Например: `2026-04-23-cpr-media-weekly`.

3. **Публикуй.** Положи HTML в файл, вызови helper:

   ```bash
   /home/node/.claude/skills/web/publish-html.sh <type> <slug> <path-to-html>
   ```

   Helper возвращает JSON:
   ```json
   {"url":"https://milagpt.cc/reports/2026-04-23-cpr-media-weekly","commit":"abc1234","deployment":"https://milagpt-xxx.vercel.app","push":true}
   ```

4. **Verify.** `curl -sSfI <url>` → `HTTP/2 200`. Если 404 — vercel-деплой ещё идёт, подожди 30 секунд.

5. **Сообщи пользователю.** Пришли финальный URL + что опубликовано. Markdown: `✅ Опубликовано: https://milagpt.cc/reports/<slug>`.

## Правила

- **Не публикуй чувствительное**: персональные данные клиентов, платёжные реквизиты, внутренние переписки. Репо `milagpt-cc` приватный, но сам сайт — публичный. Если сомневаешься — спроси.
- **Никаких inline-скриптов с секретами.** Аналитика (Plausible, Umami) — OK в отдельном теге в `<head>`.
- **Один slug = одна страница.** Повторная публикация с тем же slug перезапишет. Для версионирования используй `YYYY-MM-DD-slug-v2`.
- **Картинки** ≥200KB — обязательно оптимизируй (squoosh/sharp). Десятки нужных картинок — не в репо, а в S3/Cloudinary через отдельный шаг.

## Пример — публикация отчёта

```bash
cat > /tmp/cpr-weekly.html <<'EOF'
<!doctype html>
<html lang="ru"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CPR Media — Weekly 2026-04-23</title>
<style>body{font-family:-apple-system,system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 24px;line-height:1.55;color-scheme:light dark;}h1{letter-spacing:-.02em;}</style>
</head><body>
<h1>CPR Media — Weekly</h1>
<p>Сводка за 16–23 апреля 2026...</p>
</body></html>
EOF

/home/node/.claude/skills/web/publish-html.sh report 2026-04-23-cpr-weekly /tmp/cpr-weekly.html
```

Возвращает URL, шлёшь клиенту.

## Важно

- Скилл работает когда есть доступ к `~/apps/milagpt-cc/` и к `vercel` + `gh` CLI. В main-контейнере/на host-машине это есть. В MILA-контейнерах (channel-promoter и др.) — пока нет, это Phase 2.
- До подключения GitHub→Vercel OAuth-интеграции `vercel deploy --prod` обязателен (CLI-push). После — можно только `git push`, Vercel сам деплоит.
