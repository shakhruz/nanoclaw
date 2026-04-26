import fs from 'fs';
import https from 'https';
import path from 'path';

import { Api, Bot, InputFile } from 'grammy';

import { ASSISTANT_NAME, TRIGGER_PATTERN } from '../config.js';
import { readEnvFile } from '../env.js';
import { resolveGroupFolderPath } from '../group-folder.js';
import { processImageFile } from '../image.js';
import { logger } from '../logger.js';
import { registerChannel, ChannelOpts } from './registry.js';
import {
  InlineButton,
  Channel,
  OnChatMetadata,
  OnInboundMessage,
  RegisteredGroup,
} from '../types.js';

export interface TelegramChannelOpts {
  onMessage: OnInboundMessage;
  onChatMetadata: OnChatMetadata;
  registeredGroups: () => Record<string, RegisteredGroup>;
  onAutoRegister?: (
    chatJid: string,
    userName: string,
    userId?: number,
    languageCode?: string,
    deepLink?: string,
  ) => void;
}

// --- Bot pool for agent teams (Swarm) ----------------------------------
// Send-only Api instances (no polling). Each pool bot can be renamed at
// runtime via setMyName so messages appear from a distinct identity in
// Telegram. See groups/global/wiki/architecture/sub-agents.md for the
// coordination model.
const poolApis: Api[] = [];
// Deterministic role→pool-index map. Populated from TELEGRAM_BOT_POOL_ROLES
// (comma-separated, same order as TELEGRAM_BOT_POOL). If role isn't in this
// map, fall back to round-robin. Deterministic mapping ensures bot username
// + avatar + display-name stay consistent across sessions and restarts.
const roleBotMap = new Map<string, number>();
// `${groupFolder}:${senderName}` → index (round-robin fallback cache).
const senderBotMap = new Map<string, number>();
let nextPoolIndex = 0;

export async function initBotPool(
  tokens: string[],
  roles: string[] = [],
): Promise<void> {
  for (const token of tokens) {
    try {
      const api = new Api(token);
      const me = await api.getMe();
      poolApis.push(api);
      logger.info(
        { username: me.username, id: me.id, poolSize: poolApis.length },
        'Pool bot initialized',
      );
    } catch (err) {
      logger.error({ err }, 'Failed to initialize pool bot');
    }
  }
  // Register deterministic role mapping. Trim + skip empty entries so
  // callers can leave gaps (e.g. "Marketer,,Targetist" maps indices 0 + 2).
  roles.forEach((role, i) => {
    const name = role.trim();
    if (!name || i >= poolApis.length) return;
    roleBotMap.set(name, i);
  });
  // Canonicalise each bot's display name now, so UIs that persist
  // bot-names between sessions (Telegram /mybots) don't carry stale
  // labels from previous rename events.
  for (const [role, idx] of roleBotMap) {
    try {
      await poolApis[idx].setMyName(role);
      logger.info({ role, poolIndex: idx }, 'Pool bot canonical name set');
    } catch (err) {
      logger.warn({ role, err }, 'Failed to canonicalise pool bot name');
    }
  }
  if (poolApis.length > 0) {
    logger.info(
      { count: poolApis.length, canonicalRoles: roleBotMap.size },
      'Telegram bot pool ready',
    );
  }
}

/**
 * Send a message from a pool bot assigned to `sender`. Uses deterministic
 * role→bot mapping when configured (via TELEGRAM_BOT_POOL_ROLES); falls back
 * to round-robin for ad-hoc senders. Falls back to main bot if no pool.
 */
