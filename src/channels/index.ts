// Channel self-registration barrel file.
// Each import triggers the channel module's registerChannel() call.

// discord

// gmail — channel mode disabled (tool-only mode).
// MCP tools (mcp__gmail__*) still work via container/agent-runner config;
// the channel itself does NOT auto-poll the inbox to avoid flooding the
// main chat with every incoming email. Re-enable by uncommenting if you
// want push notifications for new emails.
// import './gmail.js';

// slack

// telegram
import './telegram.js';

// whatsapp
