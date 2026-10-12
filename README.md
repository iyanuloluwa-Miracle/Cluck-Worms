# Cluck & Worms

A premium Zuma-style 2D puzzle game — cartoon chicken, colorful worms, cascades, and juice.

Built with **Godot 4.3+** (GDScript only), **GL Compatibility** renderer, and a **single-threaded HTML5** export path suitable for itch.io, Poki, CrazyGames, and mobile browsers.

---

## Requirements

- [Godot 4.3+](https://godotengine.org/download) (4.3 or 4.4 recommended)
- Web export templates installed (`Editor → Manage Export Templates`)

---

## How to run

1. Open the project folder in Godot (`Project → Import` or drag the folder onto the editor).
2. Press **F5** (or **Play**).
3. From the main menu, choose **Play**.

| Input | Action |
| --- | --- |
| Left click / tap | Aim & shoot |
| Right click / Space / two-finger tap | Swap current ↔ next worm |
| Esc / P / HUD pause | Pause |

Touch: tap the playfield to aim and shoot; tap the chicken or next-preview to swap.

---

## Campaign

**3 stages × 4 levels = 12 levels.** Each level has a finite worm budget — clear the chain after spawns run out to win.

| Stage | Levels | Focus |
| --- | --- | --- |
| Farmyard Beginner | 1–4 | 3→4 colors, open paths |
| Backyard Mayhem | 5–8 | 4→5 colors, tighter routes |
| Chicken Apocalypse | 9–12 | 6 colors, dense finale spiral |

Progress and high score are saved locally via `SaveService`.

---

## How to add new levels

All levels reuse `scenes/level/Level.tscn`. Authoring is data-only.

1. **Path** — add a helper in `scripts/level/PathFactory.gd`, or build a `PackedVector2Array` of waypoints (1280×720 playfield).
2. **Level data** — in `resources/progression/ProgressionCatalog.gd` → `build_campaign()`, call `_level(...)` with:
   - display name / id  
   - path points  
   - color count (3–6)  
   - march speed, spawn interval  
   - initial worm count + total worms (budget)  
   - spacing, path smoothness, background color  
3. **Stage** — append the `LevelData` to the right `StageDef.levels` array.

Example:

```gdscript
_level(13, &"s4_l13", "New Pasture", PathFactory.path_s4_l13(),
	4, 58.0, 0.75, 12, 40, 40.0, 0.40, Color(0.14, 0.30, 0.18))
```

Key fields live on `LevelData` (`resources/progression/LevelData.gd`): path, difficulty, chicken position, danger zone length.

No new scene file is required unless you want a custom layout.

---

## How to replace art

The shipping build is **procedural** (drawn worms, chicken, UI). To swap in real art:

| What | Where | How |
| --- | --- | --- |
| Worm body | `scripts/worm/Worm.gd` `_draw_worm_body()` | Draw `Sprite2D` / atlas frames instead of circles; keep `HEAD_RADIUS` for hit tests |
| Colors | `resources/worm/WormColor.gd` | Edit fill / outline / highlight per `Kind` |
| Chicken | `scripts/chicken/ChickenBody.gd` | Replace `_draw()` with sprites under `scenes/chicken/Chicken.tscn` |
| Loadout previews | `scripts/chicken/WormPreview.gd` | Use the same worm art at smaller scale |
| Projectiles | `scripts/projectile/ShootingWorm.gd` | Sprite + keep `Trail` (`Line2D`) for motion readability |
| Background | Level `Background/ColorRect` or `LevelData.background_color` | TextureRect / parallax under `scenes/level/Level.tscn` |
| UI chrome | `scripts/ui/UITheme.gd`, `FancyButton.gd` | Theme / NinePatch / fonts |
| SFX | `autoload/AudioManager.gd` | `register_stream(&"peck", preload("res://audio/peck.wav"))` — same logical names (`peck`, `pop`, `cascade`, `cluck`, …) |
| Icon / splash | `icon.svg`, Project Settings → Application | Replace for store pages |

Keep collision radii (`Worm.HEAD_RADIUS`, `ShootingWorm.hit_radius`) aligned with new sprite sizes.

---

## Export instructions

### Renderer

The project uses **GL Compatibility** (`project.godot`). Required for WebGL 2.0 / HTML5. Do not switch back to Forward+ if you need a browser build.

### Web (HTML5) — recommended

A ready-made preset is in `export_presets.cfg`:

- **Name:** `Web (HTML5)`
- **Thread support:** off (single-threaded — works on itch.io / mobile Safari without COOP/COEP headers)
- **Extensions support:** off
- **Output:** `builds/web/index.html`

Steps:

1. Install Web export templates.
2. `Project → Export…` → select **Web (HTML5)**.
3. Click **Export Project** (release).
4. Serve the `builds/web/` folder over **HTTP(S)** (browsers block `file://` WASM).

Local preview:

```bash
# from builds/web
python -m http.server 8080
# open http://localhost:8080
```

itch.io: upload the folder as an HTML5 game (“This file will be played in the browser”). Single-threaded builds do **not** need SharedArrayBuffer / cross-origin isolation.

### Desktop (optional)

Add a Windows / macOS / Linux preset in the Export dialog if you want native builds. Compatibility renderer works on desktop too.

### Performance notes (mobile browsers)

`QualitySettings` autoload picks a tier at boot:

| Tier | When | Behavior |
| --- | --- | --- |
| HIGH | Desktop / editor | Full particles, hit-stop, trails |
| MEDIUM | Desktop browser | Fewer particles, no per-worm pops, 60 FPS cap |
| LOW | Phone / touch web | Lean FX, no hit-stop, throttled chicken redraw |

Juice still reads as premium — just cheaper on constrained GPUs.

---

## Architecture

```
Main                    loads/unloads Level into LevelHost; hosts UI
GameManager             state machine, score, lives, progression
EventBus                all cross-system signals
QualitySettings         web/mobile quality tier
JuiceDirector           shake, hit-stop, camera, PopBurst / float text
AudioManager            procedural SFX bank (replaceable streams)
Level + LevelData       path, tuning, finite spawn budget
WormChain + WormPool    Zuma insert / match / cascade / pooling
Chicken + ShootingWorm  aim, shoot, trail, near-miss
ProgressionCatalog      3 stages × 4 LevelData entries
SaveService             high score / progress
```

---

## Project layout

```
autoload/          EventBus, GameManager, Audio, Juice, Quality, Save
scenes/            Main, Level, Chicken, Worm, Projectile, UI
scripts/           gameplay, UI, juice, level helpers
resources/         WormColor, LevelData, ProgressionCatalog, PathFactory
builds/            export output (gitignored)
export_presets.cfg Web HTML5 single-threaded preset
```

---

## License

Project code and assets in this repository — set your own license before shipping commercially.
