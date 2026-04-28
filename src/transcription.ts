/**
 * Voice / audio transcription via Deepgram.
 *
 * Channel adapters (Telegram in particular) deliver voice notes as binary
 * attachments. The host transcribes them inline before the agent ever sees
 * the message — agents receive plain text with a `[Voice: <transcript>]`
 * prefix, transparent to whatever per-agent CLAUDE.md rules apply.
 *
 * Reads DEEPGRAM_API_KEY from .env. If the key is missing, transcription
 * is a no-op and the original (empty) text is preserved.
 */
import { readEnvFile } from './env.js';
import { log } from './log.js';

const DEEPGRAM_URL = 'https://api.deepgram.com/v1/listen';

interface DeepgramAlternative {
  transcript?: string;
  confidence?: number;
}

interface DeepgramResponse {
  results?: {
    channels?: Array<{
      alternatives?: DeepgramAlternative[];
      detected_language?: string;
    }>;
  };
}

let cachedKey: string | null | undefined = undefined;

function getKey(): string | null {
  if (cachedKey !== undefined) return cachedKey;
  const fromEnv = process.env.DEEPGRAM_API_KEY;
  if (fromEnv) {
    cachedKey = fromEnv;
    return cachedKey;
  }
  cachedKey = readEnvFile(['DEEPGRAM_API_KEY']).DEEPGRAM_API_KEY ?? null;
  return cachedKey;
}

/** True if Deepgram is configured (key present). */
export function isTranscriptionAvailable(): boolean {
  return getKey() !== null;
}

/**
 * Transcribe a single audio buffer. Returns the transcript text, or null
 * if transcription is disabled / fails. Uses Deepgram nova-3 with auto
 * language detection (RU + UZ + EN are the working languages here).
 */
export async function transcribeAudio(buf: Buffer, mimeType: string | undefined): Promise<string | null> {
  const key = getKey();
  if (!key) return null;
  if (!buf || buf.length === 0) return null;

  const params = new URLSearchParams({
    model: 'nova-3',
    detect_language: 'true',
    smart_format: 'true',
    punctuate: 'true',
  });

  try {
    const res = await fetch(`${DEEPGRAM_URL}?${params}`, {
      method: 'POST',
      headers: {
        Authorization: `Token ${key}`,
        'Content-Type': mimeType || 'audio/ogg',
      },
      body: new Uint8Array(buf),
    });

    if (!res.ok) {
      log.warn('Deepgram transcription failed', { status: res.status, statusText: res.statusText });
      return null;
    }

    const data = (await res.json()) as DeepgramResponse;
    const alt = data.results?.channels?.[0]?.alternatives?.[0];
    const transcript = alt?.transcript?.trim();
    if (!transcript) return null;
    log.debug('Transcribed audio', { bytes: buf.length, chars: transcript.length });
    return transcript;
  } catch (err) {
    log.warn('Deepgram transcription threw', { err });
    return null;
  }
}

/** Heuristic: is this attachment audio we should transcribe? */
export function isTranscribableAttachment(att: { type?: string; mimeType?: string }): boolean {
  const mt = (att.mimeType || '').toLowerCase();
  const t = (att.type || '').toLowerCase();
  if (t === 'audio' || t === 'voice') return true;
  if (mt.startsWith('audio/')) return true;
  if (mt === 'video/ogg') return true;
  return false;
}
