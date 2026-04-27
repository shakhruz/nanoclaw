---
name: elevenlabs-music
description: Generate background music from a text prompt via ElevenLabs Music API. Optionally mix the generated track underneath a TTS voiceover via ffmpeg ducking. Triggers on "сгенерируй музыку", "фоновая музыка", "background music", "mix voice with music", "music for funnel".
---

# ElevenLabs — Music Generation

Генерирует музыкальные треки из текстового промпта. Используется как:
1. Самостоятельная фоновая музыка под reels/voiceover/Octo-воронки
2. Подложка под TTS — миксуем через ffmpeg с автоматическим duck'ом громкости

## When to invoke

- «сгенерируй фоновую музыку», «сделай background»
- «mix voice + music», «наложи музыку на голос»
- «трек для воронки», «intro/outro для подкаста»
- запрос с описанием mood/жанра для генерации звука

## Prerequisites

- `elevenlabs_api_key` в group config
- ffmpeg — для микса с TTS
- (опционально) готовый MP3 от `elevenlabs-tts` — если нужен voiceover поверх музыки

## Workflow

### 1. Generate music

```bash
ELEVEN_KEY=$(node -e "console.log(JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8')).elevenlabs_api_key||'')")

PROMPT="Calm, warm, ambient piano with subtle pads, lo-fi, no drums, 90 bpm, intimate and welcoming"
DURATION_MS=30000  # 30 sec
TS=$(date +%s)
OUT=/workspace/group/attachments/music-$TS.mp3

curl -s -X POST "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128" \
  -H "xi-api-key: $ELEVEN_KEY" \
  -H "Content-Type: application/json" \
  -d "$(node -e "console.log(JSON.stringify({prompt:process.argv[1],music_length_ms:Number(process.argv[2]),model_id:'music_v1',force_instrumental:true}))" "$PROMPT" "$DURATION_MS")" \
  --output "$OUT"

[ ! -s "$OUT" ] && { echo "music gen failed"; exit 1; }
echo "Generated: $OUT"
```

**Параметры**:
- `music_length_ms` — 3000-600000 (3 сек – 10 мин)
- `force_instrumental: true` — без вокала (для voiceover-фона обязательно)
- `model_id: music_v1` — единственная модель сейчас

**Хорошие промпты для контента**:
- Welcome funnel: `"Warm, intimate, slow-tempo piano with soft strings, hopeful, no drums, instrumental"`
- Бизнес-контент / экспертные посты: `"Calm corporate ambient, soft synths, gentle pulse, no melody-heavy lead, instrumental"`
- Energy/мотивация: `"Uplifting cinematic build, light percussion, strings rising, modern, instrumental"`
- Storytelling/кейсы: `"Lo-fi hip-hop, vinyl crackle, soft chords, mellow, instrumental"`

### 2. Mix music under TTS (ducking)

Если нужно совместить с готовым TTS-файлом:

```bash
VOICE=/workspace/group/attachments/tts-XXX.mp3
MUSIC=/workspace/group/attachments/music-XXX.mp3
MIX=/workspace/group/attachments/mix-$TS.mp3

# Длительность голоса
VOICE_DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VOICE")
# Музыку обрезаем/зацикливаем под голос + 2 сек хвоста
TARGET=$(node -e "console.log(Number(process.argv[1])+2)" "$VOICE_DUR")

ffmpeg -y -i "$VOICE" -stream_loop -1 -t "$TARGET" -i "$MUSIC" \
  -filter_complex "
    [1:a]volume=0.18[bg];
    [0:a][bg]amix=inputs=2:duration=first:dropout_transition=2[mix];
    [mix]afade=t=out:st=$VOICE_DUR:d=2[out]
  " -map "[out]" -c:a libmp3lame -b:a 192k "$MIX" 2>/dev/null

echo "Mixed: $MIX"
```

**Tuning**:
- `volume=0.18` — стандартный уровень фона. Если голос тихий → 0.10-0.12. Если музыка должна быть слышна → 0.25.
- Для **сайдчейн-ducking** (музыка приглушается *только* когда есть голос) используй `sidechaincompress`:
  ```
  [1:a][0:a]sidechaincompress=threshold=0.05:ratio=8:attack=20:release=400[bgduck];
  [0:a][bgduck]amix=inputs=2:duration=first[mix]
  ```

### 3. Convert to Telegram voice note (если для голосовухи)

```bash
ffmpeg -y -i "$MIX" -c:a libopus -b:a 96k -ac 1 -ar 48000 \
  "/workspace/group/attachments/mix-$TS.ogg" 2>/dev/null
```

(Voice notes с фоновой музыкой работают в Telegram, но визуально это будет audio-файл, не «синяя волна» классической голосовухи. Для классической голосовухи Telegram требует mono ≤1мин и плеер сам решит.)

## Composition plan (для длинных треков)

Для треков с явной структурой (intro→verse→chorus→outro) используй `composition_plan` вместо `prompt`:

```json
{
  "composition_plan": {
    "sections": [
      {"name": "intro", "duration_ms": 8000, "prompt": "soft piano alone"},
      {"name": "build", "duration_ms": 12000, "prompt": "add warm pads"},
      {"name": "outro", "duration_ms": 6000, "prompt": "fade pads, piano resolves"}
    ]
  },
  "model_id": "music_v1"
}
```

## Troubleshooting

- **422** — `prompt` или `music_length_ms` отсутствует, либо длительность вне диапазона 3000-600000
- **Музыка обрезается резко** — добавь `afade=t=out:st=...:d=2` в ffmpeg
- **Голос тонет в музыке** — снижай `volume` фона до 0.10 или используй sidechaincompress
- **Кириллица в промпте** — пиши промпты на английском, ElevenLabs music лучше понимает english music vocabulary

## Cost

Music API биллится по сгенерированным секундам. Текущие лимиты — см. workspace usage:
```bash
curl -s "https://api.elevenlabs.io/v1/usage/character-stats" -H "xi-api-key: $ELEVEN_KEY"
```
