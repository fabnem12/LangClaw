#!/usr/bin/env bash
set -euo pipefail

# LangClaw Setup Script
# Reads .env, generates openclaw.json, and sets up workspaces.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
TEMPLATE="$SCRIPT_DIR/openclaw.json.example"
OUTPUT="$SCRIPT_DIR/openclaw.json"
OPENCLAW_DIR="${HOME}/.openclaw"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# --- Checks ---

if [ ! -f "$ENV_FILE" ]; then
  error ".env file not found."
  echo "  Copy .env.example to .env and fill in your values:"
  echo "    cp .env.example .env"
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  error "openclaw.json.example not found."
  exit 1
fi

# --- Load .env ---

set -a
# shellcheck disable=SC1090
source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
set +a

# --- Validate ---

missing=()
[ -z "${DISCORD_BOT_TOKEN:-}" ]           && missing+=("DISCORD_BOT_TOKEN")
[ -z "${DISCORD_SERVER_ID:-}" ]           && missing+=("DISCORD_SERVER_ID")
[ -z "${DISCORD_ROMANIAN_CHANNEL_ID:-}" ] && missing+=("DISCORD_ROMANIAN_CHANNEL_ID")
[ -z "${DISCORD_GERMAN_CHANNEL_ID:-}" ]   && missing+=("DISCORD_GERMAN_CHANNEL_ID")
[ -z "${ANTHROPIC_API_KEY:-}" ]           && missing+=("ANTHROPIC_API_KEY")

