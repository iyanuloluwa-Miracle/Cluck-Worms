# Cluck & Worms: Final Upgrade Report

Engine: Godot 4.7.2 (GL Compatibility). Every result below was produced by running the game and its test suites headlessly with the official 4.7.2 console build on Windows, plus screenshot captures from the windowed build.

## 1. The chain-reversal bug

### Root cause

The old chain treated all worms as **one packed train**. After a match it re-packed the rear worms into slots directly behind the leader and surged them forward (`MAGNETIC_SURGE`) to fill the hole, while the whole train kept marching forward through the flash and collapse. The front never actually moved backward along the path; `Worm.State.RETRACTING` was only an animation state. That produced the reported symptoms: the rear lunged forward instead of the front reversing, gaps closed regardless of color, and bomb clears skewed the collapse point because expanded match indices left of the group start were ignored.

### How reversal works now (`scripts/chain/WormChain.gd`)

- Each worm's logical position is `target_path_distance` along the curve. **Segments** are runs of worms whose spacing is within `worm_spacing + JOIN_EPSILON`.
- Only the **rearmost segment** is pushed by the march (`_advance_rear_segment`, with tension near the pit, slow and intro roll).
- A match removes worms and leaves a real gap. For each gap, `_process_reverse` checks the two edge worms (`_colors_link`: same color, or a Rainbow). If they link, the front segment **rolls backward**, starting at 140 px/s and accelerating at 1100 px/s² up to 620 px/s, and never moves past the worm behind it. If they don't link, the front stands still and the rear closes the gap at march speed.
- `_resolve_contacts` pushes worms apart so they never overlap, snaps closed joins to exact spacing, emits `chain_collapse_finished` for reversals, and runs `_check_join`. A match at the join removes the run with an increased cascade depth, which can start the next reversal.
- The level can't be lost at the pit while a shot, match, reversal or gap-close is still resolving. Lose and win checks only run once the chain is settled.

Edge cases covered by the chain tests:
- Matches at the chain head and tail.
- Non-matching gaps: no reversal; the rear catches up instead.
- Two quick shots resolving independently.
- Insertion into a reversing segment.
- A new rear worm matching the gap color.
- Rainbow wildcards.
- A cascade from a reverse join.
- A saving match near the pit not counting as a loss.
- Tunnel-hidden worms.
- Clearing the chain.
- A 6 × 900-step randomized fuzz that checks spacing, indices and counts.

## 2. Features delivered

**Visual identity and UI**
- Animated `GameLogo`: the letters drop in and bob, and a worm wriggles through the "&". It respects reduced effects.
- Main menu with a greeting and progress summary ("Best X · ★ s/45 · c/15 levels cleared").
- Gradient vignettes replace the hard-edged bands.

**HUD**
- Stone navbar.
- Progress bar based on what is actually left on the field.
- Combo counter, shown only when it is above ×1.
- Objective line.
- Level and stage intro banner.
- Compact boss panel showing name, health, phase and status.

**Loading screen**
- Custom boot screen that loads `Main.tscn` on a background thread and shows tips.

**Campaign**
- 3 stages × 5 levels, all defined in `ProgressionCatalog`.
- Objectives: clear, score, survive, limited shots and combo.
- Modifiers: acceleration, speed, color cap, tight palette, no specials and bonus charges.
- Boss levels use their own arena paths kept below the HUD.

**Bosses (`scripts/boss/BossController.gd`)**
- Modes: INTRO (immune), IDLE, TELEGRAPH (warning ring, shielded), ATTACK and DEFEATED.
- Damage comes from chain matches (scaled by cascade depth) and from direct shots at the boss body.
- A phase floor stops one big hit from skipping a phase.
- Feedback: hit flash, "BLOCKED"/"SHELL!" text, and status updates in the panel.
- The defeat sequence pops the remaining chain and finishes the stage after 1.8 s.
- Garden Guardian:
  - *Root Surge* speeds up the chain; phase 2 also adds worms at the rear.
  - A weak window (double damage) follows each attack.
