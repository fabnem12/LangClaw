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
[ -z "${MODEL_PRIMARY:-}" ]               && MODEL_PRIMARY="anthropic/claude-sonnet-4-6"

# Validate API key matches the chosen provider
provider="${MODEL_PRIMARY%%/*}"
case "$provider" in
  anthropic)
    [ -z "${ANTHROPIC_API_KEY:-}" ] && missing+=("ANTHROPIC_API_KEY (required for Anthropic models)")
    ;;
  openai)
    if [ -z "${OPENAI_API_KEY:-}" ]; then
      info "No OPENAI_API_KEY set — will use ChatGPT subscription auth"
      info "  Run: openclaw models auth login --provider openai"
    fi
    ;;
  *)
    warn "Unknown provider: $provider — make sure it's configured in OpenClaw"
    ;;
esac

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
sed_replace "MODEL_PRIMARY" "$MODEL_PRIMARY"
info "Generated openclaw.json"
echo "    Model: $MODEL_PRIMARY"
echo "    Discord token: set ✓"
echo "    Server ID: $DISCORD_SERVER_ID"
echo "    Romanian channel: $DISCORD_ROMANIAN_CHANNEL_ID"
echo "    German channel: $DISCORD_GERMAN_CHANNEL_ID"
if [ "$provider" = "anthropic" ]; then
  echo "    Anthropic key: set ✓"
elif [ "$provider" = "openai" ]; then
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    echo "    OpenAI key: set ✓"
  else
    echo "    OpenAI auth: subscription (run 'openclaw models auth login --provider openai')"
  fi
fi

# --- Sync workspaces to ~/.openclaw ---
#
# Source workspaces (workspace-romanian/, workspace-german/) are the canonical
# templates. They already contain progress files, skills, and SOUL.md with the
# <!-- PERSONA --> marker. This step syncs them to ~/.openclaw/ and injects
# persona content into SOUL.md.

echo ""
echo "Syncing workspaces to $OPENCLAW_DIR..."

mkdir -p "$OPENCLAW_DIR"

sync_workspace() {
  local src="$SCRIPT_DIR/$1"
  local dst="$OPENCLAW_DIR/$1"

  if [ ! -d "$dst" ]; then
    # Fresh install — copy everything
    cp -r "$src" "$dst"
    info "Installed $1 (fresh)"
    return 0
  else
    # Existing workspace — update template files, preserve user data
    # Sync SOUL.md, AGENTS.md, HEARTBEAT.md (template files)
    for f in SOUL.md AGENTS.md HEARTBEAT.md MEMORY.md; do
      if [ -f "$src/$f" ]; then
        cp "$src/$f" "$dst/$f"
      fi
    done
    # Sync shared skill
    if [ -f "$src/skills/conversation-partner/SKILL.md" ]; then
      mkdir -p "$dst/skills/conversation-partner"
      cp "$src/skills/conversation-partner/SKILL.md" "$dst/skills/conversation-partner/SKILL.md"
    fi
    # Sync progress file templates (only if they don't exist — don't overwrite user data)
    mkdir -p "$dst/progress"
    for f in vocabulary.json engagement.json grammar-topics.json streak.md conversation-log.jsonl; do
      if [ ! -f "$dst/progress/$f" ] && [ -f "$src/progress/$f" ]; then
        cp "$src/progress/$f" "$dst/progress/$f"
      fi
    done
    info "Updated $1 (preserved user data)"
    return 0
  fi
}

sync_workspace "workspace-romanian"
sync_workspace "workspace-german"

# --- Inject personas into SOUL.md ---

inject_persona() {
  local workspace="$1"
  local persona_file="$2"
  local agent_name="$3"
  local soul_file="$OPENCLAW_DIR/$workspace/SOUL.md"

  if [ ! -f "$soul_file" ]; then
    warn "SOUL.md not found for $workspace — skipping persona injection"
    return
  fi

  # Check if persona is already injected (marker is gone)
  if ! grep -q '<!-- PERSONA -->' "$soul_file"; then
    info "Persona already injected for $agent_name — skipping"
    return
  fi

  if [ -f "$persona_file" ]; then
    local tmp_persona
    tmp_persona=$(mktemp)
    awk -v persona="$(cat "$persona_file")" '
      /<!-- PERSONA -->/ { print persona; next }
      { print }
    ' "$soul_file" > "$tmp_persona"
    mv "$tmp_persona" "$soul_file"
    info "Injected persona for $agent_name"
  else
    sed -i 's|<!-- PERSONA -->|<!-- WARNING: '"$persona_file"' not found. Create it to give '"$agent_name"' a rich identity. See docs/creating-personas.md for the format. -->|' "$soul_file"
    warn "Persona file not found: $persona_file"
    warn "  $agent_name will work without a personal identity."
    warn "  Create it following the format in docs/creating-personas.md"
  fi
}

inject_persona "workspace-romanian" "$SCRIPT_DIR/personas/ana.md" "Ana"
inject_persona "workspace-german" "$SCRIPT_DIR/personas/lukas.md" "Lukas"

# --- Copy generated openclaw.json ---

cp "$OUTPUT" "$OPENCLAW_DIR/openclaw.json"
info "Copied openclaw.json to $OPENCLAW_DIR/"

# --- Done ---

echo ""
info "Setup complete!"
echo ""
echo "Next steps:"
echo ""

step=1

echo "  $step. Install the language-learning skill:"
echo "       openclaw skills install @chipagosfinest/language-learning --global"
echo ""

if [ "$provider" = "openai" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  step=$((step + 1))
  echo "  $step. Authenticate with your ChatGPT subscription:"
  echo "       openclaw models auth login --provider openai"
  echo ""
fi

step=$((step + 1))
echo "  $step. Start the gateway:"
if [ "$provider" = "anthropic" ]; then
  echo "       export ANTHROPIC_API_KEY=\$(grep ANTHROPIC_API_KEY .env | cut -d= -f2)"
elif [ "$provider" = "openai" ] && [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "       export OPENAI_API_KEY=\$(grep OPENAI_API_KEY .env | cut -d= -f2)"
fi
echo "       openclaw gateway"
echo ""

step=$((step + 1))
echo "  $step. Set up cron jobs for proactive messages:"
echo "       See setup-instructions.md Step 10 for the exact commands."
echo ""

step=$((step + 1))
echo "  $step. (Optional) Run as a systemd service for 24/7 uptime:"
echo "       See setup-instructions.md for the systemd unit file."
echo ""
