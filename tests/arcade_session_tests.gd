extends Node
## A complete arcade session through the real launcher/projectile/chain flow.
## The player may inspect visible colors and motion, but never changes worms,
## ammo, spawn budgets, movement, scoring, lives, or match events.
## Run: godot --headless --path . res://tests/ArcadeSessionTestRunner.tscn

const SAVE_PATH := "user://test_arcade_session_save.cfg"
const SESSION_SEED: int = 20261018
const SESSION_LIMIT: float = 120.0
const SHOT_SPEED: float = 980.0
var _failed: int = 0
var _main: Node
var _hits: int = 0
var _matches: int = 0
var _swaps: int = 0
var _removed: int = 0
var _previous_distances: Dictionary = {}
var _velocities: Dictionary = {}


func _ready() -> void:
	print("--- Running Real-Projectile Arcade Session Tests ---")
	SaveService.save_path = SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	SaveService.load_save()
	SaveService.profile_setup_done = true
	SaveService.tutorial_done = true
	# Run the real game at normal time and default physics cadence.
	var old_ticks: int = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	EventBus.projectile_hit_chain.connect(_on_hit)
	EventBus.cascade_step.connect(_on_match)
	EventBus.chain_worms_removed.connect(_on_remove)
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _wait(0.2)
	await _run_session("desktop", Vector2i(1280, 720))
	await _run_session("phone_landscape", Vector2i(844, 390))
	GameManager.go_to_main_menu()
	await _wait(0.3)
	_main.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = old_ticks
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _failed == 0:
		print("Cluck & Worms arcade session tests: ALL PASSED")
	else:
		printerr("Cluck & Worms arcade session tests: %d FAILED" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _run_session(label: String, window_size: Vector2i) -> void:
	GameManager.go_to_main_menu()
	get_window().size = window_size
	await _wait(0.2)
	GameManager.get_rng().seed = SESSION_SEED
	_hits = 0
	_matches = 0
	_swaps = 0
	_removed = 0
	_previous_distances.clear()
	_velocities.clear()
	_expect(GameManager.start_run(0, 0), label + ": first campaign level starts")
	await _wait(0.1)
	var chain: WormChain = _chain()
	var chicken: Chicken = _chicken()
	if chain == null or chicken == null:
		_expect(false, label + ": playable chain and launcher exist")
		return
	_expect(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(1280, 720)), label + ": complete 1280x720 logical arena is retained")
	_expect(get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, label + ": framing preserves the arena aspect ratio")
	var bounds := Rect2(Vector2(24, 24), Vector2(1232, 672))
	var all_inside: bool = true
	for i: int in range(101):
		var p: Vector2 = chain.path.curve.sample_baked(chain.get_path_length() * float(i) / 100.0)
		if not bounds.has_point(p):
			all_inside = false
	_expect(all_inside, label + ": full track fits inside logical viewport including worm radius")
	var screen_point: Vector2 = chicken.get_canvas_transform() * Vector2(1100, 530)
	_expect(chicken._screen_to_world(screen_point).distance_to(Vector2(1100, 530)) < 0.1, label + ": screen aiming round-trips through the active camera transform")

	var elapsed: float = 0.0
	var decision_left: float = 0.0
	var wall_start: int = Time.get_ticks_msec()
	while GameManager.state == GameManager.State.PLAYING and elapsed < SESSION_LIMIT:
		await get_tree().physics_frame
		var dt: float = 1.0 / 60.0
		elapsed += dt
		decision_left -= dt
		# A lost life reloads the board: never count that as uninterrupted play.
		if GameManager.lives != GameManager.starting_lives or not is_instance_valid(chain):
			break
		_sample_motion(chain, dt)
		if elapsed < 2.0 or decision_left > 0.0 or chain.is_busy():
			continue
		var projectiles: Node = chicken.get_parent().get_node("Projectiles")
		if projectiles.get_child_count() > 0:
			continue
		var choice: Dictionary = _best_target(chain, chicken, chicken.current_color)
		var reserve: Dictionary = _best_target(chain, chicken, chicken.next_color)
		if not reserve.is_empty() and (choice.is_empty() or float(reserve["score"]) > float(choice["score"]) + 90.0):
			chicken.swap_worms()
			_swaps += 1
			choice = reserve
		if choice.is_empty():
			decision_left = 0.10
			continue
		chicken.aim_at(choice["position"] as Vector2)
		if chicken.shoot_now():
			decision_left = 0.28

	var shots: int = GameManager.shots_fired
	var won: bool = GameManager.state == GameManager.State.LEVEL_COMPLETE
	print("  SESSION %s simulated=%.2fs wall=%.2fs shots=%d hits=%d matches=%d swaps=%d removed=%d score=%d lives=%d state=%d" % [label, elapsed, float(Time.get_ticks_msec() - wall_start) / 1000.0, shots, _hits, _matches, _swaps, _removed, GameManager.score, GameManager.lives, GameManager.state])
	_expect(won, label + ": completes the first level using actual aimed projectiles")
	_expect(GameManager.lives == GameManager.starting_lives, label + ": completes without losing a life")
	_expect(shots > 0 and _hits > 0 and _matches > 0, label + ": shots produce real collisions and matches")
	if is_instance_valid(chain):
		_expect(chain.spawns_remaining == 0 and chain.get_worm_count() == 0, label + ": natural spawn budget exhausted and every worm cleared")
	if won:
		_expect(_removed == GameManager.current_level_def.total_worms + _hits, label + ": removed worms equal the original wave plus actual projectile insertions")
		_expect(SaveService.max_level_unlocked >= 2, label + ": natural win unlocks level two")
		SaveService.load_save()
		_expect(SaveService.get_level_stars(&"s1_l1") >= 1 and SaveService.get_level_best_score(&"s1_l1") > 0, label + ": earned stars and score survive save reload")


