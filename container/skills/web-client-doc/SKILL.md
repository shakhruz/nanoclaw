---
name: web-client-doc
description: Publish a client-facing document (proposal, contract, invoice) at a secret URL on milagpt.cc — noindex, unguessable, but with a human-readable path. Use when the user says "сделай КП для X", "опубликуй договор", "пришли ссылку клиенту", "подготовь коммерческое предложение". Primary user — telegram_client-profiler group.
version: 1.0.0
---

# web-client-doc — публикация клиентских документов с секретным URL

Коммерческие предложения (КП), договоры, инвойсы и клиентские материалы публикуются на `milagpt.cc/c/<client>/<doc>-<title>-<secret>` — URL не индексируется и защищён 7-значным секретом.

## URL-схема

```
https://milagpt.cc/c/<client-slug>/<doc-type>-<title>-<secret>
```

- `client-slug` — kebab-case имя клиента (`acme-corp`, `solidrealty`, `novatel`)
- `doc-type` — `proposal` | `contract` | `invoice` | `doc`
- `title` — kebab-case краткое описание (`ai-director`, `consulting-q2`, `march-2026`)
- `secret` — 7 символов base32 без неоднозначных (`0`, `1`, `l`, `i`, `o`) → ~35 млрд комбинаций

**Пример:** `https://milagpt.cc/c/acme-corp/proposal-ai-director-a7f3k9m`

Клиент видит `acme-corp / proposal-ai-director` и понимает, что это его КП. Секрет делает URL невычислимым.

## Защита от индексации (4 слоя)

1. `robots.txt` → `Disallow: /c/`
2. Vercel-хедер `/c/*` → `X-Robots-Tag: noindex, nofollow, noarchive, nosnippet`
3. В каждом HTML `<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">` (инжектируется автоматически, если забыл)
4. Нет directory listing: `/c/<client>/` без index.html → 404.

## Когда использовать

- Шахруз: «Сделай КП для ACME», «Опубликуй договор для NovaTel», «Отправь клиенту ссылку».
- `telegram_client-profiler`: после профилирования клиента готовишь документ — шлёшь через этот skill.
- Любой MILA-скилл, который **написал** клиентский материал — не отдавай тексты в открытые каналы, опубликуй сначала через этот skill.

## Режим работы по группам

### Main (ты — main-agent или Шахруз в main-чате)

Прямая публикация:

1. **Подготовь HTML.** Полный документ: `<!doctype html>`, `<meta viewport>`, `<title>`, inline CSS. Хороший КП обычно включает: hero-блок с названием клиента, суть предложения, объём работ, сроки, цена, условия, подпись/контакт.

2. **Собери параметры**:
   - `client-slug` (kebab-case)
   - `doc-type` (proposal/contract/invoice/doc)
   - `title` (kebab-case, короткий)
   - путь к HTML-файлу
   - (опц.) note — внутренний комментарий

3. **Опубликуй**:
   ```bash
   /home/node/.claude/skills/web/publish-client-doc.sh \
     acme-corp proposal ai-director /tmp/kp-acme.html \
     "первичное КП после звонка 2026-04-22"
   ```

4. Helper возвращает JSON с `url`, `secret`, запись в ledger (`/workspace/global/web-projects/client-docs/ledger.jsonl`).

5. **Пришли URL пользователю для пересылки клиенту.** Отдельно напомни: «Ссылка приватная, не публиковать в открытых каналах — секрет в URL защищает от перебора, но если URL утечёт в индекс поисковиков — найдут все».

### MILA-группа (client-profiler и др.)

Прямая публикация недоступна (в контейнере нет gh+vercel). **Режим предложения**:

1. Напиши черновик HTML в `/workspace/global/web-projects/client-docs/drafts/<client>/<YYYY-MM-DD-HHmm>-<doc>-<title>.html`.

2. Рядом положи метаданные `<same-basename>.meta.json`:
   ```json
   {
     "client_slug": "acme-corp",
     "doc_type": "proposal",
     "title": "ai-director",
     "note": "после звонка 22.04, акцент на AI-transformation",
     "requested_by": "client-profiler",
     "requested_at": "2026-04-23T15:30:00Z"
   }
   ```

