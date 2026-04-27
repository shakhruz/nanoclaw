---
name: voice-message
description: Generate Telegram-ready voice notes (OGG/Opus mono) in the user's cloned voice. High-level workflow over elevenlabs-tts that picks the right model, format, and voice settings for short conversational audio. Triggers on "сделай голосовое", "запиши голосовуху", "ответ голосом", "voice this", "voice note", "send as voice".
---

# Voice Message — голосовые сообщения

Превращает текст в Telegram-голосовуху голосом Шахруза. Высокоуровневый wrapper над `elevenlabs-tts` + ffmpeg, оптимизированный под короткие (10–60 сек) разговорные сообщения.

## When to invoke

- «сделай голосовое», «запиши голосовуху», «отправь голосом», «voice this»
- ответ от MILA-командаа, который должен звучать живо (поддержка клиента, прогрев, follow-up)
- ситуации, где текстовый ответ слабее голосового (эмпатия, сложное объяснение, личное обращение)

**Не вызывать**, если:
- текст > 1500 символов (тогда `audio-lesson`)
- нужен MP3-файл, а не «синяя волна» Telegram (тогда напрямую `elevenlabs-tts`)
- идёт техническая команда / список / код-блок (текст лучше)

## Prerequisites

- `/workspace/group/config.json` содержит:
  - `elevenlabs_api_key`
  - `elevenlabs.default_voice` (slug, например `ashot`)
  - `elevenlabs.voices.<slug>.voice_id`
- ffmpeg в контейнере

## Workflow

### 1. Подготовь текст

- Убери Markdown/эмодзи/ссылки (TTS прочитает их буквально и звучать будет глупо)
- Раскрой аббревиатуры: «ИИ» → «искусственный интеллект» (если на русском), «AI» → «эйай»
- Длинные числа разбей: «2026» → «две тысячи двадцать шестой»
- Замени `:`/`;` на `.` или `,` для естественной паузы
- Финальный размер: 50–1500 символов. Меньше — звучит обрывисто, больше — это не voice note.

### 2. Сгенерируй TTS

```bash
CFG=/workspace/group/config.json
KEY=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$CFG','utf8')).elevenlabs_api_key||'')")
VOICE_ID=$(node -e "const c=JSON.parse(require('fs').readFileSync('$CFG','utf8'));console.log(c.elevenlabs?.voices?.[c.elevenlabs?.default_voice]?.voice_id||'')")

[ -z "$KEY" ] || [ -z "$VOICE_ID" ] && { echo "ElevenLabs not configured for this group"; exit 1; }

TS=$(date +%s)
TEXT="<your prepared text>"

# Сразу запрашиваем opus → готовый Telegram voice note
PAYLOAD=$(node -e "console.log(JSON.stringify({
  text:process.argv[1],
  model_id:'eleven_v3',
  voice_settings:{stability:0.45,similarity_boost:0.85,style:0.25,use_speaker_boost:true},
  language_code:'ru'
}))" "$TEXT")

OPUS=/tmp/voice-$TS.opus
curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=opus_48000_64" \
  -H "xi-api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --output "$OPUS"

# Перепакуй в OGG-контейнер (требование Telegram)
OGG=/workspace/group/attachments/voice-$TS.ogg
ffmpeg -y -i "$OPUS" -c:a copy -ac 1 "$OGG" 2>/dev/null
[ -s "$OGG" ] || { echo "voice note generation failed"; exit 1; }
echo "Voice note ready: $OGG"
```

### 3. (Опционально) Лёгкий фон под voice note

Telegram'ские голосовухи **с музыкой** работают, но клиент покажет их как audio-файл, а не «синюю волну». Решай по контексту:
- Поддержка / FAQ → **без музыки** (классический voice note, выше Trust)
- Welcome / прогрев / промо → **с музыкой** (теплее, ярче, но это уже не voice note визуально)

Если нужен фон — вызови `elevenlabs-music` для генерации подложки и смикшируй (см. `elevenlabs-music` SKILL.md, секция «Mix music under TTS»).

### 4. Отправь

Передай путь к OGG обратно хосту через reply-инструмент. Telegram сам распознает opus и покажет «синюю волну».

## Tuning по контексту

| Контекст | model | stability | similarity | style |
|----------|-------|-----------|------------|-------|
| Live-чат, эмоции | `eleven_v3` | 0.35 | 0.85 | 0.30 |
| Поддержка, нейтрально | `eleven_v3` | 0.55 | 0.80 | 0.10 |
| Быстрый отклик (<3 сек latency) | `eleven_turbo_v2_5` | 0.40 | 0.80 | n/a |
| Очень короткое (1-2 фразы) | `eleven_flash_v2_5` | 0.40 | 0.80 | n/a |

`eleven_v3` — золотой стандарт для контента. Если важна скорость — `turbo`/`flash`.

## Use cases для MILA-команд

- **channel-promoter** — голосовое анонсирование нового поста
- **client-profiler** — голосовой welcome для нового лида
- **partner-recruitment** — личное приглашение партнёру
- **ashotai-experts** — голосовой ответ эксперту в сложном вопросе
- **inbox / main** — быстрый голосовой ответ вместо текста, когда так теплее

## Анти-паттерны

- ❌ **Не делать voice notes для бизнес-логики/чисел/ссылок** — пользователь не сможет скопировать
- ❌ **Не ставить `style > 0.4` на длинных текстах** — модель начнёт «играть», теряя естественность
- ❌ **Не отправлять voice notes длиннее 60 сек как одно сообщение** — Telegram режет, фокус теряется. Для длинных используй `audio-lesson`.
- ❌ **Не озвучивать сообщения, требующие точности** (адреса, номера, цены) — TTS ошибается на цифрах
