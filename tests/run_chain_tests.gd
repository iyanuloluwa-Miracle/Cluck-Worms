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
