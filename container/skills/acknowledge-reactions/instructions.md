## Acknowledge with reactions

### When you receive a user message

**Immediately react with 👀** to acknowledge that you've seen the message and started processing — *before* you do any tool calls or thinking out loud. This gives the user instant feedback ("она прочитала, работает").

```
mcp__nanoclaw__add_reaction({ messageId: <seq-of-incoming-message>, emoji: "👀" })
```

`messageId` is the numeric `seq` shown in the system view of the inbound message (the small `#NN` near the message). Read it from the inbound and pass as integer.

After processing, before sending the final reply, optionally swap the reaction:
- 👍 — done, success
- ✅ — task completed
- 🤔 — thinking / need more info (if you're going to ask a clarifying question)
- ❌ — could not do it

You can call `add_reaction` multiple times — the latest reaction replaces older one for that message.

### When the user reacts to YOUR message

Inbound `message_reaction` updates from Telegram tell you the user reacted to a message you previously sent. **Treat this as compact feedback:**

- 👍 / ✅ / ❤️ — user approves what you sent. No need to push further.
- 🔥 / 😍 — extra-positive, log a note in wiki/memory if relevant ("user loved this approach").
- 🤔 — user is unsure or wants discussion. Send a clarifying message proactively.
- ❌ / 💩 — user rejects. Do NOT continue the path you were on. Acknowledge ("понял, сворачиваю / меняю подход") and ask what they'd prefer.
- 👀 — user is looking, waiting. Don't take this as a directive.

Reactions don't always need a text reply — sometimes the right response is just to swap your own reaction (e.g., react ✅ back to confirm "got it"). Don't over-respond.

### When NOT to use reactions

- Don't react to your own outbound messages.
- Don't spam reactions — one per message lifecycle (👀 on receipt → ✅ on completion is a complete cycle).
- Don't use reactions as the primary mode of communication for substantive answers — substance goes in `<message>` blocks.

### Telegram-supported emoji set

Telegram only allows a fixed list of emoji as message reactions (the ones in the standard reaction menu). Common safe choices: 👀 ✅ 👍 👎 ❤️ 🔥 🤔 😢 😱 🎉 ⚡ ❌ 💩.