- Worm Queen:
  - A crest-color shell blocks every other color.
  - *Royal Brood* adds special worms; *Royal Decree* (phase 2 and later) recolors part of the chain.
- Golden Rooster:
  - *Fury Dash* surges the chain.
  - *Egg Barrage* (phase 2 and later) lays eggs that hatch 2 worms after 5.5 s unless you shoot them.
  - *Golden Stare* (phase 3) holds the chain, then releases it.

**Level select and progression**
- Stage tabs and level cards with stars.
- Locked levels can't be started, from the UI or from code.
- Best score is compared against the score from before the run.

**Game loop screens**
- Pause, level complete (level points, run total, new best), game over and stage complete ("Next Stage →" plus what was unlocked).
- The final boss shows **Campaign Complete!** with stars out of 45 and the final score.

**Stage presentation**
- `StageBackdrop` draws procedural scenery per stage: Backyard lawn, Wild Garden fireflies and mushrooms, Forbidden Coop planks, straw and lanterns.
- Boss levels add a spotlight.

**Audio**
- `MusicComposer` renders 4 deterministic looping tracks: Backyard (G major, 112 bpm), Garden (A minor, 100 bpm), Coop (E minor, 92 bpm, swing) and Boss (C minor, 132 bpm).
- Tracks render on a worker thread, or in 3 ms slices per frame on the single-threaded web build, then replace the drone fallback without a gap.
- Master, music and SFX volumes are independent and saved.

**Game feel**
- Gentler camera shake (none on routine shots).
- Floating text is placed at the actual match or reversal spot and no longer stacks on top of itself.

**Accessibility and keyboard**
- Full keyboard and focus navigation in menus, overlays and level select, with a visible focus ring.
- During play, buttons never steal focus, so Space always swaps worms. Before this fix, clicking an ability button broke Space.
- Reduced-effects option.

## 3. Content counts

| Item | Count |
| --- | --- |
| Stages | 3 (The Backyard, The Wild Garden, The Forbidden Coop) |
| Levels | 15 (5 per stage) |
| Bosses | 3: Garden Guardian (2 phases), Worm Queen (3), Golden Rooster (3) |
| Music tracks | 4 composed (one per stage + boss) |
| Stars available | 45 |

## 4. Saving

- `SaveService` writes `user://cluck_and_worms_save.cfg` with `save_version = 2`.
- It stores stars and best score per level, unlocks, stage clears, settings, achievements, leaderboard and lifetime stats.
- On load every value is type-checked and clamped. `sanitize_against_campaign` drops stars for level IDs that no longer exist and clamps unlocks to real level numbers, so corrupt or outdated saves can't break progression.
- Stat writes are batched (2 s flush) instead of hitting the disk on every event.
- Practice mode never writes progress.

## 5. Files changed

**New**
- Boss and progression: `scripts/boss/BossController.gd`, `resources/progression/BossDef.gd`, `resources/progression/LevelObjective.gd`
- Stage, logo and music: `scripts/level/StageBackdrop.gd`, `scripts/ui/GameLogo.gd`, `scripts/audio/MusicComposer.gd`
- Screens: `scripts/ui/LoadingScreen.gd` + `scenes/ui/LoadingScreen.tscn`, `scripts/ui/StatsUI.gd` + `scenes/ui/StatsUI.tscn`
- Achievements: `resources/meta/`
- Tests: `tests/game_flow_tests.gd` + `GameFlowTestRunner.tscn`, `tests/run_chain_tests.gd` + `ChainTestRunner.tscn`, `tests/bench_music.gd`, `tests/visual_capture.gd` + `VisualCapture.tscn`
- Tooling: `tools/run_tests.ps1`

