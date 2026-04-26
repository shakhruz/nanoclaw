---
name: audio-lesson
description: Produce structured audio lessons (5–30 min) in the user's cloned voice with continuous background music bed. Splits long content into sections, generates TTS per section, mixes a single background track underneath, exports MP3 with chapter markers. Triggers on "сделай аудио урок", "запиши урок", "audio lesson", "озвучь курс", "озвучь главу".
---

# Audio Lesson — образовательное аудио

Высокоуровневый pipeline для производства полноформатных аудио-уроков голосом Шахруза с непрерывной музыкальной подложкой и chapter markers. Используется для: курсов, мини-лекций, эпизодов подкаста, аудио-версий лонгридов wiki.

## When to invoke

- «сделай аудио урок по теме X», «озвучь главу из курса»
- «запиши подкаст-эпизод из этого материала»
- «аудио-версия этого лонгрида / wiki-страницы»
- запрос с outline / структурой / явным разделением на блоки

**Не вызывать**, если:
- < 90 сек суммарно (тогда `voice-message`)
- технический контент с кодом / формулами / таблицами (аудио = плохой формат)
- материал не структурирован — сначала попроси пользователя дать outline

## Prerequisites

- `elevenlabs_api_key` + `elevenlabs.default_voice` в group config
- ffmpeg
- Outline или готовый сценарий урока

## Workflow

### 1. Структурируй сценарий

На вход: либо готовый сценарий, либо тема + outline. Если outline — сначала разверни в полный текст (можно в этой же сессии — Sonnet справится с расширением).

Финальная структура (JSON в `/tmp/lesson-plan.json`):

```json
{
  "title": "Как ИИ-агент собирает воронку за 30 минут",
  "intro_script": "Привет! Сегодня мы разберём...",
  "sections": [
    {"name": "Зачем вообще ИИ-агент", "script": "..."},
    {"name": "Архитектура воронки", "script": "..."},
    {"name": "Сборка за 30 минут", "script": "..."}
  ],
  "outro_script": "Если было полезно — нажми..."
}
```

Каждая секция: 60–600 секунд аудио (≈300–3000 символов текста).

### 2. Сгенерируй TTS по секциям

```bash
CFG=/workspace/group/config.json
KEY=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$CFG','utf8')).elevenlabs_api_key||'')")
VOICE_ID=$(node -e "const c=JSON.parse(require('fs').readFileSync('$CFG','utf8'));console.log(c.elevenlabs?.voices?.[c.elevenlabs?.default_voice]?.voice_id||'')")

WD=/workspace/group/attachments/lesson-$(date +%Y%m%d-%H%M%S)
mkdir -p "$WD"

# Через Node — итерируем по секциям с previous_text/next_text для просодии
node -e "
const fs=require('fs');const path=require('path');const https=require('https');
const plan=JSON.parse(fs.readFileSync('/tmp/lesson-plan.json','utf8'));
const KEY=process.env.KEY,VOICE_ID=process.env.VOICE_ID,WD=process.env.WD;
const segments=[
  {name:'00-intro',text:plan.intro_script},
  ...plan.sections.map((s,i)=>({name:String(i+1).padStart(2,'0')+'-'+s.name.toLowerCase().replace(/[^a-z0-9а-яё]+/gi,'-').slice(0,40),text:s.script})),
  {name:'99-outro',text:plan.outro_script}
];
(async()=>{
  for (let i=0;i<segments.length;i++){
    const seg=segments[i];
    const prev=segments[i-1]?.text?.slice(-300);
    const next=segments[i+1]?.text?.slice(0,300);
    const body=JSON.stringify({
      text:seg.text,
      model_id:'eleven_v3',
      voice_settings:{stability:0.55,similarity_boost:0.85,style:0.15,use_speaker_boost:true},
      language_code:'ru',
      previous_text:prev,next_text:next
    });
    await new Promise((res,rej)=>{
      const req=https.request('https://api.elevenlabs.io/v1/text-to-speech/'+VOICE_ID+'?output_format=mp3_44100_128',{
        method:'POST',headers:{'xi-api-key':KEY,'content-type':'application/json'}
      },r=>{
        const chunks=[];r.on('data',c=>chunks.push(c));r.on('end',()=>{
          if (r.statusCode!==200){console.error('FAIL',seg.name,r.statusCode,Buffer.concat(chunks).toString().slice(0,200));return rej(new Error('tts fail'))}
          fs.writeFileSync(path.join(WD,seg.name+'.mp3'),Buffer.concat(chunks));
          console.error('ok',seg.name);res();
        });
      });
      req.on('error',rej);req.write(body);req.end();
    });
  }
})().catch(e=>{console.error(e);process.exit(1)});
" 2>&1
```

### 3. Склей дорожку голоса

```bash
# Список файлов в порядке
ls "$WD"/*.mp3 | sort > /tmp/concat.txt
sed -i 's|^|file |' /tmp/concat.txt

ffmpeg -y -f concat -safe 0 -i /tmp/concat.txt -c copy "$WD/voice-track.mp3" 2>/dev/null
TOTAL_DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$WD/voice-track.mp3")
echo "Voice track: $TOTAL_DUR sec"
```

### 4. Сгенерируй непрерывную музыкальную подложку

Music API даёт максимум 600 сек (10 мин) за один запрос. Для уроков длиннее — генерим несколько кусков и склеиваем с crossfade.

