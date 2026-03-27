#!/bin/bash
# PostToolUse hook — track tool calls and errors

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
STATE_FILE="$TAMAGOTCHI_DIR/state.json"

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Read hook input
INPUT=$(cat)

# Check exit code
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // 0' 2>/dev/null)
STDERR=$(echo "$INPUT" | jq -r '.tool_result.stderr // empty' 2>/dev/null)

source "$TAMAGOTCHI_DIR/bin/tamagotchi-engine.sh"

if [[ "$EXIT_CODE" != "0" && "$EXIT_CODE" != "null" ]] || [[ -n "$STDERR" ]]; then
  engine_increment_session_errors
else
  engine_increment_session_tool_calls
fi

exit 0
