---
name: livestream-thumbnail
description: Create premium YouTube thumbnails for live stream recordings. Uses ffmpeg to extract frames from video, Gemini Flash Image for cinematic background/lighting enhancement (keeps real face), rembg for logo transparency, Pillow for channel-style typography and logos with proper drop shadows. Matches AshotAI channel visual style. Use for weekly livestream recording uploads.
---

# Livestream YouTube Thumbnail Generator

Create viral, premium YouTube thumbnails for recorded live streams. Follows AshotAI channel style (teal bg, bold condensed text, yellow accents, LIVE badge) while keeping the real face.

## Prerequisites

- `$OPENROUTER_API_KEY` — for Gemini image enhancement
- `ffmpeg` installed (for frame extraction) — on host: `brew install ffmpeg`
- Python 3 with `Pillow`, `rembg`, `numpy`
- System fonts: `/Library/Fonts/DIN Condensed Bold.ttf` and `/System/Library/Fonts/HelveticaNeue.ttc`

## Trigger

- "создай обложку для эфира", "сделай thumbnail для записи эфира"
- "выложи запись эфира" (в сочетании с youtube-upload)
- "обложка для ютуба" — when user has a livestream recording

## Channel Style Reference (AshotAI Expert)

- **Bright teal/turquoise background** (not dark!)
- **Face MUST be bright and well-lit** — webcam shots are too dark by default
- **Bold condensed font**: DIN Condensed Bold (channel-matching)
- **Two-tone text**: white for main words + YELLOW `(255,215,50)` for key numbers/tech terms
- **Thick black outline** on all text (5-7px radius)
- **LIVE badge** in top-right corner (distinguishes livestream from tutorial videos)
- **Logo/visual storytelling**: e.g., OpenClaw ❌ → NanoClaw ✅ for narrative
- **Minimum text** — 2-4 words max, no small subtitles (noise)

## Workflow

### Phase 1: Extract frames from video

Pick frames from early part (30s-5min) where person is engaged, not mid-speech:

```bash
export VIDEO="<absolute path to recording.mp4>"
export WD=/workspace/group/thumbnails/$(basename "$VIDEO" .mp4)
mkdir -p $WD

ffmpeg -i "$VIDEO" \
  -vf "select='between(t,30,300)',fps=1/30" \
  -frames:v 10 -q:v 2 \
  $WD/frame-%02d.jpg -y
```

Review all 10 frames, pick the one with:
- Direct eye contact with camera
- Clear facial expression (engaged, not mid-speech-blur)
- Centered composition
- Good lighting on face

### Phase 2: Enhance photo via Gemini Flash Image

**Critical:** Safety filters on face-generation are triggered by some prompts. Use the explicit "EDIT this photo" framing, not "generate a person".

The prompt must enforce:
- Person in LEFT 40% (not centered) — reserves right side for text
- BRIGHT, well-lit face (webcam shots are dark by default)
- Teal background with subtle red/orange glow (matches channel + signals "live")
- No text/watermarks

```bash
BASE64=$(base64 -i $WD/frame-XX.jpg)  # chosen frame

python3 << PYEOF > /tmp/enhance-req.json
import json
b64 = """$BASE64"""
payload = {
    "model": "google/gemini-2.5-flash-image",
    "messages": [{"role": "user", "content": [
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
        {"type": "text", "text": "Transform this webcam screenshot into a vibrant, professional YouTube thumbnail photo (1280x720 landscape). The person must be in the LEFT 40% of the frame. LIGHTING: Make the person's face BRIGHT and well-lit, as if they have professional studio ring light. The face should glow with warm, flattering light - not dark or moody. Enhance skin tones to look healthy and vibrant. EXPRESSION: Keep the same face but make the expression slightly more animated and engaging. CLOTHING: Keep all original clothing (glasses, scarf, blazer) but make them look sharper and more polished, richer colors. BACKGROUND: Replace the room with a vibrant teal-turquoise gradient background (similar to YouTube tech channel style). Add a subtle red-orange glow on the right side to suggest LIVE broadcast energy. The RIGHT 55% should be the clean teal gradient - empty space for text overlay. Overall feel: energetic, professional, bright. This should look LIVE and dynamic, not like a static portrait. Do NOT add any text or letters."}
    ]}]
}
print(json.dumps(payload))
PYEOF

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/enhance-req.json > /tmp/enhance-resp.json

# Extract image from response — CRITICAL: images are in `message.images[]` not `content`
python3 -c "
import json, base64
d = json.load(open('/tmp/enhance-resp.json'))
images = d['choices'][0]['message'].get('images', [])
if images:
    b64 = images[0]['image_url']['url'].split(',', 1)[1]
    open('$WD/enhanced.png', 'wb').write(base64.b64decode(b64))
    print('SAVED enhanced.png')
else:
    print('FILTERED or error:', json.dumps(d)[:500])
"
```

