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
## Points earned in the level just cleared, and that level's best before this clear.
var last_level_score: int = 0
var last_level_previous_best: int = 0
var level_start_score: int = 0
## True when the current run was started from the Gauntlet menu (arcade feel).
var is_gauntlet_run: bool = false
## practice | daily | "" for normal adventure / gauntlet.
var challenge_mode: StringName = &""
## Do not write unlocks / stars (practice sandbox).
var suppress_progress_save: bool = false

## Player abilities (real gameplay effects).
var slow_charges: int = 0
var bomb_charges: int = 0
const MAX_ABILITY_CHARGES: int = 3
const SLOW_ABILITY_DURATION: float = 3.2

## Objective runtime
var shots_fired: int = 0
var survive_time_left: float = 0.0
var level_elapsed: float = 0.0
var largest_match_this_level: int = 0
var objective_met: bool = false
var _accel_bonus: float = 0.0


func _ready() -> void:
	_rng.randomize()
	lives = starting_lives
	catalog = ProgressionCatalog.build_default()
	sanitize_save()
	EventBus.chain_cleared.connect(_on_chain_cleared)
	EventBus.chain_reached_end.connect(_on_chain_reached_end)
	EventBus.cascade_step.connect(_on_cascade_step)
	EventBus.chain_reversing.connect(_on_chain_reversing)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.chicken_shot.connect(_on_chicken_shot)


func _process(delta: float) -> void:
	if state != State.PLAYING or is_paused or current_level_def == null:
		return
	level_elapsed += delta
	SaveService.add_play_time(delta)
	_tick_accelerating_chain(delta)
	_tick_survive_objective(delta)
	_emit_objective_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if state == State.PLAYING:
			pause_game()
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED:
			resume_game()
			get_viewport().set_input_as_handled()
		return
	if not can_player_act():
		return
	if event.is_action_pressed("ability_slow"):
		try_use_slow_ability()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ability_bomb"):
		try_use_bomb_ability()
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
	if current_level_def != null and not current_level_def.no_specials:
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
	if score > 0 and state != State.MAIN_MENU and not suppress_progress_save:
		_submit_high_score()
	_set_tree_paused(false)
	is_paused = false
	is_gauntlet_run = false
	challenge_mode = &""
	suppress_progress_save = false
	_change_state(State.MAIN_MENU)
	EventBus.challenge_mode_changed.emit(&"")
	EventBus.unload_level_requested.emit()


## Clamp loaded progression to the campaign that actually ships.
func sanitize_save() -> void:
	if catalog == null:
		return
	var ids: Dictionary = {}
	for s: int in range(catalog.get_stage_count()):
		var stage: StageDef = catalog.get_stage(s)
		for l: int in range(stage.get_level_count()):
			var level: LevelData = stage.get_level(l)
			ids[level.level_number] = String(level.id)
	SaveService.sanitize_against_campaign(ids, catalog.get_stage_count())


## Campaign level number for a stage/level pair (1-based), or -1 if invalid.
func level_number_for(p_stage: int, p_level: int) -> int:
	if catalog == null:
		return -1
	var stage: StageDef = catalog.get_stage(p_stage)
	if stage == null or stage.get_level(p_level) == null:
		return -1
	return stage.get_level(p_level).level_number


## Progression gate — the authority behind every "Play" button.
func can_start_level(p_stage: int, p_level: int) -> bool:
	var number: int = level_number_for(p_stage, p_level)
	return number > 0 and SaveService.is_level_unlocked(number)


## Stage/level of the furthest unlocked campaign level.
func get_next_unlocked_level() -> Vector2i:
	var best := Vector2i.ZERO
	if catalog == null:
		return best
	for s: int in range(catalog.get_stage_count()):
		var stage: StageDef = catalog.get_stage(s)
		for l: int in range(stage.get_level_count()):
			if SaveService.is_level_unlocked(stage.get_level(l).level_number):
				best = Vector2i(s, l)
	return best


