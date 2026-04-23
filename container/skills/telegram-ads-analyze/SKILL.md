---
name: telegram-ads-analyze
description: Deep analysis of Telegram Ads performance — 7d/30d trends, winner/loser identification, CTR/CPM/CVR by targeting, UZ vs RU split, budget burn rate. Reads history snapshots from /workspace/global/telegram-ads/history/. Use for weekly reviews, optimization decisions, "что работает а что нет" questions.
---

# Telegram Ads — Deep Analysis

Trend analysis on top of `telegram-ads-view`. Reads dated snapshots from `/workspace/global/telegram-ads/history/YYYY-MM-DD.json` (written daily by the snapshot task) and computes:

- **Winner kampaнии** — наибольший CTR × impressions (не просто CTR)
- **Aутсайдеры** — активные кампании, >100 показов, CTR < 0.3% → паузу/редактирование
- **CTR тренд** — за 7 / 30 дней по каждой кампании
- **Языковой split** — UZ vs RU, какой канал даёт лучший CTR/CVR
- **Burn rate бюджета** — сколько TON в день в среднем, дней до 0
- **Targeting performance** — каналы vs боты vs search

## Trigger

- "проанализируй рекламу", "что работает в кампаниях", "тренды рекламы"
- "сравни UZ и RU кампании", "burn rate", "сколько осталось бюджета"
- Internal: вызывается еженедельным performance-report таском

## Algorithm

```bash
HELP=/home/node/.claude/skills/telegram-ads-session
. $HELP/common.sh

# 1. Подгрузка кеша + истории
TODAY=$(date +%Y-%m-%d)
HISTORY_DIR="$TG_ADS_HISTORY_DIR"

# 2. Найти доступные снапшоты за последние 7 / 30 дней
ls "$HISTORY_DIR"/*.json | tail -30
```

Затем — Node-скрипт парсит JSON каждого снапшота:

```js
// Псевдокод — реальная имплементация в bash + node one-liner или Python
const snaps = fs.readdirSync(HISTORY_DIR)
  .filter(f => f.endsWith('.json'))
  .sort()  // chronological
  .slice(-30);  // last 30 days

const byCampaign = {};
for (const f of snaps) {
  const date = f.replace('.json', '');
  const data = JSON.parse(fs.readFileSync(path.join(HISTORY_DIR, f)));
  for (const c of data.campaigns) {
    byCampaign[c.name] = byCampaign[c.name] || {snapshots: []};
    byCampaign[c.name].snapshots.push({date, ...c});
  }
}

// Для каждой кампании — посчитать deltas
for (const name in byCampaign) {
  const snaps = byCampaign[name].snapshots;
  const last = snaps.at(-1);
  const week_ago = snaps.find(s => /* 7 дней назад */);
  byCampaign[name].weekly_delta = {
    impressions: last.impressions - (week_ago?.impressions || 0),
    clicks: last.clicks - (week_ago?.clicks || 0),
    spent_ton: last.spent_ton - (week_ago?.spent_ton || 0),
  };
  byCampaign[name].avg_ctr_7d = /* ... */;
}
```

## Output format

```
📊 *Telegram Ads — Анализ за 7 дней*
_22 апреля → 15 апреля 2026_

*🏆 Победитель:*
"OctoFunnel — bepul tahlil"
CTR 1.2% | CVR 5% | CPA 0.45 TON
+580 показов, +3 клика, +1 действие за неделю
→ масштабировать: x2 бюджет, добавить 2 канала

*⚠️ Аутсайдеры:*
"Реклама A" — 1200 показов, 2 клика, CTR 0.17% за 7д
→ пауза или новый текст

"Реклама B" — declined, висит 5 дней
→ переписать без слов "free" / "доход"

*🔥 Burn rate:*
0.8 TON/день в среднем за неделю
Текущий баланс: 12.34 TON → хватит на 15 дней
Пополнение требуется к: 7 мая 2026

*🌐 UZ vs RU:*
UZ кампании: средний CTR 0.85%, средний CVR 4%
RU кампании: средний CTR 0.42%, средний CVR 2%
→ UZ работает в 2x лучше — больше UZ креативов

*🎯 Targeting:*
Каналы: 0.7% CTR (5 кампаний)
Боты:   0.45% CTR (2 кампании)
Search: 1.1% CTR (1 кампания) ⭐ — попробовать ещё

*💡 Топ-3 действия для роста:*
1. Удвоить бюджет "OctoFunnel — bepul tahlil" (победитель + UZ + bot search)
2. Запустить ещё 2 search-targeting кампании (лучший CTR)
3. Переписать declined "Реклама B" с новым подходом
```

## Critical rules

- **Нет данных = нет анализа.** Если в `history/` < 3 снапшотов — отвечай "Истории мало (N снапшотов), нужно подождать ещё несколько дней". НЕ выдумывай тренды.
- **Прочитай cache.json перед history** — убедись что текущее состояние известно.
- **Цифры должны быть точными.** Никаких округлений типа "примерно 1000 показов" — если в JSON 1024, пиши 1024.
- **Рекомендации — actionable.** Не "улучши CTR" а "удвой бюджет кампании X" с конкретным аргументом.

## Heuristics

| Сигнал | Что значит | Действие |
|---|---|---|
| CTR > 1% при >500 показов | Сильная кампания | Масштабировать (x2 бюджет) |
| CTR < 0.3% при >200 показов | Слабая кампания | Пауза или переписать |
| CVR > 20% | Качественный лид-магнит | Не трогать оффер |
| CPA < 0.5 TON | Эффективная воронка | Привлекать больше трафика |
| Burn rate × дней < баланс / 2 | Скоро деньги кончатся | Предупредить о пополнении |
| UZ > RU по CTR | Локальный рынок откликается | Сместить bias на UZ |

## When NOT to use

- Свежие цифры (сегодня) → `telegram-ads-view`
- Создать/изменить кампанию → `telegram-ads-manager`
- Сгенерировать новый креатив → `telegram-ads-generator`
- Найти новые каналы → `telegram-ads-research`

## Available to

main + 4 MILA worker groups. NOT public, NOT ashotai-experts.

## History

| Дата | Изменения |
|---|---|
| 2026-04-22 | Создан. Зависит от daily snapshot task (создан тогда же). История накапливается с этой даты. |