**Log cost:** `$0.04 per image` (gemini-3.1-flash-image-preview or 2.5-flash-image).

### Phase 3: Prepare logos (if using visual storytelling)

Remove white backgrounds via `rembg` (produces cleaner result than color-keying):

```bash
python3 << 'PYEOF'
from rembg import remove
import io
from PIL import Image

for name in ['openclaw', 'nanoclaw']:  # or any logos
    data = open(f'$WD/logos/{name}.png', 'rb').read()
    out = remove(data)
    Image.open(io.BytesIO(out)).convert('RGBA').save(f'$WD/logos/{name}-nobg.png')
PYEOF
```

### Phase 4: Composite the thumbnail

Use Pillow with proper drop shadows (via alpha channel blur, NOT solid rectangles):

```python
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# CRITICAL — drop shadow must use alpha channel, not solid rectangle
def make_drop_shadow(logo_rgba, blur_radius=6, opacity=130):
    alpha = logo_rgba.split()[3]
    shadow = Image.new('RGBA', logo_rgba.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda a: min(a, opacity)))
    return shadow.filter(ImageFilter.GaussianBlur(radius=blur_radius))

# Apply:
logo_shadow = make_drop_shadow(logo_rgba)
img.paste(logo_shadow, (x + 4, y + 4), logo_shadow)  # shadow offset
img.paste(logo_rgba, (x, y), logo_rgba)              # actual logo
```

**DO NOT** use `img.paste(logo, (x, y), Image.new('RGBA', logo.size, (0,0,0,120)))` — this creates a solid RECTANGULAR shadow around the logo.

### Phase 5: Typography (channel style)

```python
fp_din = '/Library/Fonts/DIN Condensed Bold.ttf'  # channel-matching bold condensed
fp_hel = '/System/Library/Fonts/HelveticaNeue.ttc'  # for badge

YELLOW = (255, 215, 50)  # accent color for numbers/tech terms
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

def outlined(draw, pos, text, font, fill, outline=BLACK, w=5):
    """Thick outline for readability at small sizes."""
    x, y = pos
    for dx in range(-w, w+1):
        for dy in range(-w, w+1):
            if dx*dx + dy*dy <= w*w:
                draw.text((x+dx, y+dy), text, font=font, fill=outline)
    draw.text(pos, text, font=font, fill=fill)
```

**Text rules:**
- 2-4 words maximum
- Numbers and tech terms (AI, NanoClaw, $100) in YELLOW
- Rest in WHITE with thick black outline
- Font sizes: main words 120-145pt, smaller connectors (С, и) 80-90pt
- Never include channel name or @username — too small to read, creates noise

### Phase 6: LIVE badge (top-right corner)

Red rounded rectangle with recording dot. Distinguishes livestream from regular tutorial.

```python
bx, by, bw, bh = 1280-260, 25, 240, 58
# Gradient red (darker bottom, lighter top, inner shine)
draw.rounded_rectangle([bx, by, bx+bw, by+bh], radius=14, fill=(180, 15, 15))
draw.rounded_rectangle([bx, by, bx+bw, by+bh//2], radius=14, fill=(230, 40, 40))
draw.rounded_rectangle([bx+3, by+3, bx+bw-3, by+10], radius=10, fill=(255, 100, 100))

# White ring + red center (recording dot)
dot_cx, dot_cy = bx + 28, by + bh // 2
draw.ellipse([dot_cx-13, dot_cy-13, dot_cx+13, dot_cy+13], fill=(255, 255, 255))
draw.ellipse([dot_cx-8, dot_cy-8, dot_cx+8, dot_cy+8], fill=(235, 45, 45))
draw.ellipse([dot_cx-7, dot_cy-7, dot_cx-3, dot_cy-3], fill=(255, 200, 200))

# Text: "LIVE" big + "ПРЯМОЙ ЭФИР" subtitle
f_big = ImageFont.truetype(fp_hel, 22, index=2)  # Bold
f_lbl = ImageFont.truetype(fp_hel, 16, index=2)
draw.text((dot_cx + 22, by + 9), 'LIVE', font=f_big, fill=(255, 255, 255))
draw.text((dot_cx + 22, by + 34), 'ПРЯМОЙ ЭФИР', font=f_lbl, fill=(255, 220, 220))
```

### Phase 7: Visual storytelling (optional, high-impact)

For narratives like "replacing X with Y", add logo comparison:
- Old thing (e.g., OpenClaw) with red X strike-through + label strikethrough
- Yellow arrow (with proper blurred drop shadow)
- New thing (e.g., NanoClaw) with gold glow behind it

