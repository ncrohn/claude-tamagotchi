# Privacy Policy

**claude-tamagotchi** stores all data locally on your machine. No data is collected, transmitted, or shared with any external service.

## What is stored

All data is written to `~/.claude/tamagotchi/` on your local filesystem:

- **state.json** — Creature stats (name, level, XP, HP, mood, streak, session counters) and lineage history
- **display.txt** — Pre-rendered status line segment (regenerated from state.json)
- **themes/** — Theme configuration files (JSON)

## What is NOT collected

- No analytics or telemetry
- No network requests
- No data leaves your machine
- No personal information is stored beyond a creature name you choose

## Data retention

All data persists until you manually delete `~/.claude/tamagotchi/`. Uninstalling the plugin stops the hooks but does not delete your data.

## Contact

For questions, open an issue at https://github.com/ncrohn/claude-tamagotchi/issues.
