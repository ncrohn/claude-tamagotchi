#!/bin/bash
# Stop hook — award XP, recover HP, check death, update state

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
STATE_FILE="$TAMAGOTCHI_DIR/state.json"

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

source "$TAMAGOTCHI_DIR/bin/tamagotchi-engine.sh"

# Read turn count from stdin if available (Stop hook receives context)
INPUT=$(cat)

# Award XP based on session stats
level_result=$(engine_award_xp)
if [ -n "$level_result" ]; then
  # Parse: LEVEL_UP:level:emoji:name
  IFS=':' read -r _ new_level emoji name <<< "$level_result"
  echo "🎉 ${name} evolved to Level ${new_level}! ${emoji}" >&2
fi

# Recover HP
engine_recover_hp

# Update mood
mood=$(engine_get_mood)
engine_update_mood "$mood"

# Update last session timestamp
engine_update_last_session

# Check death (unlikely during active session, but possible if HP was very low)
death_result=$(engine_check_death)
if [ $? -eq 0 ] && [ -n "$death_result" ]; then
  IFS=':' read -r _ old_name old_level new_name new_emoji <<< "$death_result"
  echo "💀 ${old_name} (Lv ${old_level}) has passed away..." >&2
  echo "🥚 But an egg was left behind! Meet ${new_name}! (inherited $(( old_level * 2 )) XP)" >&2
fi

# Re-render display
bash "$TAMAGOTCHI_DIR/bin/tamagotchi-render.sh" > /dev/null 2>&1

exit 0
