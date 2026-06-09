#!/bin/sh
set -eu

printf '%s\n' "INFO: To install this script as python package use 'make install-pipx'; requires pipx on your system."
printf '%s\n\n' "INFO: Continuing with simple standalone script installation."

SCRIPT_SOURCE="src/ai_journal_analyzer"
CONFIG_EXAMPLE="ai-journal-analyzer.conf.example"

if [ ! -f "$SCRIPT_SOURCE" ]; then
  echo "Error: $SCRIPT_SOURCE not found. Run this from the repository root." >&2
  exit 1
fi
if [ ! -f "$CONFIG_EXAMPLE" ]; then
  echo "Error: $CONFIG_EXAMPLE not found. Run this from the repository root." >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  DEFAULT_SCRIPT_PATH="/usr/local/bin/ai-journal-analyzer"
  DEFAULT_CONFIG_PATH="/usr/local/etc/ai-journal-analyzer.conf"
else
  DEFAULT_SCRIPT_PATH="$HOME/.local/bin/ai-journal-analyzer"
  XDG_CONFIG_HOME_VALUE="${XDG_CONFIG_HOME:-$HOME/.config}"
  DEFAULT_CONFIG_PATH="$XDG_CONFIG_HOME_VALUE/ai-journal-analyzer/ai-journal-analyzer.conf"
fi

ask() {
  prompt="$1"
  default="$2"
  printf "%s [%s]: " "$prompt" "$default" >&2
  IFS= read -r answer || answer=""
  if [ -z "$answer" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$answer"
  fi
}

ask_secret() {
  prompt="$1"
  default="$2"
  printf "%s [%s]: " "$prompt" "$default" >&2
  IFS= read -r answer || answer=""
  if [ -z "$answer" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$answer"
  fi
}

ask_yes_no() {
  prompt="$1"
  default="$2"
  printf "%s [%s]: " "$prompt" "$default" >&2
  IFS= read -r answer || answer=""
  if [ -z "$answer" ]; then
    answer="$default"
  fi
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

SCRIPT_PATH=$(ask "Where should the script be installed?" "$DEFAULT_SCRIPT_PATH")
CONFIG_PATH=$(ask "Where should the config file be installed?" "$DEFAULT_CONFIG_PATH")

SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
CONFIG_DIR=$(dirname "$CONFIG_PATH")
mkdir -p "$SCRIPT_DIR" "$CONFIG_DIR"
cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
chmod 0755 "$SCRIPT_PATH"

if [ -e "$CONFIG_PATH" ]; then
  echo "Config already exists: $CONFIG_PATH"
  if ask_yes_no "Overwrite existing config?" "n"; then
    cp "$CONFIG_EXAMPLE" "$CONFIG_PATH"
  else
    echo "Keeping existing config."
  fi
else
  cp "$CONFIG_EXAMPLE" "$CONFIG_PATH"
fi
chmod 0600 "$CONFIG_PATH" 2>/dev/null || true

if ask_yes_no "Edit configuration interactively?" "Y"; then
  echo ""
  echo "Chat Completions API is used by default for OpenAI, LiteLLM, and Ollama compatibility."
  echo "Examples:"
  echo "  OpenAI:  https://api.openai.com"
  echo "  LiteLLM: http://127.0.0.1:4000"
  echo "  Ollama:  http://127.0.0.1:11434"
  echo ""

  API_URL=$(ask "API base URL" "https://api.openai.com")
  API_KEY=$(ask_secret "API key (empty = use OPENAI_API_KEY environment variable)" "")
  MODEL=$(ask "Model" "gpt-5-mini")
  MAX_OUTPUT_TOKENS=$(ask "Maximum output tokens" "8192")
  echo ""
  echo "Chunk size tips:"
  echo "  200 lines  = safer for smaller/local models or very noisy logs"
  echo "  300 lines  = conservative local-model setting"
  echo "  500 lines  = recommended default; best for 64k context-size with thinking model"
  echo "  800 lines  = for larger/stable context windows"
  echo "  1000+ lines = may fail or return empty results despite nominal 64k context"
  CHUNKSIZE=$(ask "Chunk size in journal lines" "500")
  MAX_LINES=$(ask "Maximum filtered journal lines before abort" "15000")
  LOGLEVEL=$(ask "Journal log level" "warning..alert")
  SINCE=$(ask "Default journal --since value" "24 hours ago")

  export API_KEY API_URL MODEL MAX_OUTPUT_TOKENS CHUNKSIZE MAX_LINES LOGLEVEL SINCE CONFIG_PATH
  python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["CONFIG_PATH"])
updates = {
    "openai.api_url": os.environ.get("API_URL", "https://api.openai.com"),
    "openai.api_key": os.environ.get("API_KEY", ""),
    "openai.api_path": "/v1/chat/completions",
    "openai.api_style": "chat_completions",
    "openai.model": os.environ.get("MODEL", "gpt-5-mini"),
    "openai.max_output_tokens": os.environ.get("MAX_OUTPUT_TOKENS", "8192"),
    "journal.chunksize": os.environ.get("CHUNKSIZE", "500"),
    "journal.max_lines": os.environ.get("MAX_LINES", "15000"),
    "journal.loglevel": os.environ.get("LOGLEVEL", "warning..alert"),
    "journal.since": os.environ.get("SINCE", "24 hours ago"),
    "timestamps.enabled": "true",
}

def fmt(value: str) -> str:
    value = str(value)
    if value == "" or value.startswith((" ", "#", ";")) or value.endswith(" "):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return value

lines = path.read_text(encoding="utf-8").splitlines()
seen = set()
out = []
for line in lines:
    stripped = line.strip()
    replaced = False
    if stripped and not stripped.startswith(("#", ";")) and "=" in line and "<<" not in line:
        key = line.split("=", 1)[0].strip()
        if key in updates:
            out.append(f"{key} = {fmt(updates[key])}")
            seen.add(key)
            replaced = True
    if not replaced:
        out.append(line)
for key, value in updates.items():
    if key not in seen:
        out.append(f"{key} = {fmt(value)}")
path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY
fi

echo ""
echo "Installed script: $SCRIPT_PATH"
echo "Installed config: $CONFIG_PATH"
echo ""
echo "Example run:"
echo "  $SCRIPT_PATH --config $CONFIG_PATH --since \"24 hours ago\" --focus-on \"security incidents and system stability events\" --gently-ignore \"printer warnings\""
echo ""
case ":$PATH:" in
  *":$(dirname "$SCRIPT_PATH"):"*) ;;
  *) echo "Note: $(dirname "$SCRIPT_PATH") is not in PATH. Use the full path above or add it to PATH." ;;
esac