**Modified**
- Autoloads: `autoload/EventBus.gd`, `GameManager.gd`, `AudioManager.gd`, `JuiceDirector.gd`, `SaveService.gd`
- Gameplay: `scripts/chain/WormChain.gd`, `scripts/projectile/ShootingWorm.gd`, `scripts/chicken/Chicken.gd`, `scripts/chicken/AimGuide.gd`, `scripts/level/Level.gd`, `scripts/level/PathFactory.gd`
- Progression data: `resources/progression/LevelData.gd`, `ProgressionCatalog.gd`
- UI scripts: `HUD.gd`, `HudNavbar.gd`, `MainMenuUI.gd`, `LevelSelectUI.gd`, `LevelCompleteUI.gd`, `StageCompleteUI.gd`, `PauseUI.gd`, `InstructionsUI.gd`, `OverlayBase.gd`, `UITheme.gd` and `MenuAtmosphere.gd`, all in `scripts/ui/`
- Scenes: `scenes/ui/HUD.tscn`, `scenes/main/Main.tscn`
- Project and tests: `project.godot`, `tests/TestRunner.gd`, `tests/run_core_tests.gd`, `tests/smoke_test_scenes.gd`
- Docs: `README.md`, `docs/RELEASE.md`, this report

## 6. Tests run

All suites were run with `tools/run_tests.ps1` (Godot 4.7.2 console, headless). The game-flow suite was re-run on its own after the final music assertions were added.

| Suite | Checks | Result |
| --- | --- | --- |
| Core (`TestRunner.tscn`) | 14 | Pass |
| Chain (`ChainTestRunner.tscn`) | 51 | Pass |
| Game flow (`GameFlowTestRunner.tscn`) | 75 | Pass |
| Scene smoke (`SmokeTestRunner.tscn`) | 17 scenes | Pass |
| Meta (`run_meta_tests.gd`) | 18 | Pass |
| Music bench (`bench_music.gd`) | 5 | Pass |

**What the game-flow suite covers**
- Level start, complete and fail.
- Lock enforcement.
- Star and best-score saving.
- Stage unlocks.
- Each boss:
  - Intro immunity.
  - Direct-shot damage.
  - Telegraph shield and weak-window multiplier.
  - Every phase reached in order.
  - Defeat pops the chain.
  - The stage completes only after the defeat sequence.
- Boss-specific mechanics: the Queen's shell color rule and the Rooster's eggs (shooting them and letting them hatch).
- Campaign finale screen.
- Keyboard focus and the Space-key swap.
- Composed music replacing every drone, with a seamless boss loop.

The only warning in the logs is the expected `GameManager: level 11 is locked`, produced on purpose by the lock-enforcement test.

**Visual checks:** the capture harness ran the menu, level select, every stage, all three boss fights and the overlay screens at 1280×720, 1920×1080, 1024×768 and 1600×720 with no script errors. I reviewed the screenshots for layout overlap, HUD clearance on boss paths and readability.

**Not verified:** hands-on human playtesting for difficulty and feel, a real browser run of the web export, and touch input on a physical device.

## 7. Known issues and follow-ups

- **Web music:** the per-frame music composition path (single-threaded web) is covered by the incremental==blocking bench but hasn't been tried in a browser build. The drone fallback plays until composition finishes.
- **Art and music are procedural:** bosses, scenery and music are generated in code. Recorded music and illustrated boss art would raise the quality bar; `AudioManager.register_stream()` and the `_draw` functions are the swap points.
- **Difficulty tuning:** the balance of the later Coop levels and the Rooster's phase 3 comes from automated runs, not human playtesting.
- **Old saves:** saves from the earlier 18-level / 4-stage layout lose stars for retired level IDs (unlocks are clamped safely).
- **Unused tutorial:** the `tutorial_done` flag exists, but there is no guided in-level tutorial (the How to Play screen covers controls).
- **No desktop export:** only the Web preset exists.
- `docs/WAVE2_REPORT.md` is an earlier intermediate report; this document supersedes it.
