# Cluck & Worms

A Zuma-style 2D puzzle game: a cartoon chicken at the center of the yard fires colored worms into a chain that crawls along a path toward the nest. Match three or more to pop them, set up chain reactions, and beat a boss at the end of every stage.

Built and tested with **Godot 4.7.2** (GL Compatibility renderer, 1280×720 base viewport with `canvas_items` stretch / `keep` aspect). The web export is single-threaded so it runs on itch.io, Poki, CrazyGames and mobile browsers without cross-origin isolation headers.

---

## Requirements

- [Godot 4.7](https://godotengine.org/download) (the project uses 4.7 features; older 4.x versions are not supported)
- Web export templates (`Editor → Manage Export Templates`) for HTML5 builds

---

## Arcade upgrade (October 2026)

The latest changes add first-contact collision, consistent touch aiming, live field training,
current/next ammo with shape cues, a garden art pass, cached scenery and worm artwork, mode-preserving
retry, fair final-shot resolution, and safer save retries.

See [the implementation report](docs/ARCADE_UPGRADE_REPORT.md) and open
[the before/after visual review](docs/visual-review.html). The existing 15-level campaign,
three bosses, separate music/SFX volume controls, and saves remain in place.

## How to run

1. Open the project folder in Godot (`Project → Import`).
2. Press **F5**. The custom loading screen boots first and loads the main scene in the background, then the animated main menu appears.
3. Pick **Adventure** to open the level select.

| Input | Action |
| --- | --- |
| Mouse / tap | Aim and shoot |
| Right click / Space / tap the chicken | Swap current and next worm |
| Q | Slow Pulse (limited charges) |
| E | Bomb Blast (limited charges) |
| Esc / P / HUD menu button | Pause |
| Arrow keys / Tab + Enter, Esc | Navigate menus and level select, go back |

**Modes:** Adventure (the 15-level campaign), Gauntlet (arcade-styled straight run through the campaign), Daily (date-seeded level), Practice (infinite worms, never writes progress), Stats (lifetime stats and achievements).

---

## Campaign

**3 stages × 5 levels = 15 levels. Level 5 of every stage is a boss fight.** Each stage has its own procedural backdrop, music track and palette.

| Stage | Levels | Boss |
| --- | --- | --- |
| The Backyard | 1–5 | Garden Guardian |
| The Wild Garden | 6–10 | Worm Queen |
| The Forbidden Coop | 11–15 | Golden Rooster |

Normal levels use one of several objectives (clear the chain, reach a score, survive, limited shots, combo) plus optional modifiers (accelerating chain, speed multiplier, color cap, no specials, bonus charges). Every level awards 1–3 stars. Clearing a level unlocks the next one; clearing a boss unlocks the next stage. The final boss ends in a **Campaign Complete** screen.

**Chain specials:** Rainbow (wildcard), Bomb (clears neighbors), Slow, Bonus.

### Bosses

Every boss has an intro (immune while it is announced), a health bar with phases, telegraphed attacks, damage feedback and a defeat sequence that pops the remaining chain. Damage comes from matches made in the chain (cascades hit harder) and from shooting the boss directly.

- **Garden Guardian:** shields itself while telegraphing a *Root Surge* (the chain speeds up; phase 2 also injects worms at the rear). It is weak (double damage) right after each attack.
- **Worm Queen:** wears a shell that blocks every color except her current crest color. *Royal Brood* injects special worms; from phase 2, *Royal Decree* recolors part of the chain.
- **Golden Rooster:** *Fury Dash* surges the chain; from phase 2 *Egg Barrage* lays eggs that hatch extra worms unless you shoot them; in phase 3 *Golden Stare* holds the chain still and then releases it.

---

## How the chain reverse works

The chain is modeled as **segments**: worms that touch each other along the path. Only the rearmost segment is pushed forward by the march. When a match removes worms it opens a gap, and the front segment just stands still. If the two worms on either side of the gap have the **same color** (or one is a Rainbow), the front segment **rolls backward** along the path, accelerating until it meets the rear segment. When it lands, the new contact is checked for a match, which can cascade into further reversals. If the colors don't match, the front stays put and the rear closes the gap at march speed. A level can't be lost while a match, reversal or gap-close is still resolving.

---

## Adding levels

All levels reuse `scenes/level/Level.tscn`; content is data-only.

1. **Path:** add a helper to `scripts/level/PathFactory.gd` (1280×720 playfield; keep the top of the path below `BOSS_TOP_SAFE` on boss levels so the boss panel stays clear).
2. **Level:** in `resources/progression/ProgressionCatalog.gd → build_campaign()`, call `_level(...)` or `_boss_level(...)` and append it to the stage's `levels` array.
3. **Bosses:** `_boss_level` takes a `BossDef` (`garden_guardian`, `worm_queen`, `golden_rooster`), which supplies the arena path, chicken position, health, phases and attacks used by `scripts/boss/BossController.gd`.

---

## Replacing art and audio

Most visuals are procedural: worms (`Worm.gd`), chicken (`ChickenBody.gd`), bosses (`BossController._draw`), stage scenery (`StageBackdrop.gd`), logo (`GameLogo.gd`). Keep collision radii (`Worm.HEAD_RADIUS`, `ShootingWorm.hit_radius`, `BossDef` radius) in line with any new sprite sizes.

Music is composed procedurally at startup by `scripts/audio/MusicComposer.gd` (one looping track per stage plus a boss track) and replaces a simple drone fallback once it is ready. Register recorded tracks or SFX with `AudioManager.register_stream()` to override them. Music, SFX and master volumes are independent and saved.

---

## Saving

`SaveService` writes `user://cluck_and_worms_save.cfg` (save version 2): stars and best score per level, unlocks, stage clears, settings (volumes, reduced effects, etc.), achievements, leaderboard and lifetime stats. On load the data is validated and clamped to the current campaign (`sanitize_against_campaign`), so a corrupt or outdated save can't unlock missing levels. Stat updates are batched and flushed every 2 seconds instead of on every event.

---

## Automated tests

Run every suite headlessly from PowerShell:

```powershell
$env:GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
.\tools\run_tests.ps1
```

This imports the project, then runs eight suites and saves full logs in docs/test-results/:

| Suite | Covers |
| --- | --- |
| `tests/TestRunner.tscn` | Core: scoring, catalog, save round-trip |
| `tests/ChainTestRunner.tscn` | Chain insert, matching, reversal, cascades, edge cases, fuzzing |
| `tests/GameFlowTestRunner.tscn` | Full loop: level start/complete/fail, unlocks, all 3 bosses, campaign finale, keyboard focus, composed music |
| `tests/SmokeTestRunner.tscn` | Instantiates every scene |
| `tests/run_meta_tests.gd` | Achievements, stats, daily / practice rules |
| `tests/GuideTestRunner.tscn` | Live tutorial, ammo HUD, replay, save retry |
| `tests/ArcadeSessionTestRunner.tscn` | Full first-level wins through real projectiles at desktop and phone framing |
| `tests/bench_music.gd` | Music loudness, determinism, render timing |

Visual capture harness (needs the windowed Godot build, not `--headless`):

```powershell
& $godot --path . res://tests/VisualCapture.tscn -- --out=C:/tmp/caps --size=1920x1080 [--scenario=bosses]
```

---

## Export

The project uses **GL Compatibility**, which is required for WebGL 2.0. `export_presets.cfg` contains a single-threaded **Web (HTML5)** preset that outputs to `builds/web/index.html`. Serve it locally with `python -m http.server 8080` from that folder. See `docs/RELEASE.md` for the Cloudflare deploy. There is no desktop export preset yet.

---

## Architecture

```
LoadingScreen        custom boot screen, threaded load of Main.tscn
Main                 swaps Level instances into LevelHost, hosts the UI overlays
GameManager          game state machine, score, lives, objectives, progression
EventBus             cross-system signals (chain, reverse, boss, UI)
SaveService          versioned save, validation, debounced stat writes
AudioManager         SFX, per-stage music, background music composition
JuiceDirector        screen shake, hit-stop, floating text, particles
WormChain            segment-based chain: insert, match, reverse, cascade
BossController       boss modes (intro/idle/telegraph/attack/defeated), phases, attacks
ProgressionCatalog   3 stages × 5 LevelData, boss on level 5
StageBackdrop        procedural scenery per stage
MusicComposer        deterministic procedural music, incremental on web
```

## Project layout

```
autoload/    EventBus, GameManager, AudioManager, JuiceDirector, SaveService, Scoring, QualitySettings
scenes/      Main, Level, Chicken, Worm, Projectile, UI (incl. LoadingScreen, Stats)
scripts/     chain, boss, level, chicken, projectile, audio, UI
resources/   WormColor, LevelData, LevelObjective, BossDef, ProgressionCatalog, achievements
tests/       test runners, music bench, visual capture
tools/       run_tests.ps1
docs/        RELEASE.md, UPGRADE_REPORT.md
```

---

## License

Set your own license before shipping commercially.
