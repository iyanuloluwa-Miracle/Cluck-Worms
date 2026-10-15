extends Node
## Authoritative game flow: state machine, scoring, lives, progression.
## UI and levels react via EventBus — they never drive each other directly.

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

enum State {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	LEVEL_COMPLETE,
	GAME_OVER,
	STAGE_COMPLETE,
}

# ---------------------------------------------------------------------------
# Scoring tunables
# ---------------------------------------------------------------------------

@export var points_per_worm: int = 100
@export var points_per_extra_worm: int = 50
@export var large_group_bonus_threshold: int = 5
@export var large_group_bonus_per_worm: int = 40
@export var cascade_bonus_per_depth: int = 75
@export var level_clear_bonus: int = 500
@export var stage_clear_bonus: int = 1500
@export var life_remaining_bonus: int = 250
@export var combo_multiplier_step: float = 0.25
@export var max_combo_multiplier: float = 5.0

# ---------------------------------------------------------------------------
# Lives / run
# ---------------------------------------------------------------------------

@export var starting_lives: int = 3

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var state: State = State.MAIN_MENU
var score: int = 0
var combo: int = 0
var peak_combo: int = 0
var lives: int = 3
var is_paused: bool = false

var catalog: ProgressionCatalog
var stage_index: int = 0
var level_index: int = 0
var current_level_def: LevelData = null
## Active color pool size for the loaded level (3–6).
var active_color_count: int = WormColor.KIND_COUNT

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state_before_pause: State = State.PLAYING
## Cascades triggered during the current level (for stars / achievements).
var cascades_this_level: int = 0
var last_level_stars: int = 0
var level_start_score: int = 0
## True when the current run was started from the Gauntlet menu (arcade feel).
var is_gauntlet_run: bool = false


func _ready() -> void:
	_rng.randomize()
	lives = starting_lives
	catalog = ProgressionCatalog.build_default()
	EventBus.chain_cleared.connect(_on_chain_cleared)
	EventBus.chain_reached_end.connect(_on_chain_reached_end)
	EventBus.cascade_step.connect(_on_cascade_step)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if state == State.PLAYING:
			pause_game()
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED:
			resume_game()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# State queries
# ---------------------------------------------------------------------------

func get_state() -> State:
	return state


func is_playing() -> bool:
	return state == State.PLAYING


func can_player_act() -> bool:
	return state == State.PLAYING and not is_paused


func get_current_stage() -> StageDef:
	return catalog.get_stage(stage_index) if catalog else null


func get_combo_multiplier() -> float:
	return _combo_multiplier()


func get_rng() -> RandomNumberGenerator:
	return _rng


func roll_worm_color() -> WormColor.Kind:
	return WormColor.random_kind(_rng, active_color_count)


## Chain spawn roll — mostly normal, occasional specials from level 5+.
func roll_worm() -> Dictionary:
	var color: WormColor.Kind = roll_worm_color()
	var type: WormType.Kind = WormType.Kind.NORMAL
	var chance: float = 0.0
	if current_level_def != null:
		chance = current_level_def.special_spawn_chance
	if chance > 0.0 and _rng.randf() < chance:
		var roll: float = _rng.randf()
		if roll < 0.35:
			type = WormType.Kind.RAINBOW
		elif roll < 0.60:
			type = WormType.Kind.BOMB
		elif roll < 0.80:
			type = WormType.Kind.SLOW
		else:
			type = WormType.Kind.BONUS
	return {"color": color, "type": type}


func get_active_color_count() -> int:
	return active_color_count


func get_campaign_level_number() -> int:
	if current_level_def:
		return current_level_def.level_number
	return 1


func state_name(s: State = state) -> String:
	match s:
		State.MAIN_MENU:
			return "MainMenu"
		State.PLAYING:
			return "Playing"
		State.PAUSED:
			return "Paused"
		State.LEVEL_COMPLETE:
			return "LevelComplete"
		State.GAME_OVER:
			return "GameOver"
		State.STAGE_COMPLETE:
			return "StageComplete"
		_:
			return "Unknown"


# ---------------------------------------------------------------------------
# Run / menu flow (called by UI via clear intent — not by Level)
# ---------------------------------------------------------------------------

func go_to_main_menu() -> void:
	if score > 0 and state != State.MAIN_MENU:
		_submit_high_score()
	_set_tree_paused(false)
	is_paused = false
	is_gauntlet_run = false
	_change_state(State.MAIN_MENU)
	EventBus.unload_level_requested.emit()


