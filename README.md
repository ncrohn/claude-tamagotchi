# claude-tamagotchi

A persistent Tamagotchi creature that lives in your Claude Code status line. It evolves through emoji stages, has session-level moods, and can die from neglect — leaving behind an egg with inherited XP for the next generation.

```
🥚 Nugget ▰▰▰▰▰▰ ⬆1    (freshly hatched)
🐥 Nugget ▰▰▰▰▱▱ ⬆3    (growing up)
💀 Nugget ▱▱▱▱▱▱ ⬆3    (neglected too long)
```

## Install

```bash
/plugin install ncrohn/claude-tamagotchi
```

On your next session, a creature will hatch automatically with a random name and theme. You won't know what it is until Level 2 — every creature starts as an egg.

## Status Line Setup

After install, run `/tamagotchi setup` to add the creature to your status line. Or manually add this line to your `~/.claude/statusline-command.sh`:

```bash
# Tamagotchi creature
if [ -f "$HOME/.claude/tamagotchi/display.txt" ]; then
  status+="$(cat "$HOME/.claude/tamagotchi/display.txt")"
fi
```

If you don't have a custom status line script yet, run `/statusline` in Claude Code to set one up first.

## How It Works

### Lifecycle

Your creature is **persistent** — it lives across sessions and ages over time. Each session affects its mood, while long-term patterns affect its health and growth.

**Session-level factors** (affect mood and display color):
- Error rate in tool calls (stressed when things break)
- Conversation length
- Usage streaks (proud after 7+ consecutive days)

**Long-term factors** (affect HP and XP):
- Daily usage keeps your creature healthy (+10 HP per session)
- Streaks give bonus recovery (+5 HP when streak > 3 days)
- Neglect causes HP decay (-5 HP/day after a 2-day grace period)
- XP is earned each session based on turns and tool usage

### Evolution

Creatures evolve through 5 emoji stages as they level up. Theme is random on each hatch:

| Level | Default | Cat | Dragon | Plant |
|-------|---------|-----|--------|-------|
| 1 | 🥚 | 🥚 | 🥚 | 🥚 |
| 2 | 🐣 | 🐱 | 🐛 | 🌱 |
| 3 | 🐥 | 😺 | 🦎 | 🌿 |
| 4 | 🐔 | 🐈 | 🐉 | 🪴 |
| 5 | 🦅 | 🐈‍⬛ | 🐲 | 🌳 |

### Death & Inheritance

If your creature's HP reaches 0 (from extended neglect), it dies. But it leaves behind an egg that hatches into a new creature with a small XP bonus based on its parent's level. Your lineage is tracked — run `/tamagotchi history` to see all past generations.

## Commands

| Command | Description |
|---------|-------------|
| `/tamagotchi` | View creature stats, HP, XP, streak, and lineage |
| `/tamagotchi setup` | Auto-integrate with your status line script |
| `/tamagotchi rename <name>` | Rename your creature |
| `/tamagotchi theme` | Browse themes and set preference for next hatch |
| `/tamagotchi history` | Full lineage across all generations |

## Custom Themes

Create your own theme by adding a JSON file to `~/.claude/tamagotchi/themes/`:

```json
{
  "name": "ocean",
  "emoji": ["🥚", "🐚", "🦐", "🐠", "🐋"],
  "levels": [1, 2, 3, 4, 5]
}
```

The first emoji should always be `🥚` to preserve the surprise on hatch.

## How State Works

All creature state lives in `~/.claude/tamagotchi/state.json`, outside the plugin cache. This means:

- State survives plugin updates and reinstalls
- Uninstalling the plugin stops the hooks but doesn't delete your creature
- The status line reads a pre-rendered `display.txt` file for near-zero overhead

## Uninstall

```bash
/plugin uninstall claude-tamagotchi
```

Then remove the Tamagotchi lines from your `~/.claude/statusline-command.sh`. Optionally delete `~/.claude/tamagotchi/` to remove all creature state.
