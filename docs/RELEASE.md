# Release checklist

Use this before shipping a build.

## Editor

- [ ] Open in Godot 4.3+ — project loads with **GL Compatibility**
- [ ] F5 → main menu → play a full stage clear and a life-loss / game over
- [ ] Touch or mouse: shoot, swap, pause all work
- [ ] No console `print` spam (project ships without debug prints)

## Web export

- [ ] Export templates installed
- [ ] Preset **Web (HTML5)** — `variant/thread_support=false`
- [ ] Export to `builds/web/index.html`
- [ ] Serve over HTTP and play on desktop Chrome + a phone browser
- [ ] Audio (procedural SFX) audible after first gesture if the browser requires it

## Content

- [ ] All 18 campaign levels clearable across 4 stages (Farmyard, Backyard, Apocalypse, Moonlit)
- [ ] Stars (1-3) and personal best scores persist across sessions (`SaveService`)
- [ ] Top 8 leaderboard tracks best runs
- [ ] Icon / description / version set in Project Settings

## Automated Tests

- [ ] Core tests: `godot --headless --path . "res://tests/TestRunner.tscn"`
- [ ] Scene smoke tests: `godot --headless --path . "res://tests/SmokeTestRunner.tscn"`

## Optional art / audio swap

See README sections **How to replace art** and AudioManager `register_stream()`.
