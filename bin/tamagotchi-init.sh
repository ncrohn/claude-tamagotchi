#!/bin/bash
# Tamagotchi Init — First-run setup
# Creates directory structure, copies files, creates first creature

TAMAGOTCHI_DIR="$HOME/.claude/tamagotchi"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create directory structure
mkdir -p "$TAMAGOTCHI_DIR/bin" "$TAMAGOTCHI_DIR/themes"

# Copy bin scripts to stable path
cp "$PLUGIN_DIR/bin/tamagotchi-engine.sh" "$TAMAGOTCHI_DIR/bin/"
cp "$PLUGIN_DIR/bin/tamagotchi-render.sh" "$TAMAGOTCHI_DIR/bin/"
cp "$PLUGIN_DIR/bin/tamagotchi-init.sh" "$TAMAGOTCHI_DIR/bin/"
chmod +x "$TAMAGOTCHI_DIR/bin/"*.sh

# Copy themes
for theme_file in "$PLUGIN_DIR/themes/"*.json; do
  [ -f "$theme_file" ] && cp "$theme_file" "$TAMAGOTCHI_DIR/themes/"
done

# Source engine and create first creature
source "$TAMAGOTCHI_DIR/bin/tamagotchi-engine.sh"
name=$(engine_create_creature)

# Render initial display
bash "$TAMAGOTCHI_DIR/bin/tamagotchi-render.sh" > /dev/null 2>&1

# Print welcome message
echo "🥚 A new creature has hatched! Meet ${name}!" >&2
echo "Customize with /tamagotchi — run /tamagotchi setup to add it to your status line." >&2
