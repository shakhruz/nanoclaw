---
name: inline-buttons
description: >
  Инлайн-кнопки в Telegram сообщениях. Когда Мила предлагает варианты действий —
  вместо текстового списка отправляет сообщение с кнопками (InlineKeyboardMarkup).
  Нажатия кнопок приходят как `[Callback: <data>] on message <id>`.
trigger: кнопки | inline keyboard | кликнуть | варианты ответа | reply_markup
---

# Telegram Inline Buttons

Инлайн-кнопки ускоряют общение: вместо того чтобы печатать «да» или «в вики» — Шахруз просто нажимает кнопку.

**Bot API 9.4 (февраль 2026)** добавил нативные цвета кнопок через поле `style`. Используй его — кнопки получают реальный цвет Telegram без костылей с эмодзи.

---

## Часть 1 — Когда добавлять кнопки

### Автоматические триггеры (добавлять всегда)

| Ситуация | Пример |
|---|---|
| Вопрос с 2–4 вариантами | «Занести в wiki или оставить как разговор?» |
| Draft для подтверждения | Создать задачу / Отмена |
| Lint рекомендации | Выполнить пункт / Пропустить |
| Ingest с несколькими источниками | Начать с первого / Пропустить |
| Gmail черновик | Отправить / Редактировать / Удалить |
| Calendar событие draft | Создать / Изменить |

### Когда НЕ добавлять кнопки

- Информационные ответы без вариантов действий
- Длинные списки (>4 вариантов — лучше текст или нумерованный список)
- Технические ответы (коды, конфиги) — там незачем
- Ответы на вопросы типа «сколько время»

### Правило 4

**Максимум 4 кнопки в ряду, 4 ряда.** Больше — неудобно. Если вариантов больше — используй текст.

---

## Часть 2 — Цветовая схема (Bot API 9.4 native colors)

С Bot API 9.4 кнопки получают **реальный цвет в интерфейсе Telegram** через поле `style`.
Дополнительно добавляй emoji-префикс — он усиливает визуальный сигнал и работает как fallback на старых клиентах.

### Таблица стилей

| `style` | Цвет кнопки | Emoji | Смысл | Применение |
|---|---|---|---|---|
| `"success"` | 🟢 Зелёный | ✅ | Подтверждение | Создать, Да, Ок, Отправить, Ingest |
| `"danger"` | 🔴 Красный | ❌ | Отмена/удаление | Нет, Отмена, Удалить, Очистить |
| `"primary"` | 🔵 Синий | — | Основное действие | Главный CTA, нейтральный выбор |
| *(не задан)* | ⬜ Серый | ⏭ 🔄 ℹ️ ✍️ | Второстепенное | Пропустить, Детали, В вики, Позже |

### Правила выбора

- Каждый ряд должен иметь **не более одной** кнопки `"success"` и **не более одной** `"danger"`
- `"primary"` — когда одна кнопка явно главная, остальные второстепенные
- Без `style` (серые) — для нейтральных опций (пропустить, подробнее, позже)
- Emoji-префикс добавляй **всегда** — он несёт смысл даже там, где style не отображается

### Типовые комбинации

```
[✅ Создать  style:success]  [❌ Отмена  style:danger]
[✅ В вики  style:success]   [💬 Разговор  style:primary]  [⏭ Пропустить]
[✅ Отправить  style:success]  [✏️ Редактировать  style:primary]  [🗑 Удалить  style:danger]
[✅ Да  style:success]  [⏭ Позже]  [❌ Нет  style:danger]
```

### Emoji для серых кнопок (без style)

| Emoji | Смысл |
|---|---|
| ✍️ | Wiki/ingest/память |
| 💬 | Разговор/оставить |
| ℹ️ | Детали/подробнее |
| ⚠️ | Осторожно/важно |
| 🗑 | Удалить (когда danger избыточен) |
| ⏭ | Пропустить/следующий |
| 🔄 | Повторить/ещё раз |
| 📋 | Показать список |

---

## Часть 3 — Callback data схема

`callback_data` — строка до **64 байт**. Формат: `<action>:<payload>` (при необходимости).

