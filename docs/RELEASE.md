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

- [ ] All 12 levels clearable (finite `total_worms`)
- [ ] High score persists across refresh (`SaveService`)
- [ ] Icon / description / version set in Project Settings

## Optional art / audio swap

See README sections **How to replace art** and AudioManager `register_stream()`.
