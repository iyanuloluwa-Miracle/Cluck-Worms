extends Node
## Global signal hub. Systems talk here — no spaghetti cross-references.

# ---------------------------------------------------------------------------
# Worm lifecycle
# ---------------------------------------------------------------------------

signal worm_spawned(worm: Worm)
signal worm_removed(worm: Worm, reason: StringName)
signal worm_state_changed(worm: Worm, old_state: Worm.State, new_state: Worm.State)

# ---------------------------------------------------------------------------
# Chain events
# ---------------------------------------------------------------------------

signal chain_worms_inserted(chain: WormChain, index: int, count: int)
signal chain_worms_removed(chain: WormChain, index: int, count: int)
signal chain_match_found(chain: WormChain, start_index: int, count: int, color: WormColor.Kind)
signal chain_reached_end(chain: WormChain)
signal chain_cleared(chain: WormChain)
signal cascade_step(chain: WormChain, depth: int, count: int, color: WormColor.Kind)
signal chain_collapse_started(chain: WormChain, removed_count: int)
signal chain_collapse_finished(chain: WormChain)
signal shot_resolve_finished(chain: WormChain, scored_match: bool)

# ---------------------------------------------------------------------------
# Scoring / HUD
# ---------------------------------------------------------------------------

signal score_changed(new_score: int, delta: int)
signal combo_changed(combo: int)
signal lives_changed(lives: int, max_lives: int)
signal high_score_changed(high_score: int, is_new: bool)

# ---------------------------------------------------------------------------
# Game state machine
# ---------------------------------------------------------------------------

## Emitted on every valid state transition.
signal game_state_changed(previous: int, next: int)

signal run_started(stage_index: int, level_index: int)
signal level_started(level_id: StringName, display_name: String)
signal level_completed(level_id: StringName, score: int, lives: int)
signal stage_completed(stage_id: StringName, stage_index: int, score: int)
signal game_over(final_score: int, high_score: int, is_new_high: bool)
signal life_lost(lives_remaining: int)

## Main / flow controller should load this scene path and apply LevelDef.
signal load_level_requested(level_def: LevelDef)
signal unload_level_requested()

# ---------------------------------------------------------------------------
# Chicken / shooter
# ---------------------------------------------------------------------------

signal chicken_shot(color: WormColor.Kind, origin: Vector2, direction: Vector2)
signal chicken_swapped(current_color: WormColor.Kind, next_color: WormColor.Kind)
signal chicken_loadout_changed(current_color: WormColor.Kind, next_color: WormColor.Kind)
signal projectile_hit_chain(projectile: ShootingWorm, hit_worm: Worm, chain: WormChain)