func _sample_motion(chain: WormChain, dt: float) -> void:
	for worm: Worm in chain.get_worms():
		var id: int = worm.get_instance_id()
		if _previous_distances.has(id):
			_velocities[id] = (worm.path_distance - float(_previous_distances[id])) / dt
		_previous_distances[id] = worm.path_distance


func _best_target(chain: WormChain, chicken: Chicken, color: WormColor.Kind) -> Dictionary:
	var result: Dictionary = {}
	var best: float = -INF
	var worms: Array[Worm] = chain.get_worms()
	for i: int in range(worms.size()):
		var worm: Worm = worms[i]
		if not chain.is_worm_targetable(worm) or worm.worm_color != color:
			continue
		var group: int = 1
		for step: int in [-1, 1]:
			var j: int = i + step
			var previous: int = i
			while j >= 0 and j < worms.size():
				if worms[j].worm_color != color or absf(worms[j].path_distance - worms[previous].path_distance) > chain.worm_spacing * 1.15:
					break
				group += 1
				previous = j
				j += step
		var flight: float = maxf(chicken.global_position.distance_to(worm.global_position) - chicken.muzzle_distance, 0.0) / SHOT_SPEED
		var velocity: float = float(_velocities.get(worm.get_instance_id(), 0.0))
		var distance: float = clampf(worm.path_distance + velocity * flight, 0.0, chain.get_path_length())
		var aim: Vector2 = chain.path.to_global(chain.path.curve.sample_baked(distance))
		var score: float = float(group) * 100.0 + worm.path_distance / chain.get_path_length() * 20.0 - flight
		if score > best:
			best = score
			result = {"position": aim, "score": score}
	return result


func _chain() -> WormChain:
	return _main.get_node("LevelHost").find_child("WormChain", true, false) as WormChain


func _chicken() -> Chicken:
	return _main.get_node("LevelHost").find_child("Chicken", true, false) as Chicken


func _on_hit(_projectile: ShootingWorm, _worm: Worm, _chain_node: WormChain) -> void:
	_hits += 1


func _on_match(_chain_node: WormChain, _depth: int, _count: int, _color: WormColor.Kind) -> void:
	_matches += 1


func _on_remove(_chain_node: WormChain, _index: int, count: int) -> void:
	_removed += count


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("  OK  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