func start_run(from_stage: int = 0, from_level: int = 0, gauntlet: bool = false) -> void:
	if catalog == null or catalog.get_stage_count() == 0:
		push_error("GameManager: no progression catalog.")
		return
	is_gauntlet_run = gauntlet
	stage_index = clampi(from_stage, 0, catalog.get_stage_count() - 1)
	var stage: StageDef = catalog.get_stage(stage_index)
	level_index = clampi(from_level, 0, maxi(stage.get_level_count() - 1, 0))
	score = 0
	combo = 0
	peak_combo = 0
	lives = starting_lives
	EventBus.score_changed.emit(score, 0)
	EventBus.combo_changed.emit(combo)
	EventBus.lives_changed.emit(lives, starting_lives)
	EventBus.high_score_changed.emit(SaveService.high_score, false)
	EventBus.run_started.emit(stage_index, level_index)
	if gauntlet:
		EventBus.gauntlet_run_started.emit()
	_load_current_level()


func pause_game() -> void:
	if state != State.PLAYING:
		return
	_state_before_pause = state
	is_paused = true
	_set_tree_paused(true)
	_change_state(State.PAUSED)


func resume_game() -> void:
	if state != State.PAUSED:
		return
	is_paused = false
	_set_tree_paused(false)
	_change_state(State.PLAYING)


func grant_extra_life(amount: int = 1) -> void:
	## Lagos Life IAP / continue pack — restore lives without resetting the run.
	lives = mini(lives + maxi(amount, 0), starting_lives + 2)
	EventBus.lives_changed.emit(lives, starting_lives)
	if state == State.GAME_OVER and lives > 0:
		is_paused = false
		_set_tree_paused(false)
		retry_level()


func retry_level() -> void:
	## Retry current level after LevelComplete overlay is not used —
	## used from pause/game-over "retry" and life-loss reload.
	if current_level_def == null:
		go_to_main_menu()
		return
	combo = 0
	EventBus.combo_changed.emit(combo)
	_set_tree_paused(false)
	is_paused = false
	_load_current_level()


func restart_run() -> void:
	start_run(stage_index, 0)


func advance_after_level_complete() -> void:
	if state != State.LEVEL_COMPLETE:
		return
	var stage: StageDef = get_current_stage()
	if stage == null:
		go_to_main_menu()
		return
	if level_index + 1 < stage.get_level_count():
		level_index += 1
		combo = 0
		EventBus.combo_changed.emit(combo)
		_load_current_level()
	else:
		_enter_stage_complete()


func advance_after_stage_complete() -> void:
	if state != State.STAGE_COMPLETE:
		return
	if stage_index + 1 < catalog.get_stage_count():
		stage_index += 1
		level_index = 0
		combo = 0
		EventBus.combo_changed.emit(combo)
		_load_current_level()
	else:
		# All stages cleared — treat as glorious game over / victory lap to menu.
		_submit_high_score()
		go_to_main_menu()


# ---------------------------------------------------------------------------
# Scoring API (WormChain)
# ---------------------------------------------------------------------------

func register_match(
	count: int,
	_color: WormColor.Kind,
	cascade_depth: int,
	has_bonus_worm: bool = false
) -> void:
	increment_combo()
	# Combo is already incremented — Scoring uses current combo value.
	var points: int = Scoring.match_points(count, cascade_depth, combo, has_bonus_worm)
	score += points
	EventBus.score_changed.emit(score, points)


func notify_shot_resolved(scored_match: bool) -> void:
	if not scored_match:
		reset_combo()


func add_score(base_points: int) -> void:
	var multiplier: float = _combo_multiplier()
	var delta: int = int(round(float(base_points) * multiplier))
	score += delta
	EventBus.score_changed.emit(score, delta)


func increment_combo() -> void:
	combo += 1
	peak_combo = maxi(peak_combo, combo)
	EventBus.combo_changed.emit(combo)


func reset_combo() -> void:
	if combo == 0:
		return
	combo = 0
	EventBus.combo_changed.emit(combo)


# ---------------------------------------------------------------------------
# Internals — state & level load
# ---------------------------------------------------------------------------

func _change_state(next: State) -> void:
	if state == next:
		return
	var previous: State = state
	state = next
	EventBus.game_state_changed.emit(int(previous), int(next))


