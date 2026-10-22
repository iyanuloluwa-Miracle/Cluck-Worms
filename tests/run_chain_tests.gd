extends Node
## Behavioral tests for the real WormChain: insert, match, gap, reverse, cascade,
## endpoint and fuzzed invariants. Runs inside the project tree (autoloads live).
## Run: godot --headless --path . res://tests/ChainTestRunner.tscn

const WORM_SCENE: PackedScene = preload("res://scenes/worm/Worm.tscn")
const SPACING: float = 40.0
const DT: float = 1.0 / 60.0
const R := WormColor.Kind.RED
const B := WormColor.Kind.BLUE
const G := WormColor.Kind.GREEN
const Y := WormColor.Kind.YELLOW
const P := WormColor.Kind.PURPLE

var _failed: int = 0
var _cascades: Array[int] = []
var _reversals: int = 0
var _reached_end: int = 0
var _resolved: Array[bool] = []
var _cleared: int = 0


func _ready() -> void:
	print("--- Running Cluck & Worms Chain Behavior Tests ---")
	SaveService.save_path = "user://test_chain_save.cfg"
	SaveService.load_save()
	GameManager.current_level_def = null
	EventBus.cascade_step.connect(func(_c: WormChain, depth: int, _n: int, _k: WormColor.Kind) -> void: _cascades.append(depth))
	EventBus.chain_reversing.connect(func(_c: WormChain) -> void: _reversals += 1)
	EventBus.chain_reached_end.connect(func(_c: WormChain) -> void: _reached_end += 1)
	EventBus.shot_resolve_finished.connect(func(_c: WormChain, scored: bool) -> void: _resolved.append(scored))
	EventBus.chain_cleared.connect(func(_c: WormChain) -> void: _cleared += 1)

	_test_insert_three_match()
	_test_no_match_below_three()
	_test_front_stops_when_edges_differ()
	_test_front_reverses_when_edges_match()
	_test_reverse_cascade()
	_test_match_at_front()
	_test_match_at_rear()
	_test_insert_between_adjacent()
	_test_rapid_shots()
	_test_insert_into_reversing_segment()
	_test_insert_behind_gap_tail()
	_test_rainbow_wildcard()
	_test_endpoint_waits_for_resolution()
	_test_endpoint_reached()
	_test_tunnel_worms_untargetable()
	_test_chain_cleared()
	_test_fuzz_invariants()
	_test_swept_contact_and_insertion()
	_test_projectile_target_order_and_gap()
	_test_aim_preview_contact()
	_test_shot_uses_fresh_pointer()
	_test_touch_pointer_and_swap()
	_test_rainbow_span_match()
	_test_march_join_keeps_cascade_depth()

	# Allow queued scenes, projectile trails and swap tweens to be reclaimed.
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.save_path))
	if _failed == 0:
		print("Cluck & Worms chain tests: ALL PASSED")
		get_tree().quit(0)
	else:
		printerr("Cluck & Worms chain tests: %d FAILED" % _failed)
		get_tree().quit(1)


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

func _make_chain(colors: Array, lead: float, march: float = 0.0, path_len: float = 3000.0) -> WormChain:
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(path_len, 0.0))
	path.curve = curve
	add_child(path)
	var chain := WormChain.new()
	chain.worm_scene = WORM_SCENE
	chain.path = path
	chain.worm_spacing = SPACING
	chain.march_speed = march
	chain.auto_spawn = false
	chain.pool_warm_count = 8
	add_child(chain)
	chain.set_process(false)
	for c: Variant in colors:
		chain.spawn_rear(c as WormColor.Kind)
	for worm: Worm in chain.get_worms():
		worm.target_path_distance += lead
		worm.path_distance += lead
	chain.step(0.0)
	_reset_events()
	return chain


func _dispose(chain: WormChain) -> void:
	var path: Node = chain.path
	chain.clear_all()
	chain.queue_free()
	path.queue_free()


func _reset_events() -> void:
	_cascades.clear()
	_reversals = 0
	_reached_end = 0
	_resolved.clear()
	_cleared = 0


