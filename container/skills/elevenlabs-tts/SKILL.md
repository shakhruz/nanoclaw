---
name: elevenlabs-tts
description: Generate speech from text via ElevenLabs TTS using a cloned voice (or any voice_id). Output as MP3 or Telegram-ready OGG voice note. Triggers on "озвучь", "сгенерируй голосом", "tts это", "speak this", "voice this", or any request to turn text into spoken audio.
---

# ElevenLabs — Text-to-Speech

Превращает текст в аудио через ElevenLabs TTS. По умолчанию использует склонированный голос Ашота (см. `elevenlabs-voice`). Поддерживает русский/узбекский/английский.

## When to invoke

- «озвучь этот текст», «сделай голосовое», «tts», «speak this»
- «отправь голосовое» — генерируешь mp3, конвертируешь в ogg/opus, отдаёшь как voice note
- «прочитай это моим голосом» / «голосом Ашота»
- запрос содержит блок текста + явное намерение получить аудио

## Prerequisites

- `elevenlabs_api_key` в `/workspace/group/config.json`
- `elevenlabs.default_voice` (slug) или явный `voice_id` от пользователя
- Один из `elevenlabs.voices.<slug>` уже создан через `elevenlabs-voice` (либо использовать публичный voice_id из библиотеки ElevenLabs)
- ffmpeg — для конвертации MP3 → OGG/Opus voice note

## Workflow

### 1. Read config

```bash
CFG=/workspace/group/config.json
ELEVEN_KEY=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$CFG','utf8')).elevenlabs_api_key||'')")
DEFAULT_SLUG=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$CFG','utf8')).elevenlabs?.default_voice||'')")
VOICE_ID=$(node -e "const c=JSON.parse(require('fs').readFileSync('$CFG','utf8'));console.log(c.elevenlabs?.voices?.[c.elevenlabs?.default_voice]?.voice_id||'')")
[ -z "$ELEVEN_KEY" ] && { echo "ELEVENLABS key missing"; exit 1; }
[ -z "$VOICE_ID" ] && { echo "No default voice. Run elevenlabs-voice first or pass voice_id explicitly."; exit 1; }
```

### 2. Generate MP3

```bash
TEXT="Привет! Это мой голос — клонированный через ElevenLabs."
TS=$(date +%s)
OUT=/workspace/group/attachments/tts-$TS.mp3

curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128" \
  -H "xi-api-key: $ELEVEN_KEY" \
  -H "Content-Type: application/json" \
  -d "$(node -e "console.log(JSON.stringify({text:process.argv[1],model_id:'eleven_v3',voice_settings:{stability:0.5,similarity_boost:0.75,style:0.0,use_speaker_boost:true}}))" "$TEXT")" \
  --output "$OUT"

[ ! -s "$OUT" ] && { echo "TTS failed (empty file)"; exit 1; }
echo "Generated: $OUT"
```

**Models** (pick one):
- `eleven_v3` — best quality, expressive, multilingual. Default for content.
- `eleven_multilingual_v2` — solid alternative, faster, slightly less expressive.
- `eleven_turbo_v2_5` — lowest latency, good for realtime/voicemail.
- `eleven_flash_v2_5` — even faster, lower fidelity.

**voice_settings tuning:**
- `stability` 0.3-0.5 — более живая интонация (для контента); 0.7+ — для нарратива/диктора
- `similarity_boost` 0.7-0.85 — близость к оригинальному голосу
- `style` 0-0.3 — больше эмоций (только eleven_v3)
- `speed` 0.7-1.2 — скорость речи

### 3. (Optional) Convert to Telegram voice note

Telegram voice notes требуют OGG/Opus mono. Двa варианта:

**A. Запросить opus сразу у ElevenLabs:**
```bash
curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=opus_48000_64" \
  -H "xi-api-key: $ELEVEN_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"...","model_id":"eleven_v3"}' \
  --output /tmp/tts-$TS.opus
# репак в ogg-контейнер для telegram
ffmpeg -y -i /tmp/tts-$TS.opus -c:a copy -ac 1 /workspace/group/attachments/tts-$TS.ogg 2>/dev/null
```

**B. Конвертировать MP3 → OGG/Opus:**
```bash
ffmpeg -y -i "$OUT" -c:a libopus -b:a 64k -ac 1 -ar 48000 "/workspace/group/attachments/tts-$TS.ogg" 2>/dev/null
```

### 4. Report — INLINE в чат, НЕ через milagpt.cc

**Default:** отправь mp3 / ogg прямо в чат как inline audio attachment.

```bash
mcp__nanoclaw__send_message(
  text="Готово — прослушай",
  files=["$OUT"]   # путь к .mp3 или .ogg
)
```

Telegram автоматически распознаёт audio файлы и показывает inline-плеер. Никакой web-публикации не нужно.

Verb-specific варианты:
- «отправь как голосовое» → конвертируй в `.ogg` (Phase 3) и отправь как `files=["voice.ogg"]` — Telegram покажет как voice-message
- «дай файл» / «сохрани» → отправь `.mp3` через files=[]
- «озвучь и наложи музыку» → передай дальше в `elevenlabs-music` для миксования

**АНТИ-паттерн (НЕ делать):**
- ❌ `web-asset-upload` для mp3 → не нужно. В чат напрямую быстрее и без риска Vercel error.
- ❌ Только `text="Готово: $OUT"` без files → Шахруз получит путь, не сможет послушать.

См. `[[architecture/sub-agents#21--доставка-файлов]]` для полного правила доставки файлов.

## Public voices (без клонирования)

Если пользователь хочет голос из библиотеки ElevenLabs без клонирования:

```bash
# Поиск
curl -s "https://api.elevenlabs.io/v1/shared-voices?language=ru&page_size=20" \
  -H "xi-api-key: $ELEVEN_KEY" \
  | node -e "let s='';process.stdin.on('data',c=>s+=c).on('end',()=>{JSON.parse(s).voices.forEach(v=>console.log(v.voice_id,v.name,v.gender,v.accent))})"
```

## Long text handling

- TTS endpoint принимает до ~5000 символов за запрос. Для длинных текстов разбивай на абзацы по предложениям и склеивай через ffmpeg concat:
  ```bash
  ffmpeg -y -i "concat:p1.mp3|p2.mp3|p3.mp3" -c copy joined.mp3
  ```
- Для последовательных кусков передавай `previous_text`/`next_text` в JSON чтобы сохранить просодию.

## Cost tracking

Каждый запрос возвращает заголовок `x-character-count`. Запиши при необходимости:
```bash
curl -i ... 2>&1 | grep -i 'x-character-count'
```

## Troubleshooting

- **401** — ключ не валиден или quota закончилась
- **422** — voice_id не существует или text пустой
- **Кириллица искажена** — используй `eleven_v3` или `eleven_multilingual_v2`, явно укажи `language_code: "ru"`
- **Глухой звук на Telegram voice note** — проверь, что итоговый файл моно (`-ac 1`) и opus, не vorbis