if [ ${#missing[@]} -gt 0 ]; then
  error "Missing required values in .env:"
  for key in "${missing[@]}"; do
    echo "    - $key"
  done
  exit 1
fi

# --- Generate openclaw.json ---

sed_replace() {
  local var_name="$1"
  local var_value="$2"
  sed -i "s|\${${var_name}}|${var_value}|g" "$OUTPUT"
}

cp "$TEMPLATE" "$OUTPUT"
sed_replace "DISCORD_BOT_TOKEN" "$DISCORD_BOT_TOKEN"
sed_replace "DISCORD_SERVER_ID" "$DISCORD_SERVER_ID"
sed_replace "DISCORD_ROMANIAN_CHANNEL_ID" "$DISCORD_ROMANIAN_CHANNEL_ID"
sed_replace "DISCORD_GERMAN_CHANNEL_ID" "$DISCORD_GERMAN_CHANNEL_ID"
info "Generated openclaw.json"
echo "    Discord token: set ✓"
echo "    Server ID: $DISCORD_SERVER_ID"
echo "    Romanian channel: $DISCORD_ROMANIAN_CHANNEL_ID"
echo "    German channel: $DISCORD_GERMAN_CHANNEL_ID"
echo "    Anthropic key: set ✓"

# --- Create progress directories ---

create_progress() {
  local dir="$1"
  local lang="$2"
  mkdir -p "$dir"

  if [ ! -f "$dir/vocabulary.json" ]; then
    cat > "$dir/vocabulary.json" <<EOF
{
  "language": "$lang",
  "lastUpdated": null,
  "words": []
}
EOF
    info "Created $dir/vocabulary.json"
  fi

  if [ ! -f "$dir/engagement.json" ]; then
    cat > "$dir/engagement.json" <<EOF
{
  "language": "$lang",
  "lastUpdated": null,
  "proactiveMessages": {
    "morning":   { "sent": 0, "responded": 0, "avgResponseMin": 0 },
    "midday":    { "sent": 0, "responded": 0, "avgResponseMin": 0 },
    "afternoon": { "sent": 0, "responded": 0, "avgResponseMin": 0 },
    "evening":   { "sent": 0, "responded": 0, "avgResponseMin": 0 }
  },
  "sessionPatterns": {
    "totalSessions": 0,
    "avgLengthMin": 0,
    "preferredActivities": [],
    "leastPreferred": [],
    "peakEngagementHour": null,
    "consecutiveIgnoredProactive": 0,
    "longestStreak": 0,
    "currentStreak": 0
  },
  "correctionTolerance": "medium",
  "recentEngagementTrend": "unknown",
  "lastAdaptation": null,
  "adaptationHistory": []
}
EOF
    info "Created $dir/engagement.json"
  fi

  if [ ! -f "$dir/conversation-log.jsonl" ]; then
    touch "$dir/conversation-log.jsonl"
    info "Created $dir/conversation-log.jsonl"
  fi

  if [ ! -f "$dir/streak.md" ]; then
    cat > "$dir/streak.md" <<EOF
# Practice Streak — $lang

## Format
Each line: \`YYYY-MM-DD | sessions: N | totalMin: N | activities: [list]\`

## Log

(no entries yet)
EOF
    info "Created $dir/streak.md"
  fi

  if [ ! -f "$dir/grammar-topics.json" ]; then
    cat > "$dir/grammar-topics.json" <<EOF
{
  "language": "$lang",
  "topics": []
}
EOF
    info "Created $dir/grammar-topics.json"
  fi
}

create_progress "$SCRIPT_DIR/workspace-romanian/progress" "Romanian"
create_progress "$SCRIPT_DIR/workspace-german/progress" "German"

# --- Copy workspaces to ~/.openclaw ---

echo ""
echo "Copying workspaces to $OPENCLAW_DIR..."

mkdir -p "$OPENCLAW_DIR"
cp -rn "$SCRIPT_DIR/workspace-romanian" "$OPENCLAW_DIR/" 2>/dev/null || warn "workspace-romanian already exists, skipping"
cp -rn "$SCRIPT_DIR/workspace-german" "$OPENCLAW_DIR/" 2>/dev/null || warn "workspace-german already exists, skipping"

# Copy shared skill file to both workspaces
cp "$SCRIPT_DIR/skills/conversation-partner/SKILL.md" "$OPENCLAW_DIR/workspace-romanian/skills/conversation-partner/SKILL.md"
cp "$SCRIPT_DIR/skills/conversation-partner/SKILL.md" "$OPENCLAW_DIR/workspace-german/skills/conversation-partner/SKILL.md"
info "Copied shared SKILL.md to both workspaces"

# --- Inject personas into SOUL.md ---

inject_persona() {
  local workspace="$1"
  local persona_file="$2"
  local agent_name="$3"
  local soul_file="$OPENCLAW_DIR/$workspace/SOUL.md"

  if [ -f "$persona_file" ]; then
    # Create a temp file with the persona content (escaping special chars for sed)
    local tmp_persona
    tmp_persona=$(mktemp)
    # Use awk to avoid sed escaping issues with special characters
    awk -v persona="$(cat "$persona_file")" '
      /<!-- PERSONA -->/ { print persona; next }
      { print }
    ' "$soul_file" > "$tmp_persona"
    mv "$tmp_persona" "$soul_file"
    info "Injected persona into $workspace/SOUL.md"
  else
    # Replace marker with warning
    sed -i 's|<!-- PERSONA -->|<!-- WARNING: '"$persona_file"' not found. Create it to give '"$agent_name"' a rich identity. See docs/creating-personas.md for the format. -->|' "$soul_file"
    warn "Persona file not found: $persona_file"
    warn "  $agent_name will work without a personal identity."
    warn "  Create it following the format in docs/creating-personas.md"
  fi
}

inject_persona "workspace-romanian" "$SCRIPT_DIR/personas/ana.md" "Ana"
inject_persona "workspace-german" "$SCRIPT_DIR/personas/lukas.md" "Lukas"

# Copy generated openclaw.json
cp "$OUTPUT" "$OPENCLAW_DIR/openclaw.json"
info "Copied openclaw.json to $OPENCLAW_DIR/"

echo ""
info "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Install the language-learning skill:"
echo "       openclaw skills install @chipagosfinest/language-learning --global"
echo ""
echo "  2. Start the gateway:"
echo "       export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
echo "       openclaw gateway"
echo ""
echo "  3. Set up cron jobs (see setup-instructions.md)"
