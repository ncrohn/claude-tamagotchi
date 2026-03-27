#!/bin/bash
# Tamagotchi Renderer — Reads state, outputs ANSI status line segment
# Also writes pre-rendered output to display.txt for fast status line reads

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
STATE_FILE="$TAMAGOTCHI_DIR/state.json"
DISPLAY_FILE="$TAMAGOTCHI_DIR/display.txt"

# Gruvbox palette (matches common Claude Code status line theme)
COLOR_GREEN='#b8bb26'
COLOR_YELLOW='#d79921'
COLOR_RED='#fb4934'
COLOR_ORANGE='#d65d0e'
COLOR_GRAY='#928374'
COLOR_DIM='#504945'
COLOR_FG='#fbf1c7'
COLOR_BG1='#3c3836'
COLOR_BRIGHT_GREEN='#98971a'

hex_to_fg() {
  local hex="${1#\#}"
  printf "\033[38;2;%d;%d;%dm" $((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))
}

hex_to_bg() {
  local hex="${1#\#}"
  printf "\033[48;2;%d;%d;%dm" $((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))
}

RESET="\033[0m"
BOLD="\033[1m"

render() {
  if [ ! -f "$STATE_FILE" ]; then
    printf ""
    return
  fi

  local state
  state=$(cat "$STATE_FILE")

  local hp max_hp level name mood theme
  hp=$(echo "$state" | jq -r '.creature.hp // 0')
  max_hp=$(echo "$state" | jq -r '.creature.max_hp // 85')
  level=$(echo "$state" | jq -r '.creature.level // 1')
  name=$(echo "$state" | jq -r '.creature.name // "???"')
  mood=$(echo "$state" | jq -r '.creature.mood // "happy"')
  theme=$(echo "$state" | jq -r '.creature.theme // "default"')

  # Get emoji for current level
  local emoji
  local theme_file="$TAMAGOTCHI_DIR/themes/${theme}.json"
  if [ -f "$theme_file" ]; then
    local emoji_count
    emoji_count=$(jq -r '.emoji | length' "$theme_file")
    local idx=$(( level - 1 ))
    [ $idx -ge "$emoji_count" ] && idx=$(( emoji_count - 1 ))
    [ $idx -lt 0 ] && idx=0
    emoji=$(jq -r ".emoji[$idx]" "$theme_file")
  else
    emoji="🥚"
  fi

  # Dead state override
  if [ "$hp" -le 0 ]; then
    emoji="💀"
    mood="dead"
  fi

  # Health bar: 6 blocks
  local filled=0
  if [ "$max_hp" -gt 0 ] && [ "$hp" -gt 0 ]; then
    filled=$(( (hp * 6 + max_hp - 1) / max_hp ))  # Round up
    [ $filled -gt 6 ] && filled=6
    [ $filled -lt 0 ] && filled=0
  fi
  local empty=$(( 6 - filled ))

  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar+="▰"; done
  for (( i=0; i<empty; i++ )); do bar+="▱"; done

  # Color based on mood
  local color
  case "$mood" in
    stressed) color="$COLOR_RED" ;;
    tired)    color="$COLOR_YELLOW" ;;
    sleepy)   color="$COLOR_GRAY" ;;
    proud)    color="$COLOR_BRIGHT_GREEN" ;;
    dead)     color="$COLOR_DIM" ;;
    *)        color="$COLOR_GREEN" ;;  # happy
  esac

  local fg bg
  fg=$(hex_to_fg "$color")
  local bg_color
  bg_color=$(hex_to_bg "$COLOR_BG1")

  # Format: 🐥 Chip ▰▰▰▰▱▱ ⬆3
  local segment
  segment="${bg_color} ${emoji} ${fg}${BOLD}${name}${RESET}${bg_color} ${fg}${bar}${RESET}${bg_color} ${fg}⬆${level}${RESET}${bg_color} ${RESET}"

  printf "%b" "$segment"
}

# Render and write to display file
output=$(render)
printf "%b" "$output" > "$DISPLAY_FILE"
printf "%b" "$output"
