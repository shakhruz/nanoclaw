/**
 * Core MCP tools: send_message, send_file, edit_message, add_reaction.
 *
 * All outbound tools resolve destinations via the local destination map
 * (see destinations.ts). Agents reference destinations by name; the map
 * translates name → routing tuple. Permission enforcement happens on
 * the host side in delivery.ts via the agent_destinations table.
 */
import fs from 'fs';
import path from 'path';

import { findByName, getAllDestinations } from '../destinations.js';
import { getMessageIdBySeq, getRoutingBySeq, writeMessageOut } from '../db/messages-out.js';
import { getSessionRouting } from '../db/session-routing.js';
import { registerTools } from './server.js';
import type { McpToolDefinition } from './types.js';

function log(msg: string): void {
  console.error(`[mcp-tools] ${msg}`);
}

function generateId(): string {
  return `msg-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function ok(text: string) {
  return { content: [{ type: 'text' as const, text }] };
}

function err(text: string) {
  return { content: [{ type: 'text' as const, text: `Error: ${text}` }], isError: true };
}

function destinationList(): string {
  const all = getAllDestinations();
  if (all.length === 0) return '(none)';
  return all.map((d) => d.name).join(', ');
}

/**
 * Resolve a destination name to routing fields.
 *
 * If `to` is omitted, use the session's default reply routing (channel +
 * thread the conversation is in) — the agent replies in place.
 *
 * If `to` is specified, look up the named destination. If it resolves to
 * the same channel the session is bound to, the session's thread_id is
 * preserved so replies land in the correct thread. Otherwise thread_id
 * is null (a cross-destination send starts a new conversation).
 */
function resolveRouting(
  to: string | undefined,
):
  | { channel_type: string; platform_id: string; thread_id: string | null; resolvedName: string }
  | { error: string } {
  if (!to) {
    // Default: reply to whatever thread/channel this session is bound to.
    const session = getSessionRouting();
    if (session.channel_type && session.platform_id) {
      return {
        channel_type: session.channel_type,
        platform_id: session.platform_id,
        thread_id: session.thread_id,
        resolvedName: '(current conversation)',
      };
    }
    // No session routing (e.g., agent-shared or internal-only agent) —
    // fall back to the legacy single-destination shortcut.
    const all = getAllDestinations();
    if (all.length === 0) return { error: 'No destinations configured.' };
    if (all.length > 1) {
      return {
        error: `You have multiple destinations — specify "to". Options: ${all.map((d) => d.name).join(', ')}`,
      };
    }
    to = all[0].name;
  }
  const dest = findByName(to);
  if (!dest) return { error: `Unknown destination "${to}". Known: ${destinationList()}` };
  if (dest.type === 'channel') {
    // If the destination is the same channel the session is bound to,
    // preserve the thread_id so replies land in the correct thread.
    const session = getSessionRouting();
    const threadId =
      session.channel_type === dest.channelType && session.platform_id === dest.platformId
        ? session.thread_id
        : null;
    return {
      channel_type: dest.channelType!,
      platform_id: dest.platformId!,
      thread_id: threadId,
      resolvedName: to,
    };
  }
  return { channel_type: 'agent', platform_id: dest.agentGroupId!, thread_id: null, resolvedName: to };
}

export const sendMessage: McpToolDefinition = {
  tool: {
    name: 'send_message',
    description:
      'Send a message to a named destination. If you have only one destination, you can omit `to`.',
    inputSchema: {
      type: 'object' as const,
      properties: {
        to: { type: 'string', description: 'Destination name (e.g., "family", "worker-1"). Optional if you have only one destination.' },
        text: { type: 'string', description: 'Message content' },
      },
      required: ['text'],
    },
  },
  async handler(args) {
    const text = args.text as string;
    if (!text) return err('text is required');

    const routing = resolveRouting(args.to as string | undefined);
    if ('error' in routing) return err(routing.error);

    const id = generateId();
    const seq = writeMessageOut({
      id,
      kind: 'chat',
      platform_id: routing.platform_id,
      channel_type: routing.channel_type,
      thread_id: routing.thread_id,
      content: JSON.stringify({ text }),
    });

    log(`send_message: #${seq} → ${routing.resolvedName}`);
    return ok(`Message sent to ${routing.resolvedName} (id: ${seq})`);
  },
};

export const sendFile: McpToolDefinition = {
  tool: {
    name: 'send_file',
    description: 'Send a file to a named destination. If you have only one destination, you can omit `to`.',
    inputSchema: {
      type: 'object' as const,
      properties: {
        to: { type: 'string', description: 'Destination name. Optional if you have only one destination.' },
        path: { type: 'string', description: 'File path (relative to /workspace/agent/ or absolute)' },
        text: { type: 'string', description: 'Optional accompanying message' },
        filename: { type: 'string', description: 'Display name (default: basename of path)' },
      },
      required: ['path'],
    },
  },
  async handler(args) {
    const filePath = args.path as string;
    if (!filePath) return err('path is required');

    const routing = resolveRouting(args.to as string | undefined);
    if ('error' in routing) return err(routing.error);

    const resolvedPath = path.isAbsolute(filePath) ? filePath : path.resolve('/workspace/agent', filePath);
    if (!fs.existsSync(resolvedPath)) return err(`File not found: ${filePath}`);

    const id = generateId();
    const filename = (args.filename as string) || path.basename(resolvedPath);

    const outboxDir = path.join('/workspace/outbox', id);
    fs.mkdirSync(outboxDir, { recursive: true });
    fs.copyFileSync(resolvedPath, path.join(outboxDir, filename));

    writeMessageOut({
      id,
      kind: 'chat',
      platform_id: routing.platform_id,
      channel_type: routing.channel_type,
      thread_id: routing.thread_id,
      content: JSON.stringify({ text: (args.text as string) || '', files: [filename] }),
    });

    log(`send_file: ${id} → ${routing.resolvedName} (${filename})`);
    return ok(`File sent to ${routing.resolvedName} (id: ${id}, filename: ${filename})`);
  },
};

