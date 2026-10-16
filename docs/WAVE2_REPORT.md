# Cluck & Worms — Wave 2 Implementation Report

## Audit summary (before wave 2)

Working from wave 1: chain reverse, 15-level campaign, 3 bosses, loading screen, stars/save, gauntlet.

Gaps addressed: player abilities, alternate objectives/modifiers, boss uniqueness, achievement UI, stats, daily/practice, stage music hooks.

## Implemented this session

### Gameplay depth
- **Slow Pulse [Q]** and **Bomb Blast [E]** with limited charges, HUD buttons, SFX, real chain effects (`apply_slow`, `detonate_at_nearest`).
- Large-match score bonus (≥6) + precision achievement.
- Objective HUD + tip on level start.

### Campaign variety
- `LevelObjective` kinds: clear, boss, score, survive, limited shots, combo.
- Modifiers: accelerating chain, speed multiplier, color cap, tight palette, no specials, bonus charges.
- Catalog levels now mix objectives (not speed-only variants).

### Bosses
- Guardian: telegraph + root surge + vulnerability pulse.
- Queen: **royal brood** injects special rear worms + armor.
- Rooster: stare hold + fury + spawn flood + vulnerability recovery.

### Meta / replay
- Achievement toast + expanded catalog (`AchievementCatalog`).
- Lifetime stats + `StatsUI` (menu **STATS**).
- **Daily** (date-seeded level) and **Practice** (infinite spawn, no unlock writes).
- Stage procedural music beds (replaceable via `AudioManager.register_stream`).

### Controls
| Input | Action |
| --- | --- |
| Q | Slow Pulse |
| E | Bomb Blast |

## Tests run

Godot 4.7.2 at `Downloads\Godot_v4.7.2-stable_win64.exe\…_console.exe` (when available):

- Import / class registration
- `TestRunner.tscn`, `SmokeTestRunner.tscn`, `run_chain_tests.gd`, `run_meta_tests.gd`

## Known limitations
- Stage music beds are procedural loops — swap real oggs for production.
- Full interactive playtest of every objective/boss still recommended in-editor.
- Geographic campaign path map remains grid+tabs (not a world map).
- `run_core_tests.gd --script` still lacks autoloads; use `TestRunner.tscn`.
