#!/bin/bash
# Tamagotchi Engine — Core game logic
# Sourced by hooks and other scripts. Not run directly.

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
STATE_FILE="$TAMAGOTCHI_DIR/state.json"
THEMES_DIR="$TAMAGOTCHI_DIR/themes"

# Name pool for auto-generation
NAMES=(
  Chip Nugget Sparky Zorp Pixel Byte Glitch Widget Bloop Noodle
  Pip Fizz Gizmo Turbo Sprout Dash Jinx Mochi Ziggy Wobble
  Blip Crumb Flick Snoot Twig Bonk Dink Puff Riff Speck
)

# --- State helpers ---

engine_read_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    echo "{}"
  fi
}

engine_write_state() {
  local state="$1"
  local tmp="${STATE_FILE}.tmp"
  echo "$state" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

engine_get_field() {
  local state="$1" path="$2"
  echo "$state" | jq -r "$path // empty"
}

# --- Name generation ---

engine_generate_name() {
  local state="$1"
  # Collect recent lineage names to avoid
  local used_names
  used_names=$(echo "$state" | jq -r '[.lineage[]?.name // empty, .creature.name // empty] | .[]' 2>/dev/null)

  local attempts=0
  while [ $attempts -lt 20 ]; do
    local idx=$(( RANDOM % ${#NAMES[@]} ))
    local candidate="${NAMES[$idx]}"
    if ! echo "$used_names" | grep -qx "$candidate"; then
      echo "$candidate"
      return
    fi
    attempts=$((attempts + 1))
  done
  # Fallback: pick any name
  echo "${NAMES[$(( RANDOM % ${#NAMES[@]} ))]}"
}

# --- Theme helpers ---

engine_pick_random_theme() {
  local themes=()
  for f in "$THEMES_DIR"/*.json; do
    [ -f "$f" ] && themes+=("$(basename "$f" .json)")
  done
  if [ ${#themes[@]} -eq 0 ]; then
    echo "default"
    return
  fi
  echo "${themes[$(( RANDOM % ${#themes[@]} ))]}"
}

engine_get_emoji() {
  local theme="$1" level="$2"
  local theme_file="$THEMES_DIR/${theme}.json"
  if [ ! -f "$theme_file" ]; then
    theme_file="$THEMES_DIR/default.json"
  fi
  local emoji_count
  emoji_count=$(jq -r '.emoji | length' "$theme_file")
  # Clamp level to available emoji (1-indexed, array is 0-indexed)
  local idx=$(( level - 1 ))
  if [ $idx -ge "$emoji_count" ]; then
    idx=$(( emoji_count - 1 ))
  fi
  if [ $idx -lt 0 ]; then
    idx=0
  fi
  jq -r ".emoji[$idx]" "$theme_file"
}

# --- Creature creation ---

engine_create_creature() {
  local state
  state=$(engine_read_state)

  local theme
  theme=$(engine_pick_random_theme)
  local name
  name=$(engine_generate_name "$state")
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local max_hp=85  # 80 + level(1) * 5

  state=$(echo "$state" | jq --arg name "$name" --arg theme "$theme" --arg now "$now" --argjson max_hp "$max_hp" '
    .creature = {
      name: $name,
      level: 1,
      xp: 0,
      hp: $max_hp,
      max_hp: $max_hp,
      mood: "happy",
      theme: $theme,
      born: $now,
      last_session: $now,
      streak_days: 0,
      total_sessions: 0
    } |
    .session = {
      start: $now,
      errors: 0,
      tool_calls: 0,
      turns: 0
    } |
    .config = (.config // {theme: "random", custom_emoji: null}) |
    .lineage = (.lineage // [])
  ')

  engine_write_state "$state"
  echo "$name"
}

engine_create_creature_with_inheritance() {
  local parent_level="$1"
  local state
  state=$(engine_read_state)

  local theme
  theme=$(engine_pick_random_theme)
  local name
  name=$(engine_generate_name "$state")
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local max_hp=85
  local bonus_xp=$(( parent_level * 2 ))

  state=$(echo "$state" | jq --arg name "$name" --arg theme "$theme" --arg now "$now" \
    --argjson max_hp "$max_hp" --argjson bonus_xp "$bonus_xp" '
    .creature = {
      name: $name,
      level: 1,
      xp: $bonus_xp,
      hp: $max_hp,
      max_hp: $max_hp,
      mood: "happy",
      theme: $theme,
      born: $now,
      last_session: $now,
      streak_days: 0,
      total_sessions: 0
    } |
    .session = {
      start: $now,
      errors: 0,
      tool_calls: 0,
      turns: 0
    }
  ')

  engine_write_state "$state"
  echo "$name"
}

# --- Neglect & streak ---

engine_apply_neglect() {
  local state
  state=$(engine_read_state)

  local last_session
  last_session=$(engine_get_field "$state" '.creature.last_session')
  if [ -z "$last_session" ]; then
    return
  fi

  local last_epoch now_epoch
  last_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_session" +%s 2>/dev/null || date -d "$last_session" +%s 2>/dev/null)
  now_epoch=$(date +%s)

  local days_inactive=$(( (now_epoch - last_epoch) / 86400 ))

  if [ "$days_inactive" -gt 1 ]; then
    local decay=$(( (days_inactive - 1) * 3 ))
    local current_hp
    current_hp=$(echo "$state" | jq -r '.creature.hp')
    local new_hp=$(( current_hp - decay ))
    [ $new_hp -lt 0 ] && new_hp=0

    state=$(echo "$state" | jq --argjson hp "$new_hp" '.creature.hp = $hp')
    engine_write_state "$state"
  fi
}

engine_update_streak() {
  local state
  state=$(engine_read_state)

  local last_session
  last_session=$(engine_get_field "$state" '.creature.last_session')
  if [ -z "$last_session" ]; then
    return
  fi

  # Compare calendar dates
  local last_date
  last_date=$(echo "$last_session" | cut -dT -f1)
  local today
  today=$(date -u +"%Y-%m-%d")

  if [ "$last_date" = "$today" ]; then
    # Same day, no streak change
    return
  fi

  local last_epoch today_epoch
  last_epoch=$(date -j -u -f "%Y-%m-%d" "$last_date" +%s 2>/dev/null || date -d "$last_date" +%s 2>/dev/null)
  today_epoch=$(date -j -u -f "%Y-%m-%d" "$today" +%s 2>/dev/null || date -d "$today" +%s 2>/dev/null)
  local day_diff=$(( (today_epoch - last_epoch) / 86400 ))

  local streak
  streak=$(echo "$state" | jq -r '.creature.streak_days')

  if [ "$day_diff" -eq 1 ]; then
    streak=$(( streak + 1 ))
  else
    streak=1  # Reset but today counts
  fi

  state=$(echo "$state" | jq --argjson streak "$streak" '.creature.streak_days = $streak')
  engine_write_state "$state"
}

# --- Session management ---

engine_reset_session() {
  local state
  state=$(engine_read_state)
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  state=$(echo "$state" | jq --arg now "$now" '
    .session = {
      start: $now,
      errors: 0,
      tool_calls: 0,
      turns: 0
    }
  ')
  engine_write_state "$state"
}

engine_increment_session_turns() {
  local state
  state=$(engine_read_state)
  state=$(echo "$state" | jq '.session.turns = (.session.turns + 1)')
  engine_write_state "$state"
}

engine_increment_session_errors() {
  local state
  state=$(engine_read_state)
  state=$(echo "$state" | jq '.session.errors = (.session.errors + 1) | .session.tool_calls = (.session.tool_calls + 1)')
  engine_write_state "$state"
}

engine_increment_session_tool_calls() {
  local state
  state=$(engine_read_state)
  state=$(echo "$state" | jq '.session.tool_calls = (.session.tool_calls + 1)')
  engine_write_state "$state"
}

# --- XP & leveling ---

engine_award_xp() {
  local state
  state=$(engine_read_state)

  local turns tool_calls
  turns=$(echo "$state" | jq -r '.session.turns // 0')
  tool_calls=$(echo "$state" | jq -r '.session.tool_calls // 0')

  # XP formula: base(5) + min(turns, 15) * 2 + tool_calls/5 (cap 10), cap 50
  # Turns = user messages (slow), tool_calls = all tool uses (fast, needs scaling)
  local capped_turns=$(( turns > 15 ? 15 : turns ))
  local scaled_tools=$(( tool_calls / 5 ))
  local capped_tools=$(( scaled_tools > 10 ? 10 : scaled_tools ))
  local xp_earned=$(( 5 + capped_turns * 2 + capped_tools ))
  [ $xp_earned -gt 50 ] && xp_earned=50

  local current_xp current_level
  current_xp=$(echo "$state" | jq -r '.creature.xp')
  current_level=$(echo "$state" | jq -r '.creature.level')

  local new_xp=$(( current_xp + xp_earned ))
  local new_level=$current_level
  local leveled_up=false

  # Check for level-ups (can gain multiple levels)
  while true; do
    local threshold=$(( 40 + new_level * 20 ))
    if [ $new_xp -ge $threshold ]; then
      new_xp=$(( new_xp - threshold ))
      new_level=$(( new_level + 1 ))
      leveled_up=true
    else
      break
    fi
  done

  local new_max_hp=$(( 80 + new_level * 5 ))
  local current_hp
  current_hp=$(echo "$state" | jq -r '.creature.hp')
  # If leveled up, grant some bonus HP
  if [ "$leveled_up" = true ]; then
    current_hp=$(( current_hp + 10 ))
    [ $current_hp -gt $new_max_hp ] && current_hp=$new_max_hp
  fi

  state=$(echo "$state" | jq \
    --argjson xp "$new_xp" \
    --argjson level "$new_level" \
    --argjson max_hp "$new_max_hp" \
    --argjson hp "$current_hp" '
    .creature.xp = $xp |
    .creature.level = $level |
    .creature.max_hp = $max_hp |
    .creature.hp = $hp
  ')

  local total_sessions
  total_sessions=$(echo "$state" | jq -r '.creature.total_sessions')
  state=$(echo "$state" | jq --argjson s "$(( total_sessions + 1 ))" '.creature.total_sessions = $s')

  engine_write_state "$state"

  if [ "$leveled_up" = true ]; then
    local name theme
    name=$(engine_get_field "$state" '.creature.name')
    theme=$(engine_get_field "$state" '.creature.theme')
    local emoji
    emoji=$(engine_get_emoji "$theme" "$new_level")
    echo "LEVEL_UP:${new_level}:${emoji}:${name}"
  fi
}

# --- HP recovery ---

engine_recover_hp() {
  local state
  state=$(engine_read_state)

  local hp max_hp streak
  hp=$(echo "$state" | jq -r '.creature.hp')
  max_hp=$(echo "$state" | jq -r '.creature.max_hp')
  streak=$(echo "$state" | jq -r '.creature.streak_days')

  local recovery=10
  if [ "$streak" -gt 3 ]; then
    recovery=15
  fi

  local new_hp=$(( hp + recovery ))
  [ $new_hp -gt $max_hp ] && new_hp=$max_hp

  state=$(echo "$state" | jq --argjson hp "$new_hp" '.creature.hp = $hp')
  engine_write_state "$state"
}

# --- Death & inheritance ---

engine_check_death() {
  local state
  state=$(engine_read_state)

  local hp
  hp=$(echo "$state" | jq -r '.creature.hp')

  if [ "$hp" -le 0 ]; then
    local name level born total_sessions theme
    name=$(engine_get_field "$state" '.creature.name')
    level=$(echo "$state" | jq -r '.creature.level')
    born=$(engine_get_field "$state" '.creature.born')
    total_sessions=$(echo "$state" | jq -r '.creature.total_sessions')
    theme=$(engine_get_field "$state" '.creature.theme')

    local today
    today=$(date -u +"%Y-%m-%d")
    local born_date
    born_date=$(echo "$born" | cut -dT -f1)

    # Add to lineage
    state=$(echo "$state" | jq \
      --arg name "$name" \
      --argjson level "$level" \
      --arg born "$born_date" \
      --arg died "$today" \
      --argjson sessions "$total_sessions" '
      .lineage += [{
        name: $name,
        level: $level,
        born: $born,
        died: $died,
        cause: "neglect",
        sessions: $sessions
      }]
    ')
    engine_write_state "$state"

    # If an egg already exists (died during coexistence), promote it with death bonus
    local existing_egg
    existing_egg=$(echo "$state" | jq -r '.egg // empty')
    local new_name
    if [ -n "$existing_egg" ] && [ "$existing_egg" != "null" ]; then
      local egg_name egg_theme
      egg_name=$(echo "$state" | jq -r '.egg.name')
      egg_theme=$(echo "$state" | jq -r '.egg.theme')
      local bonus_xp=$(( level * 2 ))
      local now
      now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

      state=$(engine_read_state)
      state=$(echo "$state" | jq \
        --arg name "$egg_name" \
        --arg theme "$egg_theme" \
        --arg now "$now" \
        --argjson max_hp 85 \
        --argjson bonus_xp "$bonus_xp" '
        .creature = {
          name: $name,
          level: 1,
          xp: $bonus_xp,
          hp: 85,
          max_hp: 85,
          mood: "happy",
          theme: $theme,
          born: $now,
          last_session: $now,
          streak_days: 0,
          total_sessions: 0,
          sessions_at_max: 0
        } |
        del(.egg)
      ')
      engine_write_state "$state"
      new_name="$egg_name"
    else
      new_name=$(engine_create_creature_with_inheritance "$level")
    fi

    local emoji
    emoji=$(engine_get_emoji "$(engine_get_field "$(engine_read_state)" '.creature.theme')" 1)

    echo "DEATH:${name}:${level}:${new_name}:${emoji}"
    return 0
  fi
  return 1
}

# --- Egg-laying & retirement ---

engine_check_egg_laying() {
  local state
  state=$(engine_read_state)

  # Skip if already has an egg
  local has_egg
  has_egg=$(echo "$state" | jq -r '.egg // empty')
  if [ -n "$has_egg" ] && [ "$has_egg" != "null" ]; then
    return 1
  fi

  local level sessions_at_max
  level=$(echo "$state" | jq -r '.creature.level')
  sessions_at_max=$(echo "$state" | jq -r '.creature.sessions_at_max // 0')

  # Must be level 5 with 3+ sessions at that level
  if [ "$level" -ge 5 ]; then
    if [ "$sessions_at_max" -ge 3 ]; then
      # Lay the egg
      local egg_theme egg_name now
      egg_theme=$(engine_pick_random_theme)
      egg_name=$(engine_generate_name "$state")
      now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

      state=$(echo "$state" | jq \
        --arg name "$egg_name" \
        --arg theme "$egg_theme" \
        --arg now "$now" '
        .egg = {
          name: $name,
          theme: $theme,
          created: $now,
          sessions_remaining: 2
        }
      ')
      engine_write_state "$state"

      local parent_name
      parent_name=$(engine_get_field "$state" '.creature.name')
      echo "EGG_LAID:${parent_name}:${egg_name}"
      return 0
    fi
  fi
  return 1
}

engine_track_sessions_at_max() {
  local state
  state=$(engine_read_state)

  local level
  level=$(echo "$state" | jq -r '.creature.level')

  if [ "$level" -ge 5 ]; then
    local current
    current=$(echo "$state" | jq -r '.creature.sessions_at_max // 0')
    state=$(echo "$state" | jq --argjson s "$(( current + 1 ))" '.creature.sessions_at_max = $s')
  else
    state=$(echo "$state" | jq '.creature.sessions_at_max = 0')
  fi

  engine_write_state "$state"
}

engine_check_retirement() {
  local state
  state=$(engine_read_state)

  local egg
  egg=$(echo "$state" | jq -r '.egg // empty')
  if [ -z "$egg" ] || [ "$egg" = "null" ]; then
    return 1
  fi

  local remaining
  remaining=$(echo "$state" | jq -r '.egg.sessions_remaining')

  if [ "$remaining" -le 0 ]; then
    # Retire the parent
    local name level born total_sessions
    name=$(engine_get_field "$state" '.creature.name')
    level=$(echo "$state" | jq -r '.creature.level')
    born=$(engine_get_field "$state" '.creature.born')
    total_sessions=$(echo "$state" | jq -r '.creature.total_sessions')

    local today
    today=$(date -u +"%Y-%m-%d")
    local born_date
    born_date=$(echo "$born" | cut -dT -f1)

    # Add to lineage as retired
    state=$(echo "$state" | jq \
      --arg name "$name" \
      --argjson level "$level" \
      --arg born "$born_date" \
      --arg retired "$today" \
      --argjson sessions "$total_sessions" '
      .lineage += [{
        name: $name,
        level: $level,
        born: $born,
        died: $retired,
        cause: "retired",
        sessions: $sessions
      }]
    ')

    # Promote egg to creature with retirement bonus
    local egg_name egg_theme
    egg_name=$(echo "$state" | jq -r '.egg.name')
    egg_theme=$(echo "$state" | jq -r '.egg.theme')
    local bonus_xp=$(( level * 3 + (total_sessions > 10 ? 10 : total_sessions) ))
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local max_hp=85

    state=$(echo "$state" | jq \
      --arg name "$egg_name" \
      --arg theme "$egg_theme" \
      --arg now "$now" \
      --argjson max_hp "$max_hp" \
      --argjson bonus_xp "$bonus_xp" '
      .creature = {
        name: $name,
        level: 1,
        xp: $bonus_xp,
        hp: $max_hp,
        max_hp: $max_hp,
        mood: "happy",
        theme: $theme,
        born: $now,
        last_session: $now,
        streak_days: 0,
        total_sessions: 0,
        sessions_at_max: 0
      } |
      del(.egg)
    ')

    engine_write_state "$state"
    echo "RETIRED:${name}:${level}:${egg_name}"
    return 0
  else
    # Decrement remaining sessions
    state=$(echo "$state" | jq '.egg.sessions_remaining = (.egg.sessions_remaining - 1)')
    engine_write_state "$state"
    return 1
  fi
}

# --- Mood ---

engine_get_mood() {
  local state
  state=$(engine_read_state)

  local errors tool_calls streak
  errors=$(echo "$state" | jq -r '.session.errors // 0')
  tool_calls=$(echo "$state" | jq -r '.session.tool_calls // 0')
  streak=$(echo "$state" | jq -r '.creature.streak_days // 0')

  # Priority: stressed > tired > sleepy > proud > happy
  # Stressed: error rate > 40%
  if [ "$tool_calls" -gt 0 ]; then
    local error_rate=$(( (errors * 100) / tool_calls ))
    if [ "$error_rate" -gt 40 ]; then
      echo "stressed"
      return
    fi
  fi

  # Tired: checked by caller via context_window percentage (not available in state)
  # Sleepy: checked by caller via idle time (not available in state)

  # Proud: streak > 7
  if [ "$streak" -gt 7 ]; then
    echo "proud"
    return
  fi

  echo "happy"
}

engine_update_mood() {
  local mood="${1:-happy}"
  local state
  state=$(engine_read_state)
  state=$(echo "$state" | jq --arg mood "$mood" '.creature.mood = $mood')
  engine_write_state "$state"
}

engine_update_last_session() {
  local state
  state=$(engine_read_state)
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  state=$(echo "$state" | jq --arg now "$now" '.creature.last_session = $now')
  engine_write_state "$state"
}
