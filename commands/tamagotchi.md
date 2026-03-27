---
name: tamagotchi
description: View and manage your Tamagotchi creature — stats, rename, theme, setup, history
allowed-tools: Read, Write, Edit, Bash
argument-hint: "[setup|rename <name>|theme|history]"
---

# Tamagotchi Command

Manage your Tamagotchi creature that lives in the Claude Code status line.

## State File

The creature state is at `~/.claude/tamagotchi/state.json`. Read it to get current creature info.

## Subcommands

Parse the user's argument to determine which subcommand to run:

### No arguments (default) — Show Stats

Read `~/.claude/tamagotchi/state.json` and display a formatted summary:

```
🐥 Chip — Level 3 (120/150 XP)
HP: ▰▰▰▰▰▰▰▰▱▱ 85/95
Mood: happy
Streak: 5 days
Sessions: 42 total
Born: 2026-03-27
Theme: default (🥚 → 🐣 → 🐥 → 🐔 → 🦅)

Lineage:
  Gen 1: Byte — Lv 7, 89 sessions (2026-02-01 → 2026-03-15, neglect)
```

Calculate the XP needed for next level as `current_level * 50`. Show the creature's emoji from its theme file at `~/.claude/tamagotchi/themes/<theme>.json`. Show the health bar as filled/empty blocks proportional to HP/max_HP (10 blocks for the detailed view).

### `setup` — Status Line Integration

1. Check if `~/.claude/statusline-command.sh` exists
2. Read the file and find the mood emoji section (look for the line containing `mood_emoji`)
3. Insert the following BEFORE the mood emoji section:
   ```bash
   # Tamagotchi creature
   if [ -f "$HOME/.claude/tamagotchi/display.txt" ]; then
     status+="$(cat "$HOME/.claude/tamagotchi/display.txt")"
   fi
   ```
4. Show the user a diff of what will change
5. Ask for confirmation before writing
6. If the user doesn't have a statusline-command.sh, inform them they can add this line to any status line script, or create a minimal one

### `rename <name>` — Rename Creature

1. Read state.json
2. Update `.creature.name` with the new name
3. Write state.json
4. Run `bash ~/.claude/tamagotchi/bin/tamagotchi-render.sh` to update display
5. Confirm the rename

### `theme` — Manage Themes

1. List all `.json` files in `~/.claude/tamagotchi/themes/`
2. For each, show the name and emoji sequence
3. Note which theme the current creature is using
4. Explain that new themes apply to the NEXT hatch (not current creature)
5. To set a preferred theme for next hatch, update `.config.theme` in state.json (use "random" for random selection)
6. Show the format for creating custom themes:
   ```json
   {
     "name": "mytheme",
     "emoji": ["🥚", "stage2", "stage3", "stage4", "stage5"],
     "levels": [1, 2, 3, 4, 5]
   }
   ```
   Save as `~/.claude/tamagotchi/themes/mytheme.json`

### `history` — Full Lineage

Read state.json and display the full lineage array plus current creature as the latest generation:

```
Generation 1: Byte
  Level 7 | 89 sessions | default theme
  Born: 2026-02-01 | Died: 2026-03-15
  Cause of death: neglect

Generation 2: Chip (current)
  Level 3 | 42 sessions | default theme
  Born: 2026-03-27 | Streak: 5 days
  HP: 85/95 | XP: 120/150
```