func start_run(from_stage: int = 0, from_level: int = 0, gauntlet: bool = false) -> bool:
	if catalog == null or catalog.get_stage_count() == 0:
		push_error("GameManager: no progression catalog.")
		return false
	var target_stage: int = clampi(from_stage, 0, catalog.get_stage_count() - 1)
	var target_level: int = clampi(from_level, 0, maxi(catalog.get_stage(target_stage).get_level_count() - 1, 0))
	if not can_start_level(target_stage, target_level):
		push_warning("GameManager: level %d is locked." % level_number_for(target_stage, target_level))
		return false
	is_gauntlet_run = gauntlet
	challenge_mode = &"gauntlet" if gauntlet else &""
	suppress_progress_save = false
	stage_index = target_stage
	level_index = target_level
	score = 0
	combo = 0
	peak_combo = 0
	lives = starting_lives
	EventBus.score_changed.emit(score, 0)
	EventBus.combo_changed.emit(combo)
	EventBus.lives_changed.emit(lives, starting_lives)
	EventBus.high_score_changed.emit(SaveService.high_score, false)
	EventBus.run_started.emit(stage_index, level_index)
	EventBus.challenge_mode_changed.emit(challenge_mode)
	if gauntlet:
		EventBus.gauntlet_run_started.emit()
	_load_current_level()
	return true


## Sandbox: infinite spawns, no unlock writes.
func start_practice(from_stage: int = 0, from_level: int = 0) -> void:
	if catalog == null or catalog.get_stage_count() == 0:
		return
	is_gauntlet_run = false
	challenge_mode = &"practice"
	suppress_progress_save = true
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
	EventBus.run_started.emit(stage_index, level_index)
	EventBus.challenge_mode_changed.emit(&"practice")
	_load_current_level()


## Deterministic daily level from local date seed.
func start_daily_challenge() -> void:
	if catalog == null:
		return
	var seed_key: int = _daily_seed()
	_rng.seed = seed_key
	# Daily rotates through levels the player has already unlocked.
	var total: int = mini(catalog.get_total_level_count(), SaveService.max_level_unlocked)
	var pick: int = seed_key % maxi(total, 1)
	var stage_i: int = 0
	var level_i: int = pick
	for s: int in range(catalog.get_stage_count()):
		var sc: int = catalog.get_stage(s).get_level_count()
		if level_i < sc:
			stage_i = s
			break
		level_i -= sc
	suppress_progress_save = false
	challenge_mode = &"daily"
	is_gauntlet_run = false
	stage_index = stage_i
	level_index = level_i
	score = 0
	combo = 0
	peak_combo = 0
	lives = starting_lives
	EventBus.score_changed.emit(score, 0)
	EventBus.combo_changed.emit(combo)
	EventBus.lives_changed.emit(lives, starting_lives)
	EventBus.run_started.emit(stage_index, level_index)
	EventBus.challenge_mode_changed.emit(&"daily")
	_load_current_level()


func _daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


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
	# Daily / practice are single-session challenges.
	if challenge_mode == &"daily" or challenge_mode == &"practice":
		_submit_high_score()
		go_to_main_menu()
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
	largest_match_this_level = maxi(largest_match_this_level, count)
	SaveService.record_match_stat(count, cascade_depth >= 1)
	# Combo is already incremented — Scoring uses current combo value.
	var points: int = Scoring.match_points(count, cascade_depth, combo, has_bonus_worm)
	# Large-group bonus for satisfying big pops.
	if count >= 6:
		points += (count - 5) * 40
		SaveService.unlock_achievement(&"precision_shooter")
	score += points
	EventBus.score_changed.emit(score, points)
	SaveService.unlock_achievement(&"first_match")
	_check_score_objective()
	_check_combo_objective()


func notify_shot_resolved(scored_match: bool) -> void:
	if not scored_match:
		reset_combo()


func try_use_slow_ability() -> bool:
	if not can_player_act() or slow_charges <= 0:
		return false
	var chain := _find_active_chain()
	if chain == null:
		return false
	slow_charges -= 1
	chain.apply_slow(SLOW_ABILITY_DURATION)
	EventBus.ability_used.emit(&"slow")
	EventBus.ability_charges_changed.emit(slow_charges, bomb_charges)
	JuiceDirector.add_trauma(0.1)
	return true


func try_use_bomb_ability() -> bool:
	if not can_player_act() or bomb_charges <= 0:
		return false
	var chain := _find_active_chain()
	if chain == null or chain.get_worm_count() == 0:
		return false
	var chicken := _find_active_chicken()
	var pos: Vector2 = chicken.global_position if chicken else Vector2(640, 360)
	bomb_charges -= 1
	var cleared: int = chain.detonate_at_nearest(pos)
	EventBus.ability_used.emit(&"bomb")
	EventBus.ability_charges_changed.emit(slow_charges, bomb_charges)
	if cleared > 0:
		JuiceDirector.add_trauma(0.22)
	return cleared > 0