```
yes                    — простое подтверждение
no                     — отмена
wiki:ingest            — ingest в wiki
chat:keep              — оставить как разговор
task:create            — создать задачу
task:skip              — пропустить задачу
lint:6                 — выполнить пункт 6 lint
gmail:send             — отправить письмо
gmail:edit             — редактировать черновик
calendar:create        — создать событие
```

### Как Мила получает нажатие

Когда Шахруз нажимает кнопку, Мила получает синтетическое сообщение:

```
[Callback: wiki:ingest] on message 11705
```

Формат: `[Callback: <data>] on message <original_message_id>`

Это аналог `[Reaction: X] on message Y` — та же синтетическая доставка через handler.

### Обязательное поведение при получении Callback

1. **Найти контекст** — по `original_message_id` понять, к какому действию относится нажатие
2. **Выполнить действие** согласно `data`
3. **Обновить сообщение или реагировать** — поставить `👏` на исходное сообщение (через `react_to_message`)
4. **Не просить подтверждение повторно** — кнопка уже является подтверждением

---

## Часть 4 — Как использовать MCP tool

После применения кода (Часть 5) появится инструмент `mcp__nanoclaw__send_message_with_buttons`.

### Сигнатура

```typescript
send_message_with_buttons({
  text: string,           // текст сообщения (Markdown поддерживается)
  buttons: Array<Array<{  // двумерный массив: строки × кнопки
    text: string,                              // текст кнопки (добавь emoji-префикс)
    data?: string,                             // callback_data (до 64 байт)
    url?: string,                              // URL для кнопки-ссылки (вместо data)
    style?: "success" | "danger" | "primary",  // Bot API 9.4 — нативный цвет
  }>>,
  sender?: string,        // роль-имя (как в send_message)
})
```

### Примеры вызовов

```javascript
// Выбор: wiki или разговор
send_message_with_buttons({
  text: "Занести в wiki или оставить как разговор?",
  buttons: [[
    { text: "✍️ В вики", data: "wiki:ingest", style: "success" },
    { text: "💬 Разговор", data: "chat:keep", style: "primary" }
  ]]
})

// Draft задачи в Todoist
send_message_with_buttons({
  text: "*Draft задачи:*\n• Позвонить Ивану\n• Завтра 14:00, Inbox, p4",
  buttons: [[
    { text: "✅ Создать", data: "task:create", style: "success" },
    { text: "❌ Отмена", data: "task:cancel", style: "danger" }
  ]]
})

// Lint рекомендации (несколько рядов)
send_message_with_buttons({
  text: "Выбери что выполнить из рекомендаций lint:",
  buttons: [
    [
      { text: "📁 MOC pages", data: "lint:moc" },
      { text: "📚 Second source", data: "lint:source" }
    ],
    [
      { text: "✅ Всё сразу", data: "lint:all", style: "success" },
      { text: "⏭ Позже", data: "lint:skip" }
    ]
  ]
})

// Gmail черновик (3 кнопки в ряд)
send_message_with_buttons({
  text: "*Черновик ответа Ивану:*\n\n«Привет! Подтверждаю встречу на 15:00.»",
  buttons: [[
    { text: "✅ Отправить", data: "gmail:send", style: "success" },
    { text: "✏️ Редактировать", data: "gmail:edit", style: "primary" },
    { text: "🗑 Удалить", data: "gmail:delete", style: "danger" }
  ]]
})
```

---

## Часть 5 — Установка (Code Changes)

**Статус:** ⏳ Требует применения в Claude Code сессии.

Изменить нужно 5 файлов в `src/` и `container/agent-runner/src/`.

---

### 1. `src/types.ts` — добавить InlineButton + метод в Channel

После `export interface TaskRunLog { ... }` и перед `// --- Channel abstraction ---` добавить:

```typescript
/**
 * A single button in an inline keyboard row.
 * Either `data` (callback) or `url` must be set.
 *
 * Bot API 9.4 (February 2026): `style` sets native button color in Telegram UI.
 * Always include an emoji prefix in `text` as well — it works on older clients.
 */
export interface InlineButton {
  /** Displayed label — always include an emoji prefix for visual meaning */
  text: string;
  /** Callback data (≤ 64 bytes). Delivered as `[Callback: <data>] on message <id>`. */
  data?: string;
  /** URL to open when button is tapped (alternative to callback). */
  url?: string;
  /**
   * Bot API 9.4 — native button color in Telegram.
   * "success" = green (confirm/yes/create)
   * "danger"  = red   (cancel/delete/no)
   * "primary" = blue  (main action, neutral primary choice)
   * Omit for default grey (secondary/skip/info buttons).
   */
  style?: 'success' | 'danger' | 'primary';
  /**
   * Bot API 9.4 — custom emoji icon shown before button text.
   * Use the emoji's custom_emoji_id from Telegram sticker set.
   * Optional enhancement; not required.
   */
  icon_custom_emoji_id?: string;
}
```

В интерфейсе `Channel` после `reactToMessage?` добавить:

```typescript
  // Optional: send a message with an inline keyboard. Callback presses are
  // delivered as synthetic `[Callback: <data>] on message <id>` messages.
  // See the inline-buttons skill doc for usage semantics and emoji color guide.
  sendMessageWithButtons?(
    jid: string,
    text: string,
    buttons: InlineButton[][],
  ): Promise<void>;
```

---

### 2. `src/channels/telegram.ts` — метод + callback_query handler

#### 2a. Добавить import InlineButton в начало файла

```typescript
import { InlineButton, Channel, OnChatMetadata, OnInboundMessage, RegisteredGroup } from '../types.js';
```

#### 2b. Добавить метод `sendMessageWithButtons` в класс TelegramChannel

После метода `reactToMessage(...)` добавить:

```typescript
  /**
   * Send a message with an inline keyboard. Callback presses are delivered as
   * synthetic `[Callback: <data>] on message <id>` messages via the
   * callback_query handler below.
   */
  async sendMessageWithButtons(
    jid: string,
    text: string,
    buttons: InlineButton[][],
  ): Promise<void> {
    if (!this.bot) {
      logger.warn('Telegram bot not initialized (sendMessageWithButtons)');
      return;
    }
    try {
      const numericId = jid.replace(/^tg:/, '');
      const inline_keyboard = buttons.map((row) =>
        row.map((btn) => {
          if (btn.url) {
            return { text: btn.text, url: btn.url };
          }
          // Bot API 9.4: style and icon_custom_emoji_id are not yet in grammy
          // types — pass as `unknown` to bypass type checking.
          const buttonObj: Record<string, unknown> = {
            text: btn.text,
            callback_data: btn.data ?? '',
          };
          if (btn.style) buttonObj.style = btn.style;
          if (btn.icon_custom_emoji_id) buttonObj.icon_custom_emoji_id = btn.icon_custom_emoji_id;
          return buttonObj;
        }),
      );
      await this.bot.api.sendMessage(numericId, text, {
        parse_mode: 'Markdown',
        reply_markup: { inline_keyboard } as never,
      });
      logger.info({ jid, rows: buttons.length }, 'Telegram message with buttons sent');
    } catch (err) {
      // Fallback: send as plain text without buttons
      logger.warn({ jid, err }, 'Failed to send Telegram message with buttons, falling back');
      try {
        const numericId = jid.replace(/^tg:/, '');
        const fallbackText =
          text +
          '\n\n' +
          buttons
            .flat()
            .filter((b) => b.data)
            .map((b) => `• ${b.text} → \`${b.data}\``)
            .join('\n');
        await this.bot.api.sendMessage(numericId, fallbackText);
      } catch (fallbackErr) {
        logger.error({ jid, fallbackErr }, 'Failed to send Telegram fallback message');
      }
    }
  }