3. Пришли в main через `mcp__nanoclaw__send_message`:
   ```
   📄 *Черновик клиентского документа*
   Клиент: acme-corp
   Тип: proposal (КП)
   Заголовок: ai-director
   Файл: /workspace/global/web-projects/client-docs/drafts/acme-corp/2026-04-23-1530-proposal-ai-director.html

   Опубликовать? (размер ~12KB, preview в черновике)
   ```

4. Main одобряет → запускает `publish-client-doc.sh` с этим файлом → присылает ссылку обратно.

## Ledger — реестр опубликованных

`/workspace/global/web-projects/client-docs/ledger.jsonl` — по одной JSON-записи на строку. **Видят все MILA-группы** (для контекста «что уже отправляли»).

Формат записи:
```json
{"published_at":"2026-04-23T03:30:00Z","client_slug":"acme-corp","doc_type":"proposal","title":"ai-director","secret":"a7f3k9m","url":"https://milagpt.cc/c/acme-corp/proposal-ai-director-a7f3k9m","commit":"9b3ceb4","published_by":"telegram_main","note":"первичное КП"}
```

Перед публикацией нового документа для клиента — **прочитай ledger** (`jq -c 'select(.client_slug=="acme-corp")' ledger.jsonl`). Если похожий документ уже отправляли неделю назад — уточни у Шахруза, точно ли новый (а не дубликат).

## HTML-шаблон для КП (опорный пример)

```html
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>КП — [Клиент] · MILA GPT</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; max-width: 720px; margin: 48px auto; padding: 0 24px; line-height: 1.6; color: #1a1a1a; color-scheme: light dark; }
  .hero { padding: 32px 0; border-bottom: 1px solid #e6e6ea; }
  h1 { font-size: 32px; letter-spacing: -0.02em; margin: 0; }
  h2 { font-size: 22px; margin-top: 40px; }
  .meta { color: #6a6a70; font-size: 14px; }
  .price { font-size: 28px; font-weight: 600; padding: 16px 20px; background: rgba(127,127,127,.08); border-radius: 12px; display: inline-block; }
  .scope li { margin-bottom: 8px; }
  .sig { margin-top: 56px; padding-top: 24px; border-top: 1px solid #e6e6ea; }
  @media (prefers-color-scheme: dark) { body { background: #0b0b0c; color: #e8e8e8; } .hero, .sig { border-color: #26262a; } }
</style>
</head>
<body>
<section class="hero">
  <p class="meta">Коммерческое предложение · [Дата]</p>
  <h1>[Клиент] · [Кратко суть]</h1>
</section>

<h2>Что предлагаем</h2>
<p>...</p>

<h2>Объём работ</h2>
<ul class="scope">
  <li>...</li>
</ul>

<h2>Сроки</h2>
<p>...</p>

<h2>Стоимость</h2>
<div class="price">$X,XXX</div>

<h2>Условия</h2>
<p>...</p>

<section class="sig">
  <p><strong>Шахруз Аширов</strong><br>MILA GPT · <a href="https://ashotai.com">ashotai.com</a><br>shakhruz@gmail.com</p>
</section>
</body>
</html>
```

## Правила

- **Ни в КП, ни в договор не вставляй секреты** (API-ключи, пароли, токены) — документ публичен по URL, кто угодно может открыть по ссылке.
- **Один клиент — один slug.** Не смешивай `acme` и `acme-corp`. Сверься с ledger до публикации.
- **При замене версии** — не перезаписывай существующую, публикуй как `<title>-v2`, `<title>-v3`. Старая ссылка остаётся у клиента.
- **Не публикуй чужие контракты** (solidrealty и другие клиенты) без явного одобрения Шахруза.
- **Ссылка утекла** (клиент случайно запостил в Telegram-канале) → **не волнуйся сразу**, но флагни Шахрузу: «URL мог утечь, перевыпустить?». Перевыпуск = публикация нового документа с новым секретом.

## Verify

- `curl -sSI <url>` → `HTTP/2 200` + хедер `X-Robots-Tag: noindex, nofollow`.
- `curl -sS https://milagpt.cc/c/<client>/` → должно вернуть 404 (не листинг).
- `curl -sS https://milagpt.cc/robots.txt | grep -i "disallow: /c/"` → есть.

## Ссылки

- Helper: `container/skills/web/publish-client-doc.sh`
- Ledger: `/workspace/global/web-projects/client-docs/ledger.jsonl`
- Drafts (для MILA): `/workspace/global/web-projects/client-docs/drafts/<client>/`
- См. также `/web-publish` (публичные страницы), `/web-inventory`.
