# Cluck & Worms — Upgrade Report

## 1. What was wrong / incomplete

- Chicken sat on the worm path (nest vs path collision).
- Matched worms fell while still parented to the marching chain (pops slid).
- Pause froze mid-cascade resolve; win overlays did not pause the tree.
- Game Over “Try Again” restarted the whole stage from level 0 with wiped score.
- No level select, stars, settings, deep save, special worms, or music hooks.
- Save only stored high score / stages cleared.
- Campaign stopped at 12 levels with limited late-game variety.

## 2. Core Zuma mechanics changed

- Nest-safe paths + clearance clamp (`PathFactory`).
- Falling worms reparent to `FX` and move in world space.
- Shot resolve continues during pause; march stops.
- Level/stage/game-over pause the scene tree.
- March tension near the pit + Slow special worm.
- Rainbow wildcard matching; Bomb neighbor clear; Bonus score; Slow timer.
- Central `Scoring` autoload for match points and star ratings.
- Danger warning signal → path pulse + HUD text.

## 3. Visual / UI

- Color accessibility marks + special badges on worms.
- Campaign level select with locks/stars.
- Settings: volume, mute, reduced shake/FX.
- Main menu: Play (continue), Campaign, Settings.
- Level clear shows ★☆ stars.
- Path danger zone pulses under pressure.

## 4. New content / mechanics implemented

- **Specials:** Rainbow, Bomb, Slow, Bonus (chain spawns from level 5+).
- **Stars:** 1–3 per level, persisted.
- **Achievements:** combo / cascade / three-star / stage clear (local flags).
- **Campaign:** 18 levels across 4 stages (Moonlit Garden added).

## 5. Key files touched

- `autoload/` — SaveService, GameManager, Scoring, JuiceDirector, EventBus, QualitySettings
- `scripts/chain/WormChain.gd`, `scripts/worm/Worm.gd`, `resources/worm/WormType.gd`
- `scripts/level/PathFactory.gd`, `PathGuide.gd`, `LevelData.gd`, `ProgressionCatalog.gd`
- `scripts/ui/*`, `scenes/ui/*`, `scenes/main/Main.tscn`
- `tests/run_core_tests.gd`, `docs/UPGRADE_REPORT.md`

## 6. Tests / builds

| Check | Result |
| --- | --- |
| Core rules test (`res://tests/TestRunner.tscn`) | **PASSED** (10/10 assertions verified) |
| Scene smoke test (`res://tests/SmokeTestRunner.tscn`) | **PASSED** (13/13 scenes instantiated cleanly) |
| In-editor Play (F5) | Verified scene tree & autoload configuration |
| Web export | Preset present (`export_presets.cfg`) |

## 7. Still needs attention

- Interactive tutorial (flags exist; full guided level not shipped).
- Background music loops (hooks & procedural audio exist; no custom mp3/ogg tracks yet).
- Expand toward 30 levels when art/path time allows.
- Desktop export presets.
- Formal GdUnit suite for insert/cascade edge cases.

## 8. How to run / export

1. Open project in Godot 4.3+ (GL Compatibility).
2. Press **F5** to run `res://scenes/main/Main.tscn`.
3. Web: **Project → Export → Web (HTML5)** → `builds/web/`.
4. Automated tests:
   - `godot --headless --path . "res://tests/TestRunner.tscn"`
   - `godot --headless --path . "res://tests/SmokeTestRunner.tscn"`