```

#### 2c. Добавить callback_query handler в `connect()`, после `message_reaction` handler

```typescript
    // Inline button callback queries — see inline-buttons skill for usage.
    // Delivers button presses as synthetic `[Callback: <data>] on message <id>`
    // messages. Auto-answers the callback query immediately (removes loading
    // indicator) so the button tap feels instant.
    this.bot.on('callback_query:data', async (ctx) => {
      const chatJid = `tg:${ctx.chat?.id ?? ctx.callbackQuery.message?.chat.id}`;
      const group = this.opts.registeredGroups()[chatJid];
      if (!group) {
        await ctx.answerCallbackQuery().catch(() => {}); // answer even for unregistered
        return;
      }

      // Answer immediately to remove the loading spinner on the button
      await ctx.answerCallbackQuery().catch((err) => {
        logger.debug({ err }, 'Failed to answer callback query');
      });

      const data = ctx.callbackQuery.data ?? '';
      const origMsgId =
        ctx.callbackQuery.message?.message_id?.toString() ?? '';
      const timestamp = new Date().toISOString();
      const senderName =
        ctx.from?.first_name ||
        ctx.from?.username ||
        ctx.from?.id.toString() ||
        'Unknown';
      const sender = ctx.from?.id.toString() ?? '';

      const isGroup =
        ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';
      this.opts.onChatMetadata(
        chatJid,
        timestamp,
        undefined,
        'telegram',
        isGroup,
      );

      this.opts.onMessage(chatJid, {
        id: `callback-${ctx.callbackQuery.id}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
        chat_jid: chatJid,
        sender,
        sender_name: senderName,
        content: `[Callback: ${data}] on message ${origMsgId}`,
        timestamp,
        is_from_me: false,
      });

      logger.info(
        { chatJid, data, origMsgId, sender: senderName },
        'Telegram callback query delivered',
      );
    });
```

---

### 3. `src/ipc.ts` — добавить sendMessageWithButtons в IpcDeps + обработчик

#### 3a. Добавить в интерфейс IpcDeps

После `reactToMessage?` добавить:

```typescript
  // Optional: send a message with inline keyboard buttons. Only populated
  // when the connected channel implements Channel.sendMessageWithButtons.
  sendMessageWithButtons?: (
    jid: string,
    text: string,
    buttons: Array<Array<{
      text: string;
      data?: string;
      url?: string;
      style?: 'success' | 'danger' | 'primary'; // Bot API 9.4
      icon_custom_emoji_id?: string;             // Bot API 9.4
    }>>,
  ) => Promise<void>;
```

#### 3b. Добавить обработчик в `processIpcFiles`, после блока `type === 'react'`

```typescript
              } else if (
                data.type === 'message_with_buttons' &&
                data.chatJid &&
                data.text &&
                Array.isArray(data.buttons)
              ) {
                const targetGroup = registeredGroups[data.chatJid];
                const authorized =
                  isMain || (targetGroup && targetGroup.folder === sourceGroup);
                if (!authorized) {
                  logger.warn(
                    { chatJid: data.chatJid, sourceGroup },
                    'Unauthorized IPC message_with_buttons attempt blocked',
                  );
                } else if (!deps.sendMessageWithButtons) {
                  logger.warn(
                    { chatJid: data.chatJid, sourceGroup },
                    'IPC message_with_buttons dropped — channel does not support inline buttons',
                  );
                } else {
                  await deps.sendMessageWithButtons(
                    data.chatJid,
                    data.text,
                    data.buttons,
                  );
                  logger.info(
                    { chatJid: data.chatJid, sourceGroup, rows: data.buttons.length },
                    'IPC message with buttons sent',
                  );
                }
```

---

### 4. `container/agent-runner/src/ipc-mcp-stdio.ts` — добавить MCP tool

После инструмента `send_message` добавить новый tool:

```typescript
server.tool(
  'send_message_with_buttons',
  `Send a message with inline keyboard buttons. Buttons appear below the message text as tappable elements.

WHEN TO USE: whenever you present choices to the user — drafts (create/cancel), yes/no confirmations, 
multi-option decisions (wiki/chat/skip), recommendations (do/defer/ignore).

NATIVE COLORS (Bot API 9.4, February 2026) — use \`style\` field:
• style: "success" — GREEN button (confirm / create / yes / send / ingest)
• style: "danger"  — RED button   (cancel / delete / no / remove)
• style: "primary" — BLUE button  (main action, neutral primary choice)
• no style         — GREY button  (secondary / skip / details / later)

EMOJI PREFIX — always add an emoji too, it works on older clients and reinforces meaning:
• ✅ success  • ❌ danger  • ✍️ wiki  • 💬 chat  • ⏭ skip  • 🗑 delete  • ℹ️ info

BUTTON LIMITS: max 4 buttons per row, max 4 rows. More = cluttered.
MAX 1 "success" and 1 "danger" per row — don't stack same color.

CALLBACK DATA: ≤ 64 bytes. Use format \`<action>:<payload>\` when needed (e.g. "task:create", "lint:6").
Button taps arrive as synthetic messages: \`[Callback: <data>] on message <id>\`
Treat them like confirmed actions — no need to ask again.`,
  {
    text: z.string().describe('Message text (Markdown supported: *bold*, _italic_, `code`)'),
    buttons: z
      .array(
        z.array(
          z.object({
            text: z
              .string()
              .describe('Button label. Always include emoji prefix (✅ ❌ ✍️ etc.) AND set style for color.'),
            data: z
              .string()
              .max(64)
              .optional()
              .describe('Callback data (≤ 64 bytes). Use format "action:payload".'),
            url: z
              .string()
              .url()
              .optional()
              .describe('URL to open (alternative to callback data).'),
            style: z
              .enum(['success', 'danger', 'primary'])
              .optional()
              .describe('Bot API 9.4 native color: success=green, danger=red, primary=blue. Omit for default grey.'),
          }),
        ),
      )
      .describe('2D array of buttons: outer = rows, inner = buttons in each row. Max 4×4.'),
    sender: z
      .string()
      .optional()
      .describe('Your role/identity name (e.g. "Mila"). When set, messages appear from a dedicated bot in Telegram.'),
  },
  async (args) => {
    writeIpcFile(MESSAGES_DIR, {
      type: 'message_with_buttons',
      chatJid,
      text: args.text,
      buttons: args.buttons,
      sender: args.sender || undefined,
      groupFolder,
      timestamp: new Date().toISOString(),
    });

    return {
      content: [
        {
          type: 'text' as const,
          text: 'Message with buttons sent.',
        },
      ],
    };
  },
);
```

---

### 5. `src/index.ts` — подключить в startIpcWatcher

В вызове `startIpcWatcher({...})` после `reactToMessage: async (jid, ...) => {...}` добавить:

```typescript
    sendMessageWithButtons: async (jid, text, buttons) => {
      const channel = findChannel(channels, jid);
      if (!channel) {
        logger.warn({ jid }, 'sendMessageWithButtons: no channel owns JID');
        return;
      }
      if (!channel.sendMessageWithButtons) {
        logger.warn(
          { jid, channel: channel.name },
          'sendMessageWithButtons: channel does not support inline buttons, dropping',
        );
        return;
      }
      await channel.sendMessageWithButtons(jid, text, buttons);
    },
```

---

### Проверка после деплоя

1. В Telegram отправить Миле: «Тест кнопок»
2. Мила должна ответить сообщением с кнопками `[✅ Работает] [❌ Не работает]`
3. Нажать `✅ Работает`
4. Должно прийти: `[Callback: test:ok] on message <id>`
5. Мила поставит `👏` и ответит текстом «Кнопки работают ✅»

### Troubleshooting

- **Кнопки не появляются**: проверь что `sendMessageWithButtons` добавлен в `startIpcWatcher` в `index.ts`
- **Callback не приходит**: проверь что `callback_query` остаётся в `allowed_updates` в `bot.start()` (там уже был, но не потерять при мерже)
- **Markdown ошибка при отправке с кнопками**: fallback убирает кнопки но отправляет текст — если это происходит часто, проверь `parse_mode` vs специальные символы в тексте

---

## История изменений

| Дата | Что изменилось |
|------|---------------|
| 2026-04-12 | v1: Создан скилл-дизайн с emoji-only цветами. |
| 2026-04-12 | v2: Обновлён под Bot API 9.4 (февраль 2026) — нативные цвета кнопок через поле `style` ("success"/"danger"/"primary"). Добавлен `icon_custom_emoji_id`. Обновлены: Часть 2 (таблица стилей), Часть 4 (примеры с style), Часть 5 (InlineButton type, telegram.ts реализация, IpcDeps type, MCP tool schema). |