func _find_active_chain() -> WormChain:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.find_child("WormChain", true, false) as WormChain


func _find_active_chicken() -> Chicken:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.find_child("Chicken", true, false) as Chicken


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
	if level_def.color_cap > 0:
		active_color_count = clampi(level_def.color_cap, 3, WormColor.KIND_COUNT)
	elif level_def.tight_palette:
		active_color_count = clampi(mini(active_color_count, 4), 3, WormColor.KIND_COUNT)
	cascades_this_level = 0
	last_level_stars = 0
	level_start_score = score
	shots_fired = 0
	level_elapsed = 0.0
	largest_match_this_level = 0
	objective_met = false
	_accel_bonus = 0.0
	survive_time_left = level_def.survive_seconds
	_reset_ability_charges(level_def)
	_set_tree_paused(false)
	is_paused = false
	_change_state(State.PLAYING)
	EventBus.load_level_requested.emit(level_def)
	EventBus.level_started.emit(level_def.id, level_def.display_name)
	EventBus.lives_changed.emit(lives, starting_lives)
	EventBus.score_changed.emit(score, 0)
	_emit_objective_progress()
	if not level_def.intro_tip.is_empty():
		EventBus.tutorial_step.emit(StringName(level_def.intro_tip))


func _reset_ability_charges(level_def: LevelData) -> void:
	slow_charges = 1 + level_def.bonus_ability_charges
	bomb_charges = 1
	if challenge_mode == &"practice":
		slow_charges = MAX_ABILITY_CHARGES
		bomb_charges = MAX_ABILITY_CHARGES
	slow_charges = mini(slow_charges, MAX_ABILITY_CHARGES)
	bomb_charges = mini(bomb_charges, MAX_ABILITY_CHARGES)
	EventBus.ability_charges_changed.emit(slow_charges, bomb_charges)


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
	last_level_score = level_score
	last_level_previous_best = SaveService.get_level_best_score(current_level_def.id)
	if suppress_progress_save:
		return
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
	SaveService.record_level_completed()


func _on_cascade_step(_c: WormChain, depth: int, count: int, _color: WormColor.Kind) -> void:
	if depth >= 1:
		cascades_this_level += 1
	largest_match_this_level = maxi(largest_match_this_level, count)


func _on_chain_reversing(_c: WormChain) -> void:
	SaveService.unlock_achievement(&"chain_breaker")


func _on_boss_defeated(_id: StringName) -> void:
	SaveService.unlock_achievement(&"boss_slayer")
	SaveService.record_boss_defeat()


func _on_chicken_shot(_color: WormColor.Kind, _o: Vector2, _d: Vector2) -> void:
	if state != State.PLAYING:
		return
	shots_fired += 1
	SaveService.record_shot()
	_check_shot_limit_fail()
	_emit_objective_progress()


func _check_achievements() -> void:
	if peak_combo >= 5:
		SaveService.unlock_achievement(&"combo_5")
	if peak_combo >= 10:
		SaveService.unlock_achievement(&"combo_10")
	if cascades_this_level >= 3:
		SaveService.unlock_achievement(&"cascade_master")
	if last_level_stars >= 3:
		SaveService.unlock_achievement(&"three_star")
	if SaveService.stages_cleared >= 3:
		SaveService.unlock_achievement(&"campaign_champion")
	if challenge_mode == &"daily":
		SaveService.unlock_achievement(&"daily_done")


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
	if state != State.PLAYING or objective_met:
		return
	if current_level_def == null:
		return
	var obj: LevelObjective.Kind = current_level_def.objective
	if current_level_def.is_boss_level or obj == LevelObjective.Kind.DEFEAT_BOSS:
		if not _is_active_boss_defeated():
			return
		_complete_objective()
		return
	match obj:
		LevelObjective.Kind.CLEAR_CHAIN, LevelObjective.Kind.LIMITED_SHOTS:
			_complete_objective()
		LevelObjective.Kind.SCORE_TARGET, LevelObjective.Kind.COMBO_TARGET, LevelObjective.Kind.SURVIVE_TIME:
			# Chain clear still counts as success if the alternate goal was already met,
			# otherwise refill is handled by Level for boss-like pressure modes.
			if objective_met:
				_complete_objective()
		_:
			_complete_objective()


