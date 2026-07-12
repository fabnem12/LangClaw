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

## Step 6: Generate Config & Set Up Workspaces

Run the setup script:

```bash
./setup.sh
```

This reads `.env` and generates `openclaw.json` with your actual credentials. The generated file is gitignored and never committed.

Then copy the workspaces:

```bash
cp -r workspace-romanian ~/.openclaw/workspace-romanian
cp -r workspace-german ~/.openclaw/workspace-german
```

Install the ClawHub language-learning skill:

```bash
openclaw skills install @chipagosfinest/language-learning --global
```

---

## Step 7: Start OpenClaw

```bash
export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY .env | cut -d= -f2)
openclaw gateway
```

On first run, OpenClaw will:
1. Pair with Discord
2. Create agent sessions
3. Start the heartbeat system

---

## Step 8: Test

1. Go to your Discord server
2. Send a message in `#romanian` — Ana should respond
3. Send a message in `#german` — Lukas should respond
4. Wait for a proactive message (they'll reach out based on the cron schedule)

---

## Step 9: Set Up Cron Jobs (Proactive Messages)

The proactive schedule uses staggered timing. Run the setup script to see the commands:

```bash
node cron-stagger.js setup
```

Then create the cron jobs. For each agent, create 4 cron jobs (morning, midday, afternoon, evening):

```bash
# Example: Romanian morning word at 7:00 AM CET/CEST
openclaw cron create "0 7 * * *" \
  --name "Romanian morning word" \
  --tz "Europe/Berlin" \
  --agent romanian \
  --session isolated \
  --message "Read HEARTBEAT.md and progress/engagement.json. If consecutiveIgnoredProactive < 3, send a morning word in Romanian. Otherwise, reply HEARTBEAT_OK." \
  --announce \
  --channel discord

# Example: German morning word at 7:00 AM CET/CEST
openclaw cron create "0 7 * * *" \
  --name "German morning word" \
  --tz "Europe/Berlin" \
  --agent german \
  --session isolated \
  --message "Read HEARTBEAT.md and progress/engagement.json. If consecutiveIgnoredProactive < 3, send a morning word in German. Otherwise, reply HEARTBEAT_OK." \
  --announce \
  --channel discord
```

Repeat for midday (~12:00), afternoon (~18:00), and evening (~20:00) slots.

See `cron-stagger.js` for the full list of staggered commands.

---

## Step 10: Verify Everything Works

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
openclaw cron edit <job-id> --cron "30 7 * * *" --tz "Europe/Berlin"
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
- Check timezone: `openclaw cron list`
- Run `openclaw doctor` for diagnostics

### Agent ignores engagement patterns
- Check `progress/engagement.json` exists and is readable
- Verify the agent is reading HEARTBEAT.md before sending

### Token costs too high
- Switch to a cheaper model (Haiku)
- Reduce proactive message frequency
- Set shorter timeouts in `openclaw.json`
