# LangClaw

Personal AI language learning setup powered by [OpenClaw](https://openclaw.ai). Two autonomous agents — **Ana** (Romanian) and **Lukas** (German) — act as conversation partners and tutors through Discord, with persistent memory, proactive practice messages, and adaptive engagement.

## What It Does

- **Two independent agents**, each with their own personality, teaching style, and progress tracking
- **Discord integration** — talk to Ana in `#romanian`, Lukas in `#german`
- **Proactive practice** — they reach out to you at varied times throughout the day (morning word, vocab quiz, conversation prompt, evening review)
- **Engagement intelligence** — agents monitor how you interact, notice when you disengage, and adapt their strategy
- **Persistent memory** — vocabulary confidence scores, grammar progress, conversation history, streaks
- **Variable timing** — proactive messages vary from day to day so it feels natural, not robotic

## Agents

| | Ana (Romanian) | Lukas (German) |
|---|---|---|
| **Role** | Patient friend + tutor | Enthusiastic practice buddy |
| **Language** | All explanations in Romanian | German primary, French for grammar |
| **Focus** | Grammar structure, error patterns | Vocabulary expansion, fluency |
| **Correction** | Frequent, gentle, pattern-focused | Light, keeps conversation flowing |

## Architecture

```
openclaw.json.example     Config template (${VAR} placeholders)
setup.sh                  Reads .env → generates openclaw.json
.env.example              Secrets template (Discord token, API key)

workspace-romanian/       Ana's workspace
  SOUL.md                   Identity & teaching philosophy
  AGENTS.md                 Session behavior & tracking rules
  HEARTBEAT.md              Proactive message logic
  MEMORY.md                 Long-term user memory
  skills/conversation-partner/   5 conversation modes + correction strategy

workspace-german/         Lukas's workspace (same structure)

cron-stagger.js           Variable timing via date-hash slot selection
```

## Setup

1. Install OpenClaw: `npm i -g openclaw@latest`
2. Create a Discord bot ([Developer Portal](https://discord.com/developers/applications))
3. `cp .env.example .env` → fill in your Discord token, server/channel IDs, and Anthropic API key
4. `./setup.sh` → generates config and creates progress directories
5. `openclaw skills install @chipagosfinest/language-learning --global`
6. `openclaw gateway`

See [setup-instructions.md](setup-instructions.md) for the full guide.

## How Engagement Works

Agents track everything in `progress/engagement.json`:

- **Response rates** per proactive message type
- **Session length** and preferred activities
- **Consecutive ignored messages** — if you ignore 3 in a row, they back off
- **Adaptation history** — what they changed and why

Adaptation rules:
- Short sessions → keep it brief, end with a hook
- Deep engagement → go deeper, introduce complexity
- Boredom detected → switch activity immediately
- Absence → warm welcome, no guilt, ease back in

## Proactive Schedule

Messages vary from day to day using date-hash slot selection (`cron-stagger.js`):

| Message | Window | Behavior |
|---|---|---|
| Morning word | ~6:45–7:15 AM CET | One word + example, alternating languages |
| Vocab quiz | ~11:30–1:00 PM CET | 5 words from weak areas |
| Conversation | ~5:30–6:30 PM CET | "Want to practice?" prompt |
| Evening review | ~7:45–8:15 PM CET | Recap of the day |

## Tech Stack

- [OpenClaw](https://openclaw.ai) — self-hosted AI agent framework
- [Anthropic Claude](https://console.anthropic.com) — Sonnet 4.6 (default model)
- [Discord](https://discord.com) — chat interface
- [ClawHub](https://clawhub.ai) — `@chipagosfinest/language-learning` skill

## License

MIT
