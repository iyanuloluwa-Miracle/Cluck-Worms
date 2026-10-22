# Cluck & Worms: arcade upgrade

Implemented in the existing Godot 4.7.2 project. The local web export is `builds/web/index.html`; the production domain has not been deployed.

## Audit and priorities

The original already had a substantial foundation: 15 levels across three stages, three bosses, several objectives, match/cascade scoring, abilities, Daily, Practice, Gauntlet, saves, and procedural audio. Adding more levels was less useful than making those systems dependable.

The audit found incorrect collision ordering and wildcard matching, stale aim on fast clicks, final-shot and retry edge cases, objective softlocks, mobile framing/input issues, intrusive first-run dialogs, and excessive procedural draw cost. The live browser build also logged missing imported-menu-audio errors.

Work followed four priorities: fix gameplay rules and input; establish the first level's garden art and feedback; integrate tutorial, HUD, retry and saving; then export, profile, and test complete sessions.

## What changed

- **Shooting and chains:** exact first-contact sweep tests, consistent insertion sides, shared aim-guide/projectile geometry, immediate click direction, gap shots, wildcard spans across adjacent rainbow worms, and cascade depth preserved when separated groups reconnect.
- **Fair outcomes:** the last allowed shot finishes before a shot-limit loss; retries restore the level's starting score; Daily/Practice/Gauntlet retries preserve their mode; Practice cannot overwrite the competitive high score; combo objectives use the current level's peak; score/combo/survival objectives refill an exhausted wave when needed.
- **Garden identity:** layered grass, flower beds, timber borders, stone-and-soil tracks, a readable nest danger zone, a cream hen with a green kerchief, and segmented worms. Artwork is original procedural drawing code. The existing three stage themes remain distinct.
- **Readable controls:** current and next ammunition show names and shared shape codes, with a visible swap button. Lives use text rather than unavailable emoji. The track fits above the lower controls, and wide phones retain the full arena.
- **Playable training:** first play reaches the menu directly. The first campaign level teaches a real shot, swap, and match without opening a blocking instructions dialog. Training can be skipped or replayed; completion persists independently of the older instructions flag. Touch uses tap-to-shoot. A menu tap cannot leak into a newly created launcher as a shot.
- **Feedback and accessibility:** danger audio escalates with urgency; cosmetic randomness is separate from Daily gameplay randomness; particles use stable damping; reduced effects suppress hit-stop and several idle/pulsing animations; reduced shake also disables camera pull. Distinct worm symbols supplement color. Existing separate music/SFX/master controls remain.
- **Browser and saves:** branded loading, fullscreen control, orientation guidance, safe framing, pause on focus/orientation changes, and explicit resume. Menu audio loads through Godot's imported resource system. Pending stats flush on focus loss; a failed save stays dirty and retries. No new save backend or atomic-backup scheme was added.
- **Rendering:** static scenery and track are cached once per configuration. Six worm bodies share one supersampled texture atlas; movement, collision, scale feedback and animated special badges remain live. Documentation, screenshots and test code are excluded from the game export.

## Verification

Run `tools/run_tests.ps1 -Godot <Godot-console-executable>`; on hosts restricting PowerShell scripts, invoke it with a process-only `-ExecutionPolicy Bypass`. Full logs are in [test-results](test-results/) and [test-summary.log](test-summary.log).

All eight suites passed on the final gameplay source. They cover core/save rules, chain behavior, game flow and bosses, every scene, field training, real-projectile sessions, meta progression, and audio composition. Regression coverage includes rapid shots, first-contact collisions, gaps, wildcard cascades, endpoint resolution, limited-shot wins/losses, retries, scaled touch coordinates, focus changes, and save retry.

The natural-play runner wins the first level at desktop and phone-landscape framing using actual aiming, swaps and projectiles. It does not force clear the chain or replace worm colors. Both sessions exhaust spawning, clear every worm, preserve three lives, unlock level two, and reload earned stars/scores. See [the session log](test-results/arcade-session.log). Other flow tests deliberately construct state to exercise failures, objectives, all three bosses and the campaign finale; they are not human balance playtests.

The exported game was exercised in Chromium with desktop mouse input and emulated phone touch input, including menu/level selection, shots, swap, slow, pause/resume, portrait rotation and restoration. The updated captures report no browser console errors; the original live audit records missing menu-audio errors. These are browser smoke tests plus inspected screenshots, not claims of physical-device certification.

## Performance and limits

On this laptop's Intel UHD Graphics 620, the initial upgraded art profile measured 46.43 ms median / 66.49 ms p95 and about 2,149 draw calls. After caching scenery, track and worm artwork, the native live-play sample measured **16.72 ms median / 21.50 ms p95**, with about **179 draw calls**. These are short samples of a growing first-level chain, not controlled device-wide benchmarks. The final profiler additionally freezes one identical scene for meaningful layer isolation; its full-scene sample was 16.66 ms median / 18.06 ms p95. See [native-performance.txt](native-performance.txt).

Browser performance on this host remains below the requested 60 FPS target. Profiling found that an Emscripten framebuffer blit queried WebGL scissor state every frame; on this Intel/ANGLE driver those synchronous queries consumed about 6.6 seconds of an 8.6-second sample. The web shell now mirrors that one boolean state on the game canvas, verifies it against the real driver, and retains `?native_gl_queries=1` for A/B diagnosis. This cut sampled main-thread task time from 10.5 to 3.15 seconds. The final headless desktop smoke sample still ran at a 66.7 ms median / 83.4 ms p95 cadence. Browser timings are requestAnimationFrame intervals from headless Chromium and are not interchangeable with the native measurements. No stable 60 FPS browser claim is made.

Further work before a broad release: profile browser performance in visible browsers on representative physical phones and desktops; test Safari/iOS and other browser engines; conduct human difficulty/readability/audio playtests across the later campaign. The existing 15-level campaign was retained and repaired, not fully rebalanced from long-form playtest data. Runtime stage music is still composed incrementally on single-threaded web builds. Save failures retry, but storage eviction/private-mode restrictions and atomic crash recovery remain outside this pass. The screenshot-only harness reports 28 retained Godot objects at process shutdown after producing all captures; the shipped browser session and eight automated suites do not report that warning. Production deployment remains outstanding.

## Visual evidence

Open [the before/after comparison](visual-review.html). It compares actual native captures of the original and upgraded playfield, menu, campaign selection, pause, victory, boss and coop screens. The scenarios deliberately drive screen states, including scripted victory/game-over; colors and scores can differ between runs. The capture harness ignores accidental window focus loss only during capture, while preserving its deliberate pause screenshot.

- [Original playfield](screenshots/before/04_gameplay.png)
- [Upgraded playfield](screenshots/after/04_gameplay.png)
- [Playable training](screenshots/after/12_tutorial.png)
- [Desktop browser](screenshots/browser/05-gameplay.png)
- [Phone touch layout](screenshots/mobile/05-gameplay.png)
- [Portrait/restored pause](screenshots/mobile/09-restored.png)

The architecture stays in Godot: GameManager/chain rules, Chicken input, rendering nodes, audio, save service, and LevelData remain separate. No external site platform, engine rewrite, copied Zuma assets, or production deployment was needed for these local changes.