export async function sendPoolMessage(
  chatId: string,
  text: string,
  sender: string,
  groupFolder: string,
  fallback: (chatId: string, text: string) => Promise<void>,
): Promise<void> {
  if (poolApis.length === 0) {
    await fallback(chatId, text);
    return;
  }
  // Deterministic: known role maps to a fixed pool index regardless of
  // arrival order. Bot was already renamed to this role at initBotPool,
  // so no setMyName/delay needed here — send immediately.
  let idx = roleBotMap.get(sender);
  if (idx !== undefined) {
    // no-op: display name, avatar and username all stable
  } else {
    // Fallback: round-robin cache per (group, sender).
    const key = `${groupFolder}:${sender}`;
    idx = senderBotMap.get(key);
    if (idx === undefined) {
      idx = nextPoolIndex % poolApis.length;
      nextPoolIndex++;
      senderBotMap.set(key, idx);
      try {
        await poolApis[idx].setMyName(sender);
        // Small delay lets Telegram propagate the name change before the
        // first message arrives; otherwise the first post can appear from
        // the old bot name.
        await new Promise((r) => setTimeout(r, 2000));
        logger.info(
          { sender, groupFolder, poolIndex: idx },
          'Assigned and renamed pool bot (round-robin fallback)',
        );
      } catch (err) {
        logger.warn(
          { sender, err },
          'Failed to rename pool bot (sending anyway)',
        );
      }
    }
  }
  const api = poolApis[idx];
  const numericId = chatId.replace(/^tg:/, '');
  const MAX_LENGTH = 4096;
  // Try Telegram Markdown v1 first (matches what Mila's CLAUDE.md teaches
  // pool-sender agents: single *bold*, _italic_, `code`); on failure, fall
  // back to plain so a bad markdown sequence doesn't silence the bot.
  const sendChunk = async (chunk: string): Promise<void> => {
    try {
      await api.sendMessage(numericId, chunk, { parse_mode: 'Markdown' });
    } catch (err) {
      logger.debug(
        { sender, err },
        'Pool Markdown send failed, retrying as plain text',
      );
      await api.sendMessage(numericId, chunk);
    }
  };
  try {
    if (text.length <= MAX_LENGTH) {
      await sendChunk(text);
    } else {
      for (let i = 0; i < text.length; i += MAX_LENGTH) {
        await sendChunk(text.slice(i, i + MAX_LENGTH));
      }
    }
    logger.info(
      { chatId, sender, poolIndex: idx, length: text.length },
      'Pool message sent',
    );
  } catch (err) {
    logger.error({ chatId, sender, err }, 'Failed to send pool message');
  }
}

/**
 * Send a message with Telegram Markdown parse mode, falling back to plain text.
 * Claude's output naturally matches Telegram's Markdown v1 format:
 *   *bold*, _italic_, `code`, ```code blocks```, [links](url)
 */
async function sendTelegramMessage(
  api: { sendMessage: Api['sendMessage'] },
  chatId: string | number,
  text: string,
  options: { message_thread_id?: number } = {},
): Promise<void> {
  try {
    await api.sendMessage(chatId, text, {
      ...options,
      parse_mode: 'Markdown',
    });
  } catch (err) {
    // Fallback: send as plain text if Markdown parsing fails
    logger.debug({ err }, 'Markdown send failed, falling back to plain text');
    await api.sendMessage(chatId, text, options);
  }
}

export class TelegramChannel implements Channel {
  name = 'telegram';

  private bot: Bot | null = null;
  private opts: TelegramChannelOpts;
  private botToken: string;
  private botId: number | null = null;

  constructor(botToken: string, opts: TelegramChannelOpts) {
    this.botToken = botToken;
    this.opts = opts;
  }

