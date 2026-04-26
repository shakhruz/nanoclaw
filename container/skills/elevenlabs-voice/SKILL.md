---
name: elevenlabs-voice
description: Clone the user's voice via ElevenLabs Instant Voice Cloning. Creates a personal voice_id from one or more audio samples and persists it in the group config so TTS skills can reuse it. Triggers on "клонируй голос", "склонируй мой голос", "create voice clone", "сделай голос Ашота".
---

# ElevenLabs — Voice Cloning (IVC)

Создаёт персональный `voice_id` из одного или нескольких аудиосэмплов через Instant Voice Cloning. Сохраняет ID в `/workspace/group/config.json`, чтобы `elevenlabs-tts` мог его переиспользовать.

## When to invoke

- «склонируй мой голос», «сделай голос Ашота», «clone my voice»
- «создай voice_id из этого голосового», «register voice»
- запрос содержит ссылку на аудиофайл + просьбу «использовать как мой голос»

## Prerequisites

- API key in `/workspace/group/config.json` под ключом `elevenlabs_api_key`
- Минимум один аудиосэмпл — `.ogg`/`.mp3`/`.wav`/`.m4a`. Идеально 1-3 минуты чистой речи.
- ffmpeg (есть в контейнере) — для предварительной нормализации.

## Workflow

### 1. Read API key

```bash
ELEVEN_KEY=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('/workspace/group/config.json','utf8'));console.log(c.elevenlabs_api_key||c.elevenlabsApiKey||'')}catch{console.log('')}")
[ -z "$ELEVEN_KEY" ] && { echo "ELEVENLABS key missing in group config"; exit 1; }
```

### 2. Pick audio sample(s)

If user said «возьми последнее голосовое» — use newest `.oga`/`.ogg` from `/workspace/group/attachments/`:

```bash
SAMPLE=$(ls -t /workspace/group/attachments/*.{oga,ogg,mp3,wav,m4a} 2>/dev/null | head -1)
```

Otherwise use the explicit path the user provided.

**Optional cleanup** (recommended for noisy phone recordings — but ElevenLabs has its own `remove_background_noise` flag, prefer that unless you specifically need ffmpeg work):

```bash
# Convert oga→wav if you want to inspect/trim first
ffmpeg -y -i "$SAMPLE" -ar 44100 -ac 1 /tmp/voice-sample.wav 2>/dev/null
```

### 3. Call IVC endpoint

```bash
RESPONSE=$(curl -s -X POST 'https://api.elevenlabs.io/v1/voices/add' \
  -H "xi-api-key: $ELEVEN_KEY" \
  -F "name=Ashot" \
  -F "description=Personal voice of Ashot Ashirov, Russian/Uzbek, warm, conversational" \
  -F 'labels={"language":"ru","gender":"male","accent":"Russian"}' \
  -F "remove_background_noise=true" \
  -F "files=@${SAMPLE}")

VOICE_ID=$(echo "$RESPONSE" | node -e "let s='';process.stdin.on('data',c=>s+=c).on('end',()=>{try{console.log(JSON.parse(s).voice_id||'')}catch{console.log('')}})")

[ -z "$VOICE_ID" ] && { echo "IVC failed: $RESPONSE"; exit 1; }
echo "Created voice_id=$VOICE_ID"
```

For multi-sample upload, repeat the `-F "files=@..."` flag — ElevenLabs accepts up to 25 files per voice.

### 4. Persist voice_id into group config

```bash
node -e "
const fs=require('fs');const p='/workspace/group/config.json';
const c=JSON.parse(fs.readFileSync(p,'utf8'));
c.elevenlabs=c.elevenlabs||{};
c.elevenlabs.voices=c.elevenlabs.voices||{};
c.elevenlabs.voices['$1']={voice_id:'$VOICE_ID',created_at:new Date().toISOString()};
c.elevenlabs.default_voice='$1';
fs.writeFileSync(p,JSON.stringify(c,null,2));
" "ashot"
```

(Replace `ashot` with the slug requested by user, e.g. `mila`, `mentor`, etc.)

### 5. Report back

Tell the user:
- `voice_id` (short form, last 8 chars OK)
- which slug it's saved under (`elevenlabs.voices.<slug>`)
- next step: «теперь можно вызвать `elevenlabs-tts` с любым текстом — будет звучать твоим голосом»

## Listing / managing existing voices

```bash
# List all custom voices
curl -s "https://api.elevenlabs.io/v1/voices" -H "xi-api-key: $ELEVEN_KEY" \
  | node -e "let s='';process.stdin.on('data',c=>s+=c).on('end',()=>{const v=JSON.parse(s).voices;v.filter(x=>x.category==='cloned').forEach(x=>console.log(x.voice_id, x.name))})"

# Delete a voice
curl -s -X DELETE "https://api.elevenlabs.io/v1/voices/$VOICE_ID" -H "xi-api-key: $ELEVEN_KEY"
```

## Troubleshooting

- **`requires_verification: true`** — only matters for Professional Voice Cloning (PVC). IVC voices are usable immediately.
- **422 error** — sample too short (<2 sec) or wrong format. Convert to wav/mp3 with ffmpeg first.
- **Quality issues** — give ElevenLabs more sample material (up to 25 files, ideally 30 min total). Or use PVC for studio-grade results.
- **Cost** — IVC consumes a *voice slot*, not characters. Slots are tied to subscription tier.

## Notes

- IVC voices belong to the workspace, not the group. Once created they can be referenced from any group's config (just copy the voice_id).
- For multi-language output use TTS model `eleven_v3` or `eleven_multilingual_v2` — both work with cloned voices for RU/EN/UZ.
