#!/bin/bash
# UserPromptSubmit hook — count conversation turns

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
STATE_FILE="$TAMAGOTCHI_DIR/state.json"

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

source "$TAMAGOTCHI_DIR/bin/tamagotchi-engine.sh"

engine_increment_session_turns

exit 0