func _complete_objective() -> void:
	if objective_met or state != State.PLAYING:
		return
	objective_met = true
	if current_level_def:
		EventBus.objective_completed.emit(int(current_level_def.objective))
	var stage: StageDef = get_current_stage()
	var is_stage_end: bool = (
		challenge_mode != &"daily"
		and challenge_mode != &"practice"
		and stage != null
		and level_index >= stage.get_level_count() - 1
	)
	if is_stage_end:
		_enter_stage_complete()
	else:
		_enter_level_complete()


func _check_score_objective() -> void:
	if current_level_def == null or objective_met:
		return
	if current_level_def.objective != LevelObjective.Kind.SCORE_TARGET:
		return
	var gained: int = score - level_start_score
	if gained >= current_level_def.target_score:
		_complete_objective()


func _check_combo_objective() -> void:
	if current_level_def == null or objective_met:
		return
	if current_level_def.objective != LevelObjective.Kind.COMBO_TARGET:
		return
	if peak_combo >= current_level_def.target_combo:
		_complete_objective()


func _check_shot_limit_fail() -> void:
	if current_level_def == null:
		return
	if current_level_def.objective != LevelObjective.Kind.LIMITED_SHOTS:
		return
	if current_level_def.shot_limit <= 0:
		return
	if shots_fired > current_level_def.shot_limit and not objective_met:
		_lose_life()


func _tick_survive_objective(delta: float) -> void:
	if current_level_def == null or objective_met:
		return
	if current_level_def.objective != LevelObjective.Kind.SURVIVE_TIME:
		return
	survive_time_left = maxf(survive_time_left - delta, 0.0)
	if survive_time_left <= 0.0:
		_complete_objective()


func _tick_accelerating_chain(delta: float) -> void:
	if current_level_def == null or not current_level_def.accelerating_chain:
		return
	_accel_bonus += delta * 1.8
	var chain := _find_active_chain()
	if chain == null:
		return
	var base: float = current_level_def.march_speed * current_level_def.speed_multiplier
	chain.march_speed = base + minf(_accel_bonus, base * 0.55)


func _emit_objective_progress() -> void:
	if current_level_def == null:
		return
	var label: String = LevelObjective.display_name(current_level_def.objective)
	var ratio: float = 0.0
	match current_level_def.objective:
		LevelObjective.Kind.SCORE_TARGET:
			var gained: int = score - level_start_score
			ratio = clampf(float(gained) / float(maxi(current_level_def.target_score, 1)), 0.0, 1.0)
			label = "Score %d / %d" % [gained, current_level_def.target_score]
		LevelObjective.Kind.SURVIVE_TIME:
			ratio = 1.0 - clampf(
				survive_time_left / maxf(current_level_def.survive_seconds, 0.01), 0.0, 1.0
			)
			label = "Survive %.0fs" % ceilf(survive_time_left)
		LevelObjective.Kind.LIMITED_SHOTS:
			var left: int = maxi(current_level_def.shot_limit - shots_fired, 0)
			ratio = 1.0 - clampf(float(shots_fired) / float(maxi(current_level_def.shot_limit, 1)), 0.0, 1.0)
			label = "Shots left: %d" % left
		LevelObjective.Kind.COMBO_TARGET:
			ratio = clampf(float(peak_combo) / float(maxi(current_level_def.target_combo, 1)), 0.0, 1.0)
			label = "Combo %d / %d" % [peak_combo, current_level_def.target_combo]
		LevelObjective.Kind.DEFEAT_BOSS:
			label = "Defeat %s" % (
				current_level_def.boss.display_name if current_level_def.boss else "the boss"
			)
			ratio = 0.0
		_:
			label = "Clear the chain"
			ratio = 0.0
	EventBus.objective_progress_changed.emit(label, ratio)


func _is_active_boss_defeated() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var boss: BossController = tree.root.find_child("BossController", true, false) as BossController
	return boss != null and boss.is_defeated


func _on_chain_reached_end(_chain: WormChain) -> void:
	if state != State.PLAYING:
		return
	# Surviving until the timer ends is the goal — pit contact still costs a life.
	_lose_life()
