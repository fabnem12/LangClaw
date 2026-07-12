# LangClaw — Setup Instructions

A personal language learning setup with two OpenClaw agents:
- **Ana** — Romanian conversation partner & tutor
- **Lukas** — German conversation partner & tutor

Both connect through Discord and send proactive practice messages.

---

## Prerequisites

- A machine to run OpenClaw 24/7 (Mac mini, Raspberry Pi, VPS, or always-on laptop)
- Node.js 22+ (`node --version` to check)
- A Discord account
- An Anthropic API key (for Claude)

---

## Step 1: Install OpenClaw

```bash
npm install -g openclaw@latest
```

Verify:
```bash
openclaw --version
```

---

## Step 2: Create a Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it (e.g., "LangClaw")
3. Go to **Bot** in the sidebar
4. Under **Privileged Gateway Intents**, enable:
   - ✅ **Message Content Intent** (required)
   - ✅ **Server Members Intent** (recommended)
5. Click **Reset Token** → copy the token (save it somewhere safe)
6. Go to **OAuth2** → **URL Generator**
7. Enable scopes: `bot`, `applications.commands`
8. Under **Bot Permissions**, enable:
   - View Channels
   - Send Messages
   - Read Message History
   - Embed Links
   - Attach Files
   - Add Reactions
   - Send Messages in Threads
9. Copy the generated URL → open in browser → add bot to your server

---

## Step 3: Create Discord Channels

In your Discord server, create:
1. `#romanian` — for conversations with Ana
2. `#german` — for conversations with Lukas

---

## Step 4: Get Discord IDs

Enable **Developer Mode** in Discord (User Settings → Developer → toggle on).

Then:
- Right-click server name → **Copy Server ID** → this is your server ID
- Right-click `#romanian` → **Copy Channel ID** → this is your Romanian channel ID
- Right-click `#german` → **Copy Channel ID** → this is your German channel ID

---

## Step 5: Configure Secrets

Copy the template and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your actual values:

```bash
# Discord bot token (from Developer Portal → Bot → Reset Token)
DISCORD_BOT_TOKEN=your-actual-bot-token

# Discord server (guild) ID
DISCORD_SERVER_ID=123456789012345678

# Discord channel IDs
DISCORD_ROMANIAN_CHANNEL_ID=123456789012345678
DISCORD_GERMAN_CHANNEL_ID=123456789012345678

# Anthropic API key (from console.anthropic.com)
ANTHROPIC_API_KEY=sk-ant-...
```

---

## Step 6: Run Setup Script

The setup script reads `.env`, generates `openclaw.json`, creates progress files, and copies workspaces to `~/.openclaw/`. No manual copying needed.

```bash
./setup.sh
```

The script will:
1. Validate all required values in `.env`
2. Generate `openclaw.json` from the template with your credentials
3. Create initial progress files (vocabulary, engagement, grammar topics, etc.)
4. Copy workspaces to `~/.openclaw/`
5. Copy the shared conversation-partner skill to both workspaces

Generated files (`openclaw.json`, progress directories) are gitignored and never committed.

---

## Step 7: Install the Language Learning Skill

```bash
openclaw skills install @chipagosfinest/language-learning --global
```

---

## Step 8: Start OpenClaw

```bash
export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY .env | cut -d= -f2)
openclaw gateway
```

On first run, OpenClaw will:
1. Pair with Discord
2. Create agent sessions
3. Start the heartbeat system

---

## Step 9: Enable Heartbeats (Required for Proactive Messages)

By default, heartbeats are disabled (`"every": "0m"`). To receive proactive practice messages from Ana and Lukas, edit `~/.openclaw/openclaw.json` and change:

```json
"heartbeat": { "every": "0m" }
```

to:

```json
"heartbeat": { "every": "1h" }
```

This tells each agent to check HEARTBEAT.md once per hour. The agent then decides based on the time window and engagement state whether to send a message.

---

## Step 10: Set Up Cron Jobs (Proactive Messages)

Each agent needs one cron job that runs hourly during waking hours. The cron fires every hour from 7:00 to 22:00, and the agent uses HEARTBEAT.md to decide what to send (morning word, vocab quiz, conversation prompt, or review).

See the commands:

```bash
node cron-stagger.js setup
```

Then create the two cron jobs (one per language):

```bash
# Romanian (Ana)
openclaw cron create "0 7-22 * * *" \
  --name "LangClaw Ana hourly" \
  --tz "Europe/Berlin" \
  --agent romanian \
  --session isolated \
  --message "HEARTBEAT_CHECK: Read HEARTBEAT.md. Determine the current hour and map it to a time window. Check progress/engagement.json for engagement state. Follow the rules in HEARTBEAT.md to decide whether to send a proactive message. If you should not send, reply HEARTBEAT_OK." \
  --announce \
  --to "discord:YOUR_ROMANIAN_CHANNEL_ID"

# German (Lukas)
openclaw cron create "0 7-22 * * *" \
  --name "LangClaw Lukas hourly" \
  --tz "Europe/Berlin" \
  --agent german \
  --session isolated \
  --message "HEARTBEAT_CHECK: Read HEARTBEAT.md. Determine the current hour and map it to a time window. Check progress/engagement.json for engagement state. Follow the rules in HEARTBEAT.md to decide whether to send a proactive message. If you should not send, reply HEARTBEAT_OK." \
  --announce \
  --to "discord:YOUR_GERMAN_CHANNEL_ID"
```

Replace `YOUR_ROMANIAN_CHANNEL_ID` and `YOUR_GERMAN_CHANNEL_ID` with the actual IDs from your `.env` file.

The agent checks the current hour, maps it to a time window (morning/midday/afternoon/evening/night), and decides based on engagement patterns whether to send and what type of message.

---

## Step 11: Verify Everything Works

```bash
# Check OpenClaw status
openclaw status

# Check cron jobs
openclaw cron list

# Check logs if something isn't working
openclaw logs --follow
```

---

## Customization

### Change the model
Edit `openclaw.json` → `agents.defaults.model.primary`. Options:
- `anthropic/claude-sonnet-4-6` (default, good balance)
- `anthropic/claude-opus-4-8` (best quality, more expensive)
- `anthropic/claude-haiku-3-5` (cheaper, faster)

### Adjust proactive schedule
Edit the cron jobs:
```bash
openclaw cron edit <job-id> --cron "30 7-22 * * *" --tz "Europe/Berlin"
```

### Disable heartbeats
Set in `openclaw.json`:
```json
"heartbeat": { "every": "0m" }
```

### Change timezone
Replace `Europe/Berlin` with your timezone in cron commands and HEARTBEAT.md.

---

## Troubleshooting

### Bot doesn't respond in Discord
- Check that Message Content Intent is enabled in Developer Portal
- Verify the bot token in `.env` and re-run `./setup.sh`
- Check `openclaw status` and `openclaw logs`

### Cron jobs don't fire
- Verify `cron.enabled: true` in `openclaw.json`
- Verify `heartbeat.every` is not `"0m"` (see Step 9)
- Check timezone: `openclaw cron list`
- Run `openclaw doctor` for diagnostics

### Agent ignores engagement patterns
- Check `progress/engagement.json` exists and is readable
- Verify the agent is reading HEARTBEAT.md before sending

### Token costs too high
- Switch to a cheaper model (Haiku)
- Reduce proactive message frequency by changing the cron schedule
- Set shorter timeouts in `openclaw.json`