  /**
   * Download a Telegram file to the group's attachments directory.
   * Returns the container-relative path (e.g. /workspace/group/attachments/photo_123.jpg)
   * or null if the download fails.
   */
  /**
   * Download a Telegram file via Bot API (<20MB) or fall back to MTProto
   * via Telegram Scanner for large files (video, audio).
   */
  private async downloadFile(
    fileId: string,
    groupFolder: string,
    filename: string,
    mtprotoFallback?: { chatId: number; messageId: number },
  ): Promise<string | null> {
    if (!this.bot) return null;

    const groupDir = resolveGroupFolderPath(groupFolder);
    const attachDir = path.join(groupDir, 'attachments');
    fs.mkdirSync(attachDir, { recursive: true });

    // Try Bot API first (works for files <20MB)
    try {
      const file = await this.bot.api.getFile(fileId);
      if (!file.file_path) {
        logger.warn({ fileId }, 'Telegram getFile returned no file_path');
        // Fall through to MTProto fallback
      } else {
        const tgExt = path.extname(file.file_path);
        const localExt = path.extname(filename);
        const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
        const finalName = localExt ? safeName : `${safeName}${tgExt}`;
        const destPath = path.join(attachDir, finalName);

        const fileUrl = `https://api.telegram.org/file/bot${this.botToken}/${file.file_path}`;
        const resp = await fetch(fileUrl);
        if (resp.ok) {
          const buffer = Buffer.from(await resp.arrayBuffer());
          fs.writeFileSync(destPath, buffer);
          logger.info(
            { fileId, dest: destPath },
            'Telegram file downloaded via Bot API',
          );
          return `/workspace/group/attachments/${finalName}`;
        }
        logger.warn(
          { fileId, status: resp.status },
          'Telegram file download failed via Bot API',
        );
      }
    } catch (err: any) {
      // Bot API getFile fails with 400 for files >20MB
      const errMsg = err?.message || String(err);
      if (errMsg.includes('file is too big') || errMsg.includes('400')) {
        logger.info(
          { fileId },
          'File too large for Bot API (>20MB), trying MTProto fallback',
        );
      } else {
        logger.error({ fileId, err }, 'Failed to download via Bot API');
      }
    }

    // MTProto fallback via Telegram Scanner (no size limit)
    if (mtprotoFallback) {
      try {
        const scannerPort = process.env.TELEGRAM_SCANNER_PORT || '3002';
        const scannerUrl = `http://localhost:${scannerPort}/mcp`;
        const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');

        // Initialize MCP session
        const initResp = await fetch(scannerUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json, text/event-stream',
          },
          body: JSON.stringify({
            jsonrpc: '2.0',
            id: 1,
            method: 'initialize',
            params: {
              protocolVersion: '2025-03-26',
              capabilities: {},
              clientInfo: { name: 'nanoclaw', version: '1.0' },
            },
          }),
        });
        const initText = await initResp.text();
        const sessionMatch = initResp.headers.get('mcp-session-id');

        if (!sessionMatch) {
          logger.warn('MTProto fallback: no MCP session ID');
          return null;
        }

        // Call download_media tool
        const callResp = await fetch(scannerUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json, text/event-stream',
            'Mcp-Session-Id': sessionMatch,
          },
          body: JSON.stringify({
            jsonrpc: '2.0',
            id: 2,
            method: 'tools/call',
            params: {
              name: 'download_media',
              arguments: {
                chat_id: String(mtprotoFallback.chatId),
                message_id: mtprotoFallback.messageId,
                dest_dir: attachDir,
                filename: safeName,
              },
            },
          }),
        });

        const callText = await callResp.text();
        // Parse SSE response — extract JSON from "data:" line
        const dataMatch = callText.match(/data:\s*({.*})/);
        if (dataMatch) {
          const rpcResult = JSON.parse(dataMatch[1]);
          const content = rpcResult?.result?.content?.[0]?.text;
          if (content) {
            const result = JSON.parse(content);
            if (result.path && !result.error) {
              const downloadedName = path.basename(result.path);
              logger.info(
                { fileId, path: result.path, size: result.size },
                'File downloaded via MTProto fallback',
              );
              return `/workspace/group/attachments/${downloadedName}`;
            }
            logger.warn(
              { fileId, error: result.error },
              'MTProto download_media returned error',
            );
          }
        }
        logger.warn({ fileId }, 'MTProto fallback: could not parse response');
      } catch (err) {
        logger.error({ fileId, err }, 'MTProto fallback failed');
      }
    }

    return null;
  }

  async connect(): Promise<void> {
    this.bot = new Bot(this.botToken, {
      client: {
        baseFetchConfig: { agent: https.globalAgent, compress: true },
      },
    });

    // Command to get chat ID (useful for registration)
    this.bot.command('chatid', (ctx) => {
      const chatId = ctx.chat.id;
      const chatType = ctx.chat.type;
      const chatName =
        chatType === 'private'
          ? ctx.from?.first_name || 'Private'
          : (ctx.chat as any).title || 'Unknown';

      ctx.reply(
        `Chat ID: \`tg:${chatId}\`\nName: ${chatName}\nType: ${chatType}`,
        { parse_mode: 'Markdown' },
      );
    });

    // Command to check bot status
    this.bot.command('ping', (ctx) => {
      ctx.reply(`${ASSISTANT_NAME} is online.`);
    });

    // Welcome handler for new users — works for ANY chat, not just registered
    // groups. Critical for Telegram Ads: ads link to ?start=<payload>, and
    // Telegram's ad review bot sends /start to verify the bot responds.
    // After sending the quick welcome, auto-registers private chats so the
    // next message gets full AI processing (sales funnel mode).
    this.bot.command('start', async (ctx) => {
      const payload = ctx.match; // deep link parameter (?start=uz, ?start=expert etc.)

      const messages: Record<string, string> = {
        uz: `Salom! Men ${ASSISTANT_NAME} — Shahruz Ashot Ashirovning AI-yordamchisiman. Biznesingizni bepul tahlil qilib, AI qanday mijozlarni jalb qilishga yordam berishini ko'rsataman. Bir soniya...`,
        expert: `Привет! Я ${ASSISTANT_NAME} — ассистент Шахруза Ашота. Поможем упаковать вашу экспертизу в онлайн-курс с помощью ИИ. Секунду...`,
        business: `Привет! Я ${ASSISTANT_NAME} — ассистент Шахруза Ашота, эксперта по ИИ для бизнеса. Могу бесплатно проанализировать ваш бизнес и подсказать точки роста. Секунду...`,
        startup: `Привет! Я ${ASSISTANT_NAME} — ассистент Шахруза Ашота. Покажем как запустить AI-воронку продаж для вашего стартапа. Секунду...`,
        marketer: `Привет! Я ${ASSISTANT_NAME} — ассистент Шахруза Ашота. Расскажу как AI-инструменты усилят ваш маркетинг. Секунду...`,
        freelancer: `Привет! Я ${ASSISTANT_NAME} — ассистент Шахруза Ашота. Помогу автоматизировать привлечение клиентов для вашего фриланса. Секунду...`,
      };

      const text =
        (payload && messages[payload]) ||
        `Привет! Я ${ASSISTANT_NAME} — ассистент эксперта по ИИ Шахруза Ашота Аширова. Секунду, подготовлю для вас информацию...`;

      await ctx.reply(text);

      // Send typing indicator so user knows we're preparing a response
      await ctx.api.sendChatAction(ctx.chat.id, 'typing').catch(() => {});

      // Auto-register private chats as public leads for full AI conversation
      const chatJid = `tg:${ctx.chat.id}`;
      if (ctx.chat.type === 'private' && this.opts.onAutoRegister) {
        const senderName =
          ctx.from?.first_name ||
          ctx.from?.username ||
          ctx.from?.id.toString() ||
          'Lead';
        this.opts.onAutoRegister(
          chatJid,
          senderName,
          ctx.from?.id,
          ctx.from?.language_code,
          payload || undefined,
        );

        // Store the /start as the first message so the agent sees it
        const group = this.opts.registeredGroups()[chatJid];
        if (group) {
          const startContent = payload
            ? `[System: New lead from Telegram Ads, deep link: ?start=${payload}. Welcome message already sent — do NOT greet again. Start with qualification question.]\n/start ${payload}`
            : `[System: New user started the bot. Welcome message already sent — do NOT greet again. Start with qualification question (Шаг 1 из CLAUDE.md).]\n/start`;
          this.opts.onMessage(chatJid, {
            id: ctx.message?.message_id?.toString() || Date.now().toString(),
            chat_jid: chatJid,
            sender: ctx.from?.id.toString() || '',
            sender_name: senderName,
            content: startContent,
            timestamp: ctx.message
              ? new Date(ctx.message.date * 1000).toISOString()
              : new Date().toISOString(),
            is_from_me: false,
          });
        }
      }

      logger.info(
        { chatId: ctx.chat.id, payload: payload || '(none)' },
        'Telegram /start handled',
      );
    });

    // Telegram bot commands handled above — skip them in the general handler
    // so they don't also get stored as messages. All other /commands flow through.
    const TELEGRAM_BOT_COMMANDS = new Set(['chatid', 'ping', 'start']);

    this.bot.on('message:text', async (ctx) => {
      if (ctx.message.text.startsWith('/')) {
        const cmd = ctx.message.text.slice(1).split(/[\s@]/)[0].toLowerCase();
        if (TELEGRAM_BOT_COMMANDS.has(cmd)) return;
      }

      const chatJid = `tg:${ctx.chat.id}`;
      let content = ctx.message.text;
      const timestamp = new Date(ctx.message.date * 1000).toISOString();
      const senderName =
        ctx.from?.first_name ||
        ctx.from?.username ||
        ctx.from?.id.toString() ||
        'Unknown';
      const sender = ctx.from?.id.toString() || '';
      const msgId = ctx.message.message_id.toString();
      const threadId = ctx.message.message_thread_id;

      const replyTo = ctx.message.reply_to_message;
      const replyToMessageId = replyTo?.message_id?.toString();
      const replyToContent = replyTo?.text || replyTo?.caption;
      const replyToSenderName = replyTo
        ? replyTo.from?.first_name ||
          replyTo.from?.username ||
          replyTo.from?.id?.toString() ||
          'Unknown'
        : undefined;

      // Determine chat name
      const chatName =
        ctx.chat.type === 'private'
          ? senderName
          : (ctx.chat as any).title || chatJid;

      // Translate Telegram @bot_username mentions into TRIGGER_PATTERN format.
      // Telegram @mentions (e.g., @andy_ai_bot) won't match TRIGGER_PATTERN
      // (e.g., ^@Andy\b), so we prepend the trigger when the bot is @mentioned.
      const botUsername = ctx.me?.username?.toLowerCase();
      if (botUsername) {
        const entities = ctx.message.entities || [];
        const isBotMentioned = entities.some((entity) => {
          if (entity.type === 'mention') {
            const mentionText = content
              .substring(entity.offset, entity.offset + entity.length)
              .toLowerCase();
            return mentionText === `@${botUsername}`;
          }
          return false;
        });
        if (isBotMentioned && !TRIGGER_PATTERN.test(content)) {
          content = `@${ASSISTANT_NAME} ${content}`;
        }
      }

      // Store chat metadata for discovery
      const isGroup =
        ctx.chat.type === 'group' || ctx.chat.type === 'supergroup';
      this.opts.onChatMetadata(
        chatJid,
        timestamp,
        chatName,
        'telegram',
        isGroup,
      );

      // Deliver full message for registered groups. For unregistered private
      // chats (leads from ads), auto-register first then deliver.
      let group = this.opts.registeredGroups()[chatJid];
      if (!group && ctx.chat.type === 'private' && this.opts.onAutoRegister) {
        this.opts.onAutoRegister(
          chatJid,
          senderName,
          ctx.from?.id,
          ctx.from?.language_code,
        );
        group = this.opts.registeredGroups()[chatJid];
      }
      if (!group) {
        logger.debug(
          { chatJid, chatName },
          'Message from unregistered Telegram chat',
        );
        return;
      }

      // Deliver message — startMessageLoop() will pick it up
      this.opts.onMessage(chatJid, {
        id: msgId,
        chat_jid: chatJid,
        sender,
        sender_name: senderName,
        content,
        timestamp,
        is_from_me: false,
        thread_id: threadId ? threadId.toString() : undefined,
        reply_to_message_id: replyToMessageId,
        reply_to_message_content: replyToContent,
        reply_to_sender_name: replyToSenderName,
      });

      logger.info(
        { chatJid, chatName, sender: senderName },
        'Telegram message stored',
      );
    });

    // Handle non-text messages: download files when possible, fall back to placeholders.
    // For large files (>20MB), falls back to MTProto via Telegram Scanner.
    const storeMedia = (
      ctx: any,
      placeholder: string,
      opts?: { fileId?: string; filename?: string },
    ) => {
      const chatJid = `tg:${ctx.chat.id}`;
      const group = this.opts.registeredGroups()[chatJid];
      if (!group) return;

      const timestamp = new Date(ctx.message.date * 1000).toISOString();
      const senderName =
        ctx.from?.first_name ||
        ctx.from?.username ||
        ctx.from?.id?.toString() ||
        'Unknown';
      const caption = ctx.message.caption ? ` ${ctx.message.caption}` : '';

      const isGroup =
        ctx.chat.type === 'group' || ctx.chat.type === 'supergroup';
      this.opts.onChatMetadata(
        chatJid,
        timestamp,
        undefined,
        'telegram',
        isGroup,
      );

      const deliver = (content: string) => {
        this.opts.onMessage(chatJid, {
          id: ctx.message.message_id.toString(),
          chat_jid: chatJid,
          sender: ctx.from?.id?.toString() || '',
          sender_name: senderName,
          content,
          timestamp,
          is_from_me: false,
        });
      };

      // If we have a file_id, attempt to download; deliver asynchronously
      // Pass MTProto fallback context for large files (>20MB Bot API limit)
      if (opts?.fileId) {
        const msgId = ctx.message.message_id.toString();
        const filename =
          opts.filename ||
          `${placeholder.replace(/[\[\] ]/g, '').toLowerCase()}_${msgId}`;
        const mtprotoFallback = {
          chatId: ctx.chat.id,
          messageId: ctx.message.message_id,
        };
        this.downloadFile(
          opts.fileId,
          group.folder,
          filename,
          mtprotoFallback,
        ).then((filePath) => {
          if (filePath) {
            deliver(`${placeholder} (${filePath})${caption}`);
          } else {
            deliver(`${placeholder}${caption}`);
          }
        });
        return;
      }

      deliver(`${placeholder}${caption}`);
    };

    this.bot.on('message:photo', async (ctx) => {
      // Telegram sends multiple sizes; last is largest. Download → resize via
      // sharp → emit `[Image: attachments/img-X.jpg]` marker so the agent
      // sees the image as a multimodal content block (not just a path).
      const chatJid = `tg:${ctx.chat.id}`;
      const group = this.opts.registeredGroups()[chatJid];
      if (!group) return;

      const photos = ctx.message.photo;
      const largest = photos?.[photos.length - 1];
      const fileId = largest?.file_id;
      const timestamp = new Date(ctx.message.date * 1000).toISOString();
      const senderName =
        ctx.from?.first_name ||
        ctx.from?.username ||
        ctx.from?.id?.toString() ||
        'Unknown';
      const caption = ctx.message.caption || '';

      const isGroup =
        ctx.chat.type === 'group' || ctx.chat.type === 'supergroup';
      this.opts.onChatMetadata(
        chatJid,
        timestamp,
        undefined,
        'telegram',
        isGroup,
      );

      const deliver = (content: string) => {
        this.opts.onMessage(chatJid, {
          id: ctx.message.message_id.toString(),
          chat_jid: chatJid,
          sender: ctx.from?.id?.toString() || '',
          sender_name: senderName,
          content,
          timestamp,
          is_from_me: false,
        });
      };

      if (!fileId) {
        deliver(`[Photo]${caption ? ' ' + caption : ''}`);
        return;
      }

      // Download to attachments/photo_<msgId>.jpg
      const containerPath = await this.downloadFile(
        fileId,
        group.folder,
        `photo_${ctx.message.message_id}`,
      );
      if (!containerPath) {
        deliver(`[Photo]${caption ? ' ' + caption : ''}`);
        return;
      }

      // Translate container path -> host path so sharp can read it
      const groupDir = resolveGroupFolderPath(group.folder);
      const hostPath = path.join(
        groupDir,
        containerPath.replace('/workspace/group/', ''),
      );

      try {
        const processed = await processImageFile(hostPath, groupDir, {
          caption,
          deleteSource: true,
        });
        if (processed) {
          logger.info(
            { fileId, relativePath: processed.relativePath },
            'Telegram image processed for vision',
          );
          deliver(processed.marker);
        } else {
          deliver(`[Photo]${caption ? ' ' + caption : ''}`);
        }
      } catch (err) {
        logger.warn(
          { err, hostPath },
          'Image processing failed; falling back to plain photo marker',
        );
        deliver(`[Photo] (${containerPath})${caption ? ' ' + caption : ''}`);
      }
    });
    this.bot.on('message:video', (ctx) => {
      storeMedia(ctx, '[Video]', {
        fileId: ctx.message.video?.file_id,
        filename: `video_${ctx.message.message_id}`,
      });
    });
    this.bot.on('message:voice', (ctx) => {
      storeMedia(ctx, '[Voice message]', {
        fileId: ctx.message.voice?.file_id,
        filename: `voice_${ctx.message.message_id}`,
      });
    });
    this.bot.on('message:audio', (ctx) => {
      const name =
        ctx.message.audio?.file_name || `audio_${ctx.message.message_id}`;
      storeMedia(ctx, '[Audio]', {
        fileId: ctx.message.audio?.file_id,
        filename: name,
      });
    });
    this.bot.on('message:document', (ctx) => {
      const name = ctx.message.document?.file_name || 'file';
      storeMedia(ctx, `[Document: ${name}]`, {
        fileId: ctx.message.document?.file_id,
        filename: name,
      });
    });
    this.bot.on('message:sticker', (ctx) => {
      const emoji = ctx.message.sticker?.emoji || '';
      storeMedia(ctx, `[Sticker ${emoji}]`);
    });
    this.bot.on('message:location', (ctx) => storeMedia(ctx, '[Location]'));
    this.bot.on('message:contact', (ctx) => storeMedia(ctx, '[Contact]'));

    // Two-way emoji reactions channel — see
    // groups/<group>/skills/telegram-reactions/SKILL.md for the full spec.
    // Delivers newly added emoji reactions from registered chats as
    // synthetic messages `[Reaction: X] on message Y` that the agent
    // interprets as commands. Bot's own reactions are filtered out so
    // Mila doesn't echo her own status signals as incoming commands.
    this.bot.on('message_reaction', async (ctx) => {
      const chatJid = `tg:${ctx.chat.id}`;
      const group = this.opts.registeredGroups()[chatJid];
      if (!group) return;

      const reaction = ctx.messageReaction;
      if (!reaction) return;

      // Filter out the bot's own reactions — Telegram sometimes echoes them
      // back as message_reaction updates (depending on polling config).
      const user = reaction.user;
      const reactorId = user?.id;
      if (this.botId != null && reactorId === this.botId) return;

      const timestamp = new Date(reaction.date * 1000).toISOString();
      const senderName = user
        ? user.first_name || user.username || user.id.toString()
        : 'Unknown';
      const sender = reactorId != null ? reactorId.toString() : '';

      // Only deliver NEWLY added emojis (set difference new - old). Removed
      // reactions are ignored — we don't model un-reactions as commands.
      // grammy narrows `r.emoji` to the allowed-whitelist literal union when
      // `r.type === 'emoji'`, which widens to `string` on assignment.
      const oldEmojis = new Set<string>();
      for (const r of reaction.old_reaction || []) {
        if (r.type === 'emoji') oldEmojis.add(r.emoji);
      }
      const addedEmojis: string[] = [];
      for (const r of reaction.new_reaction || []) {
        if (r.type === 'emoji' && !oldEmojis.has(r.emoji)) {
          addedEmojis.push(r.emoji);
        }
      }

      if (addedEmojis.length === 0) return;

      const isGroup =
        ctx.chat.type === 'group' || ctx.chat.type === 'supergroup';
      this.opts.onChatMetadata(
        chatJid,
        timestamp,
        undefined,
        'telegram',
        isGroup,
      );

      for (const emoji of addedEmojis) {
        this.opts.onMessage(chatJid, {
          id: `reaction-${reaction.message_id}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
          chat_jid: chatJid,
          sender,
          sender_name: senderName,
          content: `[Reaction: ${emoji}] on message ${reaction.message_id}`,
          timestamp,
          is_from_me: false,
        });
      }
    });

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
      const origMsgId = ctx.callbackQuery.message?.message_id?.toString() ?? '';
      const timestamp = new Date().toISOString();
      const senderName =
        ctx.from?.first_name ||
        ctx.from?.username ||
        ctx.from?.id.toString() ||
        'Unknown';
      const sender = ctx.from?.id.toString() ?? '';

      // admin-ipc callbacks: `admin:<approve|deny>:<req-id>` — write decision
      // file to groups/global/admin-ipc/decisions/ for mila-admin (Claude Code)
      // to pick up; don't forward to onMessage (main agent shouldn't handle).
      if (data.startsWith('admin:')) {
        const [, decision, reqId] = data.split(':');
        if (
          reqId &&
          (decision === 'approve' || decision === 'deny') &&
          /^req-[a-z0-9-]+$/i.test(reqId)
        ) {
          try {
            const fs = await import('fs');
            const path = await import('path');
            const decisionsDir = path.join(
              process.cwd(),
              'groups',
              'global',
              'admin-ipc',
              'decisions',
            );
            fs.mkdirSync(decisionsDir, { recursive: true });
            const decisionFile = path.join(decisionsDir, `${reqId}.json`);
            fs.writeFileSync(
              decisionFile,
              JSON.stringify(
                {
                  request_id: reqId,
                  decision,
                  decided_by: sender,
                  decided_by_name: senderName,
                  decided_at: timestamp,
                  via: 'telegram_inline_button',
                  original_message_id: origMsgId,
                },
                null,
                2,
              ),
            );
            // edit the original message to reflect decision
            const label =
              decision === 'approve' ? '✅ Одобрено' : '❌ Отказано';
            try {
              await ctx.editMessageReplyMarkup({
                reply_markup: { inline_keyboard: [] },
              });
              await ctx.reply(`${label}: ${reqId}`, {
                reply_parameters: { message_id: Number(origMsgId) },
              });
            } catch (err) {
              logger.debug(
                { err, reqId },
                'Failed to edit admin-ipc decision message',
              );
            }
            logger.info(
              { reqId, decision, sender: senderName },
              'admin-ipc decision recorded',
            );
          } catch (err) {
            logger.error(
              { err, reqId },
              'Failed to write admin-ipc decision file',
            );
          }
        }
        return; // don't forward admin:* callbacks to onMessage
      }

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

    // Handle errors gracefully
    this.bot.catch((err) => {
      logger.error({ err: err.message }, 'Telegram bot error');
    });

    // Start polling — returns a Promise that resolves when started.
    // `allowed_updates` must explicitly include `message_reaction`; grammy's
    // default set doesn't include it, so reactions wouldn't arrive otherwise.
    return new Promise<void>((resolve) => {
      this.bot!.start({
        allowed_updates: [
          'message',
          'edited_message',
          'callback_query',
          'message_reaction',
        ],
        onStart: (botInfo) => {
          this.botId = botInfo.id;
          logger.info(
            { username: botInfo.username, id: botInfo.id },
            'Telegram bot connected',
          );
          console.log(`\n  Telegram bot: @${botInfo.username}`);
          console.log(
            `  Send /chatid to the bot to get a chat's registration ID\n`,
          );
          resolve();
        },
      });
    });
  }

  /**
   * Send an emoji reaction to a specific message. Used by the
   * `react_to_message` MCP tool so the agent can signal status (👀 / ⚡ /
   * 👏 / 💔 etc.) without a full text reply. Telegram only allows a fixed
   * whitelist of emoji for reactions; unsupported emoji will produce a
   * `REACTION_INVALID` error which we log at warn level so the set can be
   * tuned over time.
   */
  async reactToMessage(
    jid: string,
    messageId: string,
    emoji: string,
  ): Promise<void> {
    if (!this.bot) {
      logger.warn('Telegram bot not initialized (reactToMessage)');
      return;
    }
    try {
      const numericChatId = Number(jid.replace(/^tg:/, ''));
      const numericMsgId = Number.parseInt(messageId, 10);
      if (Number.isNaN(numericChatId) || Number.isNaN(numericMsgId)) {
        logger.warn(
          { jid, messageId },
          'reactToMessage: invalid chat or message id',
        );
        return;
      }
      await this.bot.api.setMessageReaction(numericChatId, numericMsgId, [
        { type: 'emoji', emoji: emoji as never },
      ]);
      logger.info({ jid, messageId, emoji }, 'Telegram reaction sent');
    } catch (err) {
      logger.warn(
        { jid, messageId, emoji, err },
        'Failed to send Telegram reaction (likely REACTION_INVALID — emoji not in Bot API whitelist)',
      );
    }
  }

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
          if (btn.icon_custom_emoji_id)
            buttonObj.icon_custom_emoji_id = btn.icon_custom_emoji_id;
          return buttonObj;
        }),
      );
      await this.bot.api.sendMessage(numericId, text, {
        parse_mode: 'Markdown',
        reply_markup: { inline_keyboard } as never,
      });
      logger.info(
        { jid, rows: buttons.length },
        'Telegram message with buttons sent',
      );
    } catch (err) {
      // Fallback: send as plain text without buttons
      logger.warn(
        { jid, err },
        'Failed to send Telegram message with buttons, falling back',
      );
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
        logger.error(
          { jid, fallbackErr },
          'Failed to send Telegram fallback message',
        );
      }
    }
  }

  async sendFile(
    jid: string,
    filePath: string,
    caption?: string,
  ): Promise<void> {
    if (!this.bot) {
      logger.warn('Telegram bot not initialized (sendFile)');
      return;
    }
    try {
      const numericId = jid.replace(/^tg:/, '');
      const ext = path.extname(filePath).toLowerCase();
      const isPhoto = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext);

      if (isPhoto) {
        await this.bot.api.sendPhoto(
          numericId,
          new InputFile(filePath),
          caption ? { caption, parse_mode: 'Markdown' } : undefined,
        );
      } else {
        await this.bot.api.sendDocument(
          numericId,
          new InputFile(filePath),
          caption ? { caption, parse_mode: 'Markdown' } : undefined,
        );
      }
      logger.info({ jid, filePath, isPhoto }, 'Telegram file sent');
    } catch (err) {
      logger.error({ jid, filePath, err }, 'Failed to send Telegram file');
    }
  }

  async sendMessage(
    jid: string,
    text: string,
    threadId?: string,
  ): Promise<void> {
    if (!this.bot) {
      logger.warn('Telegram bot not initialized');
      return;
    }

    try {
      const numericId = jid.replace(/^tg:/, '');
      const options = threadId
        ? { message_thread_id: parseInt(threadId, 10) }
        : {};

      // Telegram has a 4096 character limit per message — split if needed
      const MAX_LENGTH = 4096;
      if (text.length <= MAX_LENGTH) {
        await sendTelegramMessage(this.bot.api, numericId, text, options);
      } else {
        for (let i = 0; i < text.length; i += MAX_LENGTH) {
          await sendTelegramMessage(
            this.bot.api,
            numericId,
            text.slice(i, i + MAX_LENGTH),
            options,
          );
        }
      }
      logger.info(
        { jid, length: text.length, threadId },
        'Telegram message sent',
      );
    } catch (err) {
      logger.error({ jid, err }, 'Failed to send Telegram message');
    }
  }

  isConnected(): boolean {
    return this.bot !== null;
  }

  ownsJid(jid: string): boolean {
    return jid.startsWith('tg:');
  }

  async disconnect(): Promise<void> {
    if (this.bot) {
      this.bot.stop();
      this.bot = null;
      logger.info('Telegram bot stopped');
    }
  }

  async setTyping(jid: string, isTyping: boolean): Promise<void> {
    if (!this.bot || !isTyping) return;
    try {
      const numericId = jid.replace(/^tg:/, '');
      await this.bot.api.sendChatAction(numericId, 'typing');
    } catch (err) {
      logger.debug({ jid, err }, 'Failed to send Telegram typing indicator');
    }
  }
}