```bash
PROMPT="Calm intimate piano with soft warm pads, slow 75-80 bpm, hopeful contemplative mood, no drums, no melodic lead, instrumental music bed for educational podcast"

# Округляем до 30 сек хвоста
TARGET_MS=$(node -e "console.log(Math.min(600000,Math.round((Number(process.argv[1])+10)*1000)))" "$TOTAL_DUR")

PAYLOAD=$(node -e "console.log(JSON.stringify({prompt:process.argv[1],music_length_ms:Number(process.argv[2]),model_id:'music_v1',force_instrumental:true}))" "$PROMPT" "$TARGET_MS")

curl -s -X POST "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128" \
  -H "xi-api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --output "$WD/music-bed.mp3"
```

**Если урок > 10 мин** — сделай несколько генераций с одинаковым промптом и склей через ffmpeg `acrossfade`:
```bash
ffmpeg -i bed1.mp3 -i bed2.mp3 -filter_complex "[0:a][1:a]acrossfade=d=4" bed-joined.mp3
```

### 5. Микс с sidechain ducking (музыка приглушается под голос)

```bash
ffmpeg -y -i "$WD/voice-track.mp3" -i "$WD/music-bed.mp3" \
  -filter_complex "
    [1:a]aloop=loop=-1:size=2e9,atrim=duration=${TOTAL_DUR},volume=0.22[bg];
    [bg][0:a]sidechaincompress=threshold=0.04:ratio=8:attack=15:release=350[bgduck];
    [0:a][bgduck]amix=inputs=2:duration=first[mix];
    [mix]afade=t=in:st=0:d=2,afade=t=out:st=${TOTAL_DUR}:d=3[out]
  " -map "[out]" -c:a libmp3lame -b:a 192k -ar 44100 \
  "$WD/lesson-final.mp3" 2>/dev/null
```

### 6. Chapter markers (ID3v2)

Сделай из имён сегментов главы — слушатель сможет прыгать в плеерах:

```bash
# Считаем offset каждой секции
node -e "
const fs=require('fs');const {execSync}=require('child_process');
const dir=process.env.WD;
const files=fs.readdirSync(dir).filter(f=>f.match(/^\d+-.+\.mp3$/)).sort();
let off=0;const chapters=[];
for (const f of files){
  const dur=Number(execSync('ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 '+dir+'/'+f).toString().trim());
  chapters.push({title:f.replace(/^\d+-/,'').replace(/-/g,' ').replace('.mp3',''),start_ms:Math.round(off*1000),end_ms:Math.round((off+dur)*1000)});
  off+=dur;
}
let meta=';FFMETADATA1\n';
for (const c of chapters){
  meta+=\`[CHAPTER]\\nTIMEBASE=1/1000\\nSTART=\${c.start_ms}\\nEND=\${c.end_ms}\\ntitle=\${c.title}\\n\\n\`;
}
fs.writeFileSync(dir+'/chapters.txt',meta);
" 

ffmpeg -y -i "$WD/lesson-final.mp3" -i "$WD/chapters.txt" -map_metadata 1 -codec copy "$WD/lesson-final-chapters.mp3" 2>/dev/null
```

### 7. Save & report

- Финальный файл: `$WD/lesson-final-chapters.mp3`
- Сохрани метаданные в `$WD/manifest.json`: title, segments, total_duration, file_size, voice_id, created_at
- Если урок входит в курс/воронку — закинь в `/workspace/global/lessons/<slug>/` для расшаривания между группами

## Use cases для MILA-департаментов

- **ashotai-experts** — аудио-материалы для экспертов клуба
- **channel-promoter** — мини-уроки в Telegram-каналах вместо текстовых лонгридов
- **partner-recruitment** — обучающие материалы для новых партнёров (онбординг)
- **client-profiler** — персонализированные welcome-лекции для премиум-клиентов
- **octo** — аудио-блоки в OctoFunnel воронках (welcome-серия)
- **youtube-manager** — аудио-версии YouTube-видео для подкаст-площадок

## Качество и cost-aware

- Модель `eleven_v3` — 2 credits за символ. Урок 5000 символов = 10000 credits.
- Стартер план = 30k credits/мес. → ~3 урока 5000 символов в месяц на v3.
- Если бюджет жмёт → `eleven_multilingual_v2` (1 credit/char) или `eleven_turbo_v2_5` (0.5 credit/char). Качество чуть ниже, но для длинного материала разница не критична.
- Music API биллится отдельно (по секундам).

Перед стартом большого урока проверь баланс:
```bash
curl -s "https://api.elevenlabs.io/v1/user/subscription" -H "xi-api-key: $KEY" | node -e "let s='';process.stdin.on('data',c=>s+=c).on('end',()=>{const d=JSON.parse(s);console.log('used:',d.character_count,'/',d.character_limit)})"
```

## Анти-паттерны

- ❌ **Не озвучивать списки и таблицы** — переделай в нарратив или оставь текстом
- ❌ **Не вставлять `voice_settings.style > 0.3` на длинных** — модель начнёт уставать на 5+ минутах
- ❌ **Не использовать одну музыкальную подложку для уроков разных тем** — генери под каждый mood свежую (cost минимальный)
- ❌ **Не игнорировать `previous_text`/`next_text`** — без них стыки секций звучат рвано
- ❌ **Не ставить ducking слишком агрессивно** (`ratio>10`, `threshold<0.02`) — фон будет «дышать»