func _load_current_level() -> void:
	var stage: StageDef = get_current_stage()
	if stage == null:
		push_error("GameManager: invalid stage_index %d" % stage_index)
		go_to_main_menu()
		return
	var level_def: LevelData = stage.get_level(level_index)
	if level_def == null:
		push_error("GameManager: invalid level_index %d" % level_index)
		go_to_main_menu()
		return
	current_level_def = level_def
	active_color_count = clampi(level_def.color_count, 3, WormColor.KIND_COUNT)
	cascades_this_level = 0
	last_level_stars = 0
	level_start_score = score
	_set_tree_paused(false)
	is_paused = false
	_change_state(State.PLAYING)
	EventBus.load_level_requested.emit(level_def)
	EventBus.level_started.emit(level_def.id, level_def.display_name)
	EventBus.lives_changed.emit(lives, starting_lives)
	EventBus.score_changed.emit(score, 0)


func _enter_level_complete() -> void:
	add_score(level_clear_bonus)
	_record_level_stars()
	_set_tree_paused(true)
	is_paused = true
	_change_state(State.LEVEL_COMPLETE)
	var id: StringName = current_level_def.id if current_level_def else &""
	EventBus.level_completed.emit(id, score, lives)
	_check_achievements()


func _enter_stage_complete() -> void:
	add_score(level_clear_bonus)
	add_score(stage_clear_bonus + lives * life_remaining_bonus)
	_record_level_stars()
	SaveService.record_stage_cleared(stage_index)
	_submit_high_score()
	_set_tree_paused(true)
	is_paused = true
	_change_state(State.STAGE_COMPLETE)
	var stage: StageDef = get_current_stage()
	var sid: StringName = stage.id if stage else &""
	EventBus.stage_completed.emit(sid, stage_index, score)
	SaveService.unlock_achievement(&"stage_clear_%d" % (stage_index + 1))
	_check_achievements()


func _enter_game_over() -> void:
	var is_new: bool = _submit_high_score()
	_set_tree_paused(true)
	is_paused = true
	_change_state(State.GAME_OVER)
	EventBus.game_over.emit(score, SaveService.high_score, is_new)


func _record_level_stars() -> void:
	if current_level_def == null:
		return
	var level_score: int = maxi(score - level_start_score, 0)
	last_level_stars = Scoring.stars_for_level(
		level_score,
		current_level_def.total_worms,
		lives,
		cascades_this_level
	)
	SaveService.record_level_result(
		current_level_def.id,
		current_level_def.level_number,
		last_level_stars,
		level_score
	)


func _on_cascade_step(_c: WormChain, depth: int, _n: int, _color: WormColor.Kind) -> void:
	if depth >= 1:
		cascades_this_level += 1


func _check_achievements() -> void:
	if peak_combo >= 5:
		SaveService.unlock_achievement(&"combo_5")
	if peak_combo >= 10:
		SaveService.unlock_achievement(&"combo_10")
	if cascades_this_level >= 3:
		SaveService.unlock_achievement(&"cascade_master")
	if last_level_stars >= 3:
		SaveService.unlock_achievement(&"three_star")


func _lose_life() -> void:
	lives = maxi(lives - 1, 0)
	EventBus.lives_changed.emit(lives, starting_lives)
	EventBus.life_lost.emit(lives)
	reset_combo()
	if lives <= 0:
		_enter_game_over()
	else:
		# Remain in PLAYING after reload.
		retry_level()


func _submit_high_score() -> bool:
	var is_new: bool = SaveService.try_submit_score(score, peak_combo)
	EventBus.high_score_changed.emit(SaveService.high_score, is_new)
	return is_new


func _set_tree_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree:
		tree.paused = paused


func _combo_multiplier() -> float:
	var multiplier: float = 1.0 + float(maxi(combo - 1, 0)) * combo_multiplier_step
	return minf(multiplier, max_combo_multiplier)


# ---------------------------------------------------------------------------
# Chain → flow
# ---------------------------------------------------------------------------

func _on_chain_cleared(_chain: WormChain) -> void:
	if state != State.PLAYING:
		return
	var stage: StageDef = get_current_stage()
	if stage != null and level_index >= stage.get_level_count() - 1:
		_enter_stage_complete()
	else:
		_enter_level_complete()


func _on_chain_reached_end(_chain: WormChain) -> void:
	if state != State.PLAYING:
		return
	_lose_life()