registerChannel('telegram', (opts: ChannelOpts) => {
  const envVars = readEnvFile([
    'TELEGRAM_BOT_TOKEN',
    'TELEGRAM_BOT_POOL',
    'TELEGRAM_BOT_POOL_ROLES',
  ]);
  const token =
    process.env.TELEGRAM_BOT_TOKEN || envVars.TELEGRAM_BOT_TOKEN || '';
  if (!token) {
    logger.warn('Telegram: TELEGRAM_BOT_TOKEN not set');
    return null;
  }
  const channel = new TelegramChannel(token, opts);

  // Agent-team bot pool. Tokens are comma-separated in TELEGRAM_BOT_POOL.
  // Optional TELEGRAM_BOT_POOL_ROLES in the SAME ORDER assigns a canonical
  // role name to each token — e.g. tokens[0] → "Маркетолог" always, so
  // display name + avatar + username stay stable across restarts and
  // spawn orders. Unset roles fall back to round-robin at send time.
  const poolRaw =
    process.env.TELEGRAM_BOT_POOL || envVars.TELEGRAM_BOT_POOL || '';
  const rolesRaw =
    process.env.TELEGRAM_BOT_POOL_ROLES ||
    envVars.TELEGRAM_BOT_POOL_ROLES ||
    '';
  const poolTokens = poolRaw
    .split(',')
    .map((t) => t.trim())
    .filter(Boolean);
  const poolRoles = rolesRaw.split(',').map((r) => r.trim());
  if (poolTokens.length > 0) {
    // Fire-and-forget — pool init is async but we don't need to block
    // channel registration on it. Callers will fall back to the main bot
    // until the pool is ready.
    void initBotPool(poolTokens, poolRoles);
  }
  return channel;
});
