#!/bin/bash
# SessionStart hook — init or update creature state

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
STATE_FILE="$TAMAGOTCHI_DIR/state.json"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# First run: initialize everything
if [ ! -f "$STATE_FILE" ]; then
  bash "$PLUGIN_DIR/bin/tamagotchi-init.sh"
  exit 0
fi

# Update bin and themes from plugin (in case of plugin update)
if [ -d "$TAMAGOTCHI_DIR/bin" ]; then
  cp "$PLUGIN_DIR/bin/tamagotchi-engine.sh" "$TAMAGOTCHI_DIR/bin/"
  cp "$PLUGIN_DIR/bin/tamagotchi-render.sh" "$TAMAGOTCHI_DIR/bin/"
  cp "$PLUGIN_DIR/bin/tamagotchi-init.sh" "$TAMAGOTCHI_DIR/bin/"
  chmod +x "$TAMAGOTCHI_DIR/bin/"*.sh
fi
for theme_file in "$PLUGIN_DIR/themes/"*.json; do
  [ -f "$theme_file" ] && cp "$theme_file" "$TAMAGOTCHI_DIR/themes/"
done

# Source engine
source "$TAMAGOTCHI_DIR/bin/tamagotchi-engine.sh"

# Apply neglect decay
engine_apply_neglect

# Check if creature died from neglect
death_result=$(engine_check_death)
if [ $? -eq 0 ] && [ -n "$death_result" ]; then
  # Parse: DEATH:old_name:old_level:new_name:new_emoji
  IFS=':' read -r _ old_name old_level new_name new_emoji <<< "$death_result"
  echo "💀 ${old_name} (Lv ${old_level}) has passed away from neglect..." >&2
  echo "🥚 But an egg was left behind! Meet ${new_name}! (inherited $(( old_level * 2 )) XP)" >&2
fi

# Update streak
engine_update_streak

# Reset session counters
engine_reset_session

# Update mood
mood=$(engine_get_mood)
engine_update_mood "$mood"

# Re-render display
bash "$TAMAGOTCHI_DIR/bin/tamagotchi-render.sh" > /dev/null 2>&1

exit 0