func _run(chain: WormChain, seconds: float) -> void:
	var steps: int = int(ceil(seconds / DT))
	for i: int in range(steps):
		chain.step(DT)
		_check_spacing(chain, "spacing")


func _run_until_idle(chain: WormChain, max_seconds: float = 6.0) -> void:
	var t: float = 0.0
	chain.step(DT)
	while chain.is_busy() and t < max_seconds:
		chain.step(DT)
		_check_spacing(chain, "spacing")
		t += DT


func _colors(chain: WormChain) -> Array:
	var out: Array = []
	for worm: Worm in chain.get_worms():
		out.append(int(worm.worm_color))
	return out


func _check_spacing(chain: WormChain, label: String) -> void:
	var worms: Array[Worm] = chain.get_worms()
	for i: int in range(worms.size() - 1):
		var gap: float = worms[i].target_path_distance - worms[i + 1].target_path_distance
		if gap < SPACING - 0.01:
			_expect(false, "%s: overlap %.2f at %d" % [label, gap, i])
			return
		if worms[i].chain_index != i:
			_expect(false, "%s: chain_index mismatch at %d" % [label, i])
			return


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("  OK  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _test_insert_three_match() -> void:
	var chain := _make_chain([R, R, B, G, G], 600.0)
	var score_before: int = GameManager.score
	chain.insert_at(1, false, R)
	_expect(chain.get_worm_count() == 6, "insert adds exactly one worm")
	_run_until_idle(chain)
	_expect(_colors(chain) == [B, G, G], "3-match removes the run")
	_expect(GameManager.score > score_before, "match awards score")
	_expect(_resolved == [true], "shot resolves as scored")
	_dispose(chain)


func _test_no_match_below_three() -> void:
	var chain := _make_chain([R, B, G], 600.0)
	chain.insert_at(0, false, R)
	_run_until_idle(chain)
	_expect(_colors(chain) == [R, R, B, G], "pair of 2 does not match")
	_expect(_resolved == [false], "non-matching shot resolves unscored")
	_expect(chain.get_segment_count() == 1, "no gap after a miss")
	_dispose(chain)


func _test_front_stops_when_edges_differ() -> void:
	var chain := _make_chain([Y, R, R, G, B], 600.0, 60.0)
	var leader: Worm = chain.get_leader()
	chain.insert_at(2, false, R)
	_run_until_idle(chain)
	_expect(_colors(chain) == [Y, G, B], "middle match removed")
	_expect(chain.get_segment_count() == 2, "gap remains when edge colors differ")
	_expect(_reversals == 0, "no reversal when edge colors differ")
	var stopped_at: float = leader.target_path_distance
	_run(chain, 0.5)
	_expect(is_equal_approx(leader.target_path_distance, stopped_at), "cut-off front segment stands still")
	_run(chain, 4.0)
	_expect(chain.get_segment_count() == 1, "rear segment catches up and rejoins")
	_expect(leader.target_path_distance > stopped_at, "rejoined front is pushed forward again")
	_dispose(chain)


func _test_front_reverses_when_edges_match() -> void:
	var chain := _make_chain([G, R, R, G, B], 600.0, 0.0)
	var leader: Worm = chain.get_leader()
	chain.insert_at(2, false, R)
	chain.step(WormChain.INSERT_SETTLE_TIME + DT)
	_expect(_colors(chain) == [G, G, B], "middle match removed before reverse")
	var start: float = leader.target_path_distance
	chain.step(DT)
	chain.step(DT)
	_expect(chain.is_reversing(), "front segment enters reverse")
	_expect(chain.get_phase() == WormChain.Phase.REVERSING, "phase reports REVERSING")
	_expect(leader.target_path_distance < start, "leader moves backward (real reverse)")
	_expect(_reversals == 1, "chain_reversing emitted once")
	_run_until_idle(chain)
	_expect(chain.get_segment_count() == 1, "gap closed by reverse")
	_expect(not chain.is_reversing(), "reverse ends at contact")
	var rear: Worm = chain.get_rear()
	_expect(is_equal_approx(leader.target_path_distance - rear.target_path_distance, SPACING * 2.0), "rejoined spacing is exact")
	_dispose(chain)


func _test_reverse_cascade() -> void:
	var chain := _make_chain([B, G, G, R, R, G, Y], 600.0, 0.0)
	chain.insert_at(3, false, R)
	_run_until_idle(chain)
	if _colors(chain) != [B, Y]:
		print("    cascade debug: colors=", _colors(chain), " cascades=", _cascades, " segs=", chain.get_segment_count())
	_expect(_colors(chain) == [B, Y], "reverse join triggers cascade match")
	_expect(_cascades == [0, 1], "cascade depth 0 then 1")
	_expect(chain.get_segment_count() == 2, "after cascade, mismatched edges leave a gap")
	_dispose(chain)


func _test_match_at_front() -> void:
	var chain := _make_chain([R, R, B, G], 600.0)
	var b_pos: float = chain.get_worms()[2].target_path_distance
	chain.insert_at(0, true, R)
	_run_until_idle(chain)
	_expect(_colors(chain) == [B, G], "match at chain head")
	_expect(chain.get_segment_count() == 1 and _reversals == 0, "head match leaves no gap to reverse")
	_expect(is_equal_approx(chain.get_leader().target_path_distance, b_pos), "remaining worms do not jump")
	_dispose(chain)


func _test_match_at_rear() -> void:
	var chain := _make_chain([B, G, G], 600.0)
	chain.insert_at(2, false, G)
	_run_until_idle(chain)
	_expect(_colors(chain) == [B], "match at chain tail")
	_dispose(chain)


func _test_insert_between_adjacent() -> void:
	var chain := _make_chain([R, B, G, Y], 600.0)
	var lead_before: float = chain.get_leader().target_path_distance
	var rear_before: float = chain.get_rear().target_path_distance
	chain.insert_at(1, true, P)
	_expect(_colors(chain) == [R, P, B, G, Y], "insert lands between the two hit neighbors")
	_expect(is_equal_approx(chain.get_leader().target_path_distance, lead_before + SPACING), "front shifts one slot forward")
	_expect(is_equal_approx(chain.get_rear().target_path_distance, rear_before), "rear does not move on insert")
	_dispose(chain)


func _test_rapid_shots() -> void:
	var chain := _make_chain([R, R, B, B, G, Y], 600.0, 40.0)
	chain.insert_at(0, false, R)
	chain.step(DT)
	chain.insert_at(3, false, B)
	_expect(chain.get_worm_count() == 8, "two quick shots both insert")
	_run_until_idle(chain)
	_expect(_colors(chain) == [G, Y], "both pending matches resolve")
	_expect(_resolved.size() == 2, "each shot resolves exactly once")
	var unique: Dictionary = {}
	for worm: Worm in chain.get_worms():
		unique[worm.get_instance_id()] = true
	_expect(unique.size() == chain.get_worm_count(), "no duplicated worms")
	_dispose(chain)


func _test_insert_into_reversing_segment() -> void:
	var chain := _make_chain([B, Y, G, R, R, G, P], 800.0, 0.0)
	chain.insert_at(3, false, R)
	chain.step(WormChain.INSERT_SETTLE_TIME + DT)
	chain.step(DT)
	_expect(chain.is_reversing(), "setup: reversing")
	# Shoot into the reversing front segment (between B and Y).
	chain.insert_at(0, false, P)
	_run_until_idle(chain)
	_expect(_colors(chain) == [B, P, Y, G, G, P], "insert into a reversing segment rides along and rejoins")
	_expect(chain.get_segment_count() == 1, "reverse still closes the gap after the insert")
	_dispose(chain)


func _test_insert_behind_gap_tail() -> void:
	# Gap with mismatched edges, then shoot behind the front tail.
	var chain := _make_chain([Y, R, R, G, B], 600.0, 0.0)
	chain.insert_at(2, false, R)
	_run_until_idle(chain)
	_expect(chain.get_segment_count() == 2, "setup: gap open")
	chain.insert_at(0, false, G)
	# New tail G now faces head G → front must start reversing.
	_run(chain, 0.2)
	_expect(_reversals >= 1, "new tail matching the gap triggers reverse")
	_run_until_idle(chain)
	_expect(_colors(chain) == [Y, G, G, B], "join of 2 greens does not pop")
	_expect(chain.get_segment_count() == 1, "gap closed")
	_dispose(chain)


func _test_rainbow_wildcard() -> void:
	var chain := _make_chain([B, G, Y], 600.0)
	chain.get_worms()[1].worm_type = WormType.Kind.RAINBOW
	chain.insert_at(0, false, B)
	_run_until_idle(chain)
	_expect(_colors(chain) == [Y], "rainbow completes a 3-match")
	_dispose(chain)


func _test_endpoint_waits_for_resolution() -> void:
	var chain := _make_chain([R, R, B, G, Y], 990.0, 0.0, 1000.0)
	chain.insert_at(0, true, R)
	_expect(chain.get_leader().target_path_distance > 1000.0, "setup: insert pushes leader past the end")
	_run_until_idle(chain)
	chain.step(DT)
	_expect(_reached_end == 0, "no loss while the saving match resolves")
	_expect(_colors(chain) == [B, G, Y], "saving match removed the head")
	_dispose(chain)


func _test_endpoint_reached() -> void:
	var chain := _make_chain([R, B, G], 980.0, 100.0, 1000.0)
	_run(chain, 0.5)
	_expect(_reached_end == 1, "leader reaching the end emits chain_reached_end once")
	_dispose(chain)


func _test_tunnel_worms_untargetable() -> void:
	var chain := _make_chain([R, B], 30.0)
	var tunnel: Worm = chain.get_worms()[1]
	_expect(tunnel.target_path_distance < 0.0 and not chain.is_worm_targetable(tunnel), "worm still in tunnel is hidden from shots")
	_expect(not tunnel.visible, "tunnel worm is not drawn")
	_dispose(chain)


func _test_chain_cleared() -> void:
	var chain := _make_chain([R, R], 600.0)
	chain.spawns_remaining = 0
	chain.insert_at(1, false, R)
	_run_until_idle(chain)
	_expect(chain.get_worm_count() == 0 and _cleared == 1, "clearing the last worms emits chain_cleared")
	_dispose(chain)


func _test_fuzz_invariants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var total_ok: bool = true
	for trial: int in range(6):
		var colors: Array = []
		for i: int in range(28):
			colors.append(rng.randi_range(0, 3))
		var chain := _make_chain(colors, 1400.0, 45.0, 6000.0)
		var inserted: int = 0
		var removed_box: Array[int] = [0]
		var on_removed := func(_c: WormChain, _i: int, n: int) -> void: removed_box[0] += n
		EventBus.chain_worms_removed.connect(on_removed)
		for s: int in range(900):
			if s % 9 == 0 and chain.get_worm_count() > 0:
				var idx: int = rng.randi_range(0, chain.get_worm_count() - 1)
				if chain.is_worm_targetable(chain.get_worms()[idx]):
					chain.insert_at(idx, rng.randf() < 0.5, rng.randi_range(0, 3) as WormColor.Kind)
					inserted += 1
			chain.step(DT)
			var before: int = _failed
			_check_spacing(chain, "fuzz trial %d step %d" % [trial, s])
			if _failed != before:
				total_ok = false
				break
		_run_until_idle(chain)
		EventBus.chain_worms_removed.disconnect(on_removed)
		if chain.get_worm_count() != colors.size() + inserted - removed_box[0]:
			total_ok = false
			_expect(false, "fuzz trial %d: worm accounting" % trial)
		if chain.is_busy():
			total_ok = false
			_expect(false, "fuzz trial %d: chain settles" % trial)
		_dispose(chain)
	_expect(total_ok, "fuzz: 6 trials x 900 steps keep spacing, indices and counts valid")


# Regressions for pointer accuracy, first contact and wildcard/cascade edges.
func _test_swept_contact_and_insertion() -> void:
	var shot: ShootingWorm = preload("res://scenes/projectile/ShootingWorm.tscn").instantiate()
	add_child(shot)
	shot.set_physics_process(false)
	var contact: Dictionary = shot._segment_circle_hit(Vector2.ZERO, Vector2(200, 0), Vector2(100, 0), 20.0)
	_expect(not contact.is_empty() and is_equal_approx(float(contact["t"]), 0.4), "sweep returns first surface contact, not the worm center")
	var inside: Dictionary = shot._segment_circle_hit(Vector2(95, 0), Vector2(200, 0), Vector2(100, 0), 20.0)
	_expect(not inside.is_empty() and is_zero_approx(float(inside["t"])), "sweep starting inside a target reports immediate contact")
	var chain := _make_chain([R], 100.0)
	shot.launch(B, Vector2.ZERO, Vector2.RIGHT, chain)
	shot.global_position = Vector2(200, 0)
	shot._test_chain_collision()
	_expect(_colors(chain) == [R, B], "rear-facing impact inserts behind the worm even during a long frame")
	_dispose(chain)


func _test_aim_preview_contact() -> void:
	var chain := _make_chain([R], 200.0)
	var guide: Node2D = preload("res://scripts/chicken/AimGuide.gd").new()
	add_child(guide)
	guide.update_trajectory(R, 52.0, chain, 0.0, Vector2.ZERO)
	var expected: float = 200.0 - 16.0 - Worm.HEAD_RADIUS * 0.85
	_expect(is_equal_approx(float(guide.get("_current_target_dist")), expected), "aim guide includes muzzle offset and uses actual projectile contact")
	guide.queue_free()
	_dispose(chain)


func _make_chicken() -> Chicken:
	var chicken: Chicken = preload("res://scenes/chicken/Chicken.tscn").instantiate()
	add_child(chicken)
	chicken.set_process(false)
	chicken.position = Vector2(400, 350)
	return chicken


func _test_shot_uses_fresh_pointer() -> void:
	var previous_state: GameManager.State = GameManager.state
	GameManager.state = GameManager.State.PLAYING
	var chicken := _make_chicken()
	chicken.aim_at(chicken.global_position + Vector2.LEFT * 250.0)
	chicken.set("_pointer_pos", chicken.global_position + Vector2.RIGHT * 250.0)
	var directions: Array[Vector2] = []
	var on_shot := func(_color: WormColor.Kind, _origin: Vector2, direction: Vector2) -> void: directions.append(direction)
	EventBus.chicken_shot.connect(on_shot)
	chicken.shoot_now()
	EventBus.chicken_shot.disconnect(on_shot)
	_expect(directions.size() == 1 and directions[0].dot(Vector2.RIGHT) > 0.9999, "click fires at the current pointer, even after an immediate 180-degree turn")
	chicken.queue_free()
	GameManager.state = previous_state


func _test_touch_pointer_and_swap() -> void:
	var previous_state: GameManager.State = GameManager.state
	GameManager.state = GameManager.State.PLAYING
	var chicken := _make_chicken()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = chicken.get_canvas_transform() * (chicken.global_position + Vector2(200, -100))
	var shots_before: int = GameManager.shots_fired
	chicken._unhandled_input(touch)
	_expect(GameManager.shots_fired == shots_before, "menu touch that creates the launcher cannot also fire a shot")
	chicken._handle_touch(touch)
	var touch_aim: Vector2 = chicken.get("_pointer_pos")
	touch.pressed = false
	chicken._handle_touch(touch)
	chicken._update_pointer_from_devices()
	_expect((chicken.get("_pointer_pos") as Vector2).is_equal_approx(touch_aim), "touch aim stays in place after lifting the finger")
	chicken.current_color = R
	chicken.next_color = B
	touch.pressed = true
	touch.position = chicken.get_canvas_transform() * chicken.global_position
	chicken._handle_touch(touch)
	_expect(chicken.current_color == B and chicken.next_color == R, "single tap on the chicken swaps the loadout immediately")
	touch.pressed = false
	chicken._input(touch)
	_expect((chicken.get("_touch_ids") as Dictionary).is_empty(), "touch release over a UI control cannot leave a held finger")
	var viewport := chicken.get_viewport()
	var original_canvas: Transform2D = viewport.canvas_transform
	viewport.canvas_transform = Transform2D(0.0, Vector2(0.7, 0.7), 0.0, Vector2(80, 40))
	var world_target: Vector2 = chicken.global_position + Vector2(200, -100)
	touch.position = chicken.get_canvas_transform() * world_target
	touch.pressed = true
	chicken._handle_touch(touch)
	_expect((chicken.get("_pointer_pos") as Vector2).is_equal_approx(world_target), "scaled and translated touch coordinates resolve to the correct world target")
	viewport.canvas_transform = original_canvas
	get_tree().paused = true
	_expect((chicken.get("_touch_ids") as Dictionary).is_empty(), "pausing releases fingers before resume")
	get_tree().paused = false
	touch.position = chicken.get_canvas_transform() * (chicken.global_position + Vector2(200, -100))
	chicken._handle_touch(touch)
	chicken._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect((chicken.get("_touch_ids") as Dictionary).is_empty(), "browser focus loss releases touch state")
	chicken._handle_touch(touch)
	chicken.set_shooting_enabled(false)
	_expect((chicken.get("_touch_ids") as Dictionary).is_empty(), "disabling controls releases held touch fingers")
	chicken.queue_free()
	GameManager.state = previous_state


func _test_rainbow_span_match() -> void:
	var chain := _make_chain([B, G, G, G, B], 600.0)
	for i: int in [1, 2, 3]:
		chain.get_worms()[i].worm_type = WormType.Kind.RAINBOW
	var run: Array[int] = chain._find_run(2)
	_expect(run.size() == 5, "rainbow seed looks through adjacent wildcards to both real colors")
	_dispose(chain)


func _test_march_join_keeps_cascade_depth() -> void:
	var chain := _make_chain([B, G, G, R, R, G, Y], 800.0)
	chain.insert_at(3, false, R)
	chain.step(WormChain.INSERT_SETTLE_TIME + DT)
	_expect(_cascades == [0], "cascade setup opens a matching gap")
	# A long frame can let the rear close the gap before reverse processing.
	chain.march_speed = 400.0
	chain.step(0.5)
	_expect(_cascades == [0, 1], "rear-driven gap closure preserves the earned cascade depth")
	_dispose(chain)


func _test_projectile_target_order_and_gap() -> void:
	var chain := _make_chain([R, B, G], 500.0)
	var worms: Array[Worm] = chain.get_worms()
	worms[0].global_position = Vector2(100, 26)
	worms[1].global_position = Vector2(108, 0)
	worms[2].global_position = Vector2(300, 0)
	var first_target: Worm = worms[1]
	var targets: Array[Worm] = []
	var on_hit := func(_shot: ShootingWorm, hit: Worm, _chain: WormChain) -> void: targets.append(hit)
	EventBus.projectile_hit_chain.connect(on_hit)
	var shot: ShootingWorm = preload("res://scenes/projectile/ShootingWorm.tscn").instantiate()
	add_child(shot)
	shot.set_physics_process(false)
	shot.launch(Y, Vector2.ZERO, Vector2.RIGHT, chain)
	shot.global_position = Vector2(350, 0)
	shot._test_chain_collision()
	_expect(targets.size() == 1 and targets[0] == first_target, "overlapping targets choose the first contacted surface, not the closest center")
	# Insertion above changed array indices; build an independent gap fixture.
	_dispose(chain)
	chain = _make_chain([R, B, G], 500.0)
	worms = chain.get_worms()
	worms[0].global_position = Vector2(100, 40)
	worms[1].global_position = Vector2(100, -40)
	worms[2].global_position = Vector2(300, 0)
	var far_target: Worm = worms[2]
	targets.clear()
	shot = preload("res://scenes/projectile/ShootingWorm.tscn").instantiate()
	add_child(shot)
	shot.set_physics_process(false)
	shot.launch(Y, Vector2.ZERO, Vector2.RIGHT, chain)
	shot.global_position = Vector2(350, 0)
	shot._test_chain_collision()
	_expect(targets.size() == 1 and targets[0] == far_target, "a high-speed shot passes through a real gap to the far chain")
	EventBus.projectile_hit_chain.disconnect(on_hit)
	_dispose(chain)
