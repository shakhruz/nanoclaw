# doc-proposal — КП (коммерческое предложение)

Создаёт мобильный HTML-документ с коммерческим предложением и публикует на `milagpt.cc/c/<client>/proposal-<title>-<secret>`.

## Когда использовать

Ашот говорит: «Сделай КП для X», «Подготовь коммерческое для Y», «Напиши оффер».

---

## Реквизиты исполнителя (всегда подставлять)

```
ИП Шарапова Елена Шарифовна
ИНН: 465572794 · ПИНФЛ: 41604723800014
Р/с: 20206 000 892390120 001
Банк: JSCB KAPITALBANK · МФО: 01158 · SWIFT: KACHUZ22
Представитель: Аширов Шахруз Шавкатович (доверенность)
Тел: +998 90 188 12 40 · Telegram: @shakhruz_ashirov · Email: shakhruz@gmail.com
```

---

## Продукты и цены

| Продукт | Цена | Состав |
|---|---|---|
| AI Personal | $800/мес | OctoFunnel + AI Business Club + 4 сессии × 2ч оффлайн + поддержка в личке |
| NanoClaw AI-ассистент | $100–200/мес | Кастомный агент на NanoClaw + Claude |
| OctoFunnel автоворонка | от $300 разово | Настройка + запуск автоворонки |
| AI-консультация | $20 | Разовая сессия |
| AI Base подписка | от $200/мес | Полный AI-пакет |

---

## Правила оформления

- Язык: **русский**
- Обращение: **«вы»** — никогда «ты»
- Стиль HTML: мобильный, dark theme, mint (#4ecdc4) акценты
- **Эталон:** `/workspace/group/clients/vladlen-ai-personal/index.html`
- НЕ писать «испытательный срок» → просто «срок»
- НЕ писать «разработка отдельно» → «запуск MVP»
- НЕ обещать конкретные даты → «месяц 1», «неделя 3»

### Print / PDF-ready (обязательно)

Каждый КП должен красиво печататься в PDF — клиент может отправить его партнёру или директору.

```css
@media print {
  @page { size: A4; margin: 18mm 15mm 18mm 15mm; }
  * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
  body { background: #fff !important; color: #1a1a2e !important; font-size: 11pt; padding: 0; }
  .sticky, .no-print { display: none !important; }
  /* Hero: dark bg → белый фон, текст — тёмный */
  .hero { background: #fff !important; border-bottom: 2pt solid #1a1a2e; }
  .hero h1, .hero .hero-sub, .hero .hero-for { color: #1a1a2e !important; }
  .hero-tag { background: #f0f0f0 !important; color: #1a1a2e !important; }
  /* Price-block: dark → light */
  .price-block { background: #f8fafc !important; border: 1.5pt solid #1a1a2e !important; color: #1a1a2e !important; }
  /* Break rules */
  .task-card, .roadmap-item, .price-block, .future-block { break-inside: avoid; }
  h2 { break-after: avoid; }
}
```

---

## Алгоритм

1. **Собери данные:** ниша клиента, задачи (до 4), оффер, цена, срок
2. **Напиши HTML** в `/workspace/group/clients/<client-slug>/index.html`
   (используй vladlen-ai-personal как базу стилей)
3. **Опубликуй:**
   ```bash
   node /tmp/vercel-deploy-api2.js
   # или:
   /home/node/.claude/skills/web/publish-client-doc-api.sh \
     <client-slug> proposal <title> <html-file> "<заметка>"
   ```
4. **Скопируй в черновики:**
   ```bash
   cp <html> /workspace/global/web-projects/client-docs/drafts/<client>/<YYYY-MM-DD>-proposal-<title>.html
   ```
5. **Отправь ссылку** Ашоту — секретный noindex URL

---

## HTML-структура

```
[hero]
  hero-tag: золотой бейдж — название пакета
  h1: оффер + <span>Имя / Компания</span> (mint)
  hero-sub: 1 предложение сути, обращение «вы»
  hero-for: "Подготовлено для: Имя Фамилия / Компания"

[section] Ваши задачи
  task-cards (1–4): номер, заголовок, описание, теги

[section] Стоимость
  price-block (тёмный): $XXX/мес, что входит (маркированный список)

[section] Роадмап
  8 недель → 4 этапа по 2 недели

[section] CTA
  Контакт Ашота: тел + Telegram + email
```