```python
# Red X across old logo
for offset in range(-4, 5):
    draw_on_logo.line([(0, offset), (w, h+offset)], fill=(230, 30, 30), width=2)
    draw_on_logo.line([(0, h+offset), (w, offset)], fill=(230, 30, 30), width=2)

# Gold glow behind new logo (blurred radial)
glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r in range(int(size*0.9), 0, -2):
    alpha = int(50 * (1 - r/(size*0.9)))
    gd.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255, 220, 80, alpha))
glow = glow.filter(ImageFilter.GaussianBlur(radius=15))
img = Image.alpha_composite(img, glow)
```

### Phase 8: Upload to YouTube via Zernio

```bash
# Get presigned URL for thumbnail
THUMB_SIZE=$(stat -c%s "$WD/final.png" 2>/dev/null || stat -f%z "$WD/final.png")
curl -s -X POST "https://zernio.com/api/v1/media/presign" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"thumbnail.png\",\"contentType\":\"image/png\",\"size\":$THUMB_SIZE}" \
  > /tmp/thumb-presign.json

UPLOAD_URL=$(node -e "console.log(require('/tmp/thumb-presign.json').uploadUrl)")
PUBLIC_URL=$(node -e "console.log(require('/tmp/thumb-presign.json').publicUrl)")

curl -X PUT "$UPLOAD_URL" -H "Content-Type: image/png" --data-binary @"$WD/final.png"

# Apply via update-metadata (works for already-published videos)
curl -s -X POST "https://zernio.com/api/v1/posts/<POST_ID>/update-metadata" \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"platform\":\"youtube\",\"thumbnailUrl\":\"$PUBLIC_URL\"}"
```

For direct YouTube videos (not published through Zernio), use `"_"` as postId and pass `videoId` + `accountId`.

## Text hook formulas (viral)

| Pattern | Example | Why it works |
|---------|---------|-------------|
| **Number + benefit** | "7 ДНЕЙ С AI АГЕНТОМ" | Concrete, reality-show feel |
| **Price + comparison** | "$100/мес = СОТРУДНИК" | Shock value, specific |
| **Action + result** | "ЗАПУСТИЛ AI БИЗНЕС" | Past-tense credibility |
| **Question curiosity gap** | "ПОЧЕМУ НЕ OPENCLAW?" | Controversy, makes click |
| **Reality/before-after** | "УВОЛИЛ ВСЕХ" + arrow to AI | Provocative, emotional |

**Rule:** 2-4 words, ONE number or tech term in yellow.

## Common mistakes to avoid

1. **Generating face from scratch** — AI models don't reproduce faces accurately. Always use `img2img` with real photo as reference. Prompt should say "EDIT this photo", not "create a person."
2. **Text on top of face** — use enhanced photo with person on LEFT 40%, text on RIGHT 55%.
3. **Dark face** — webcam shots need the "BRIGHT studio ring light" instruction explicitly. Channel style = bright face.
4. **Rectangular shadow** — always use `make_drop_shadow()` helper with alpha channel blur.
5. **Too much text** — channel name, handles, taglines are noise. 2-4 words max.
6. **Generic thumbnails for livestreams** — without LIVE badge, looks like a tutorial. Badge differentiates.
7. **Impact font for titles** — looks cheap. Use DIN Condensed Bold to match channel.
8. **Cyrillic in AI image text** — Gemini/Nano Banana misspell Russian ("ВТОРИЙ" vs "ВТОРОЙ"). ALWAYS generate background without text, add text with Pillow.

## Cost

- Gemini image enhancement: `$0.04`
- Optional thumbnail generation (text-to-image for background only): `$0.04`
- Total: ~$0.04-0.08 per thumbnail

Log usage: `/workspace/group/store/log-usage.sh <group> openrouter google/gemini-2.5-flash-image 0 0 0.04 "thumbnail enhance"`

## Related: Full Livestream Publishing Pipeline

This skill produces the thumbnail. For the end-to-end flow after a livestream recording arrives:

1. **This skill** (`livestream-thumbnail`) — generate cover image
2. **`youtube-upload`** skill — upload video to YouTube via Zernio, apply thumbnail via `/update-metadata`
3. **Delegate announcement** to `channel-promoter` agent via a scheduled once-task:
   - Copy post draft (with YouTube URL substituted) to `groups/telegram_channel-promoter/sources/`
   - Copy thumbnail to same folder
   - Insert row into `scheduled_tasks` table with `group_folder='telegram_channel-promoter'`, `schedule_type='once'`, `next_run=<1 min from now>`, prompt instructing her to run `humanizer-ru` → `telegram-channel-publisher` → archive → notify main
4. She publishes to `@ashotonline` via her `telegram-channel-publisher` skill (Telethon userbot, already configured) and reports back.

This separation keeps thumbnail creation (creative) from distribution (editorial) — each agent owns its domain.