export const editMessage: McpToolDefinition = {
  tool: {
    name: 'edit_message',
    description: 'Edit a previously sent message. Targets the same destination the original message was sent to.',
    inputSchema: {
      type: 'object' as const,
      properties: {
        messageId: { type: 'integer', description: 'Message ID (the numeric id shown in messages)' },
        text: { type: 'string', description: 'New message content' },
      },
      required: ['messageId', 'text'],
    },
  },
  async handler(args) {
    const seq = Number(args.messageId);
    const text = args.text as string;
    if (!seq || !text) return err('messageId and text are required');

    const platformId = getMessageIdBySeq(seq);
    if (!platformId) return err(`Message #${seq} not found`);

    const routing = getRoutingBySeq(seq);
    if (!routing || !routing.channel_type || !routing.platform_id) {
      return err(`Cannot determine destination for message #${seq}`);
    }

    const id = generateId();
    writeMessageOut({
      id,
      kind: 'chat',
      platform_id: routing.platform_id,
      channel_type: routing.channel_type,
      thread_id: routing.thread_id,
      content: JSON.stringify({ operation: 'edit', messageId: platformId, text }),
    });

    log(`edit_message: #${seq} → ${platformId}`);
    return ok(`Message edit queued for #${seq}`);
  },
};

// Telegram only accepts a fixed Unicode emoji set for setMessageReaction.
// Map common name aliases → actual Unicode so agents can pass either form.
const EMOJI_ALIAS: Record<string, string> = {
  thumbs_up: '👍', thumbsup: '👍', up: '👍', like: '👍', ok: '👍', good: '👍',
  thumbs_down: '👎', thumbsdown: '👎', down: '👎', bad: '👎', dislike: '👎',
  heart: '❤', love: '❤', heart_red: '❤',
  fire: '🔥', flame: '🔥', hot: '🔥',
  party: '🎉', tada: '🎉', celebrate: '🎉',
  eyes: '👀', looking: '👀', watch: '👀', seen: '👀', read: '👀',
  check: '✅', done: '✅', success: '✅',
  cross: '❌', x: '❌', no: '❌', fail: '❌',
  thinking: '🤔', hmm: '🤔', think: '🤔',
  wow: '🤯', mind_blown: '🤯',
  scream: '😱', shocked: '😱',
  cry: '😢', sad: '😢',
  angry: '🤬', mad: '🤬',
  pray: '🙏', please: '🙏', thanks: '🙏',
  clap: '👏', applause: '👏',
  rofl: '🤣', lol: '🤣', laugh: '🤣',
  cool: '🆒',
  hundred: '💯', '100': '💯',
  smile: '🙂', smiley: '😀', smiling: '😀', happy: '😀',
  sparkles: '✨', star: '✨',
  zap: '⚡', lightning: '⚡',
};

function normalizeReactionEmoji(input: string): string {
  // If already a real emoji (non-ASCII), pass through.
  if (/[^\x00-\x7F]/.test(input)) return input.trim();
  const key = input.trim().toLowerCase().replace(/[\s-]/g, '_');
  return EMOJI_ALIAS[key] ?? input;
}

export const addReaction: McpToolDefinition = {
  tool: {
    name: 'add_reaction',
    description:
      'Add an emoji reaction to a message. Pass the actual emoji character (e.g. "👍", "❤", "👀"). Common English names ("thumbs_up", "heart", "eyes", "check") are also accepted and translated. Telegram has a whitelist — non-whitelisted emoji are silently rejected by the platform.',
    inputSchema: {
      type: 'object' as const,
      properties: {
        messageId: { type: 'integer', description: 'Message ID (the numeric id shown in messages)' },
        emoji: {
          type: 'string',
          description:
            'Unicode emoji character or English alias. Examples: "👍" or "thumbs_up", "❤" or "heart", "👀" or "eyes", "✅" or "check", "🔥" or "fire", "🎉" or "party".',
        },
      },
      required: ['messageId', 'emoji'],
    },
  },
  async handler(args) {
    const seq = Number(args.messageId);
    const rawEmoji = args.emoji as string;
    if (!seq || !rawEmoji) return err('messageId and emoji are required');
    const emoji = normalizeReactionEmoji(rawEmoji);

    const platformId = getMessageIdBySeq(seq);
    if (!platformId) return err(`Message #${seq} not found`);

    const routing = getRoutingBySeq(seq);
    if (!routing || !routing.channel_type || !routing.platform_id) {
      return err(`Cannot determine destination for message #${seq}`);
    }

    const id = generateId();
    writeMessageOut({
      id,
      kind: 'chat',
      platform_id: routing.platform_id,
      channel_type: routing.channel_type,
      thread_id: routing.thread_id,
      content: JSON.stringify({ operation: 'reaction', messageId: platformId, emoji }),
    });

    log(`add_reaction: #${seq} → ${emoji} on ${platformId}`);
    return ok(`Reaction queued for #${seq} as ${emoji}`);
  },
};

registerTools([sendMessage, sendFile, editMessage, addReaction]);
