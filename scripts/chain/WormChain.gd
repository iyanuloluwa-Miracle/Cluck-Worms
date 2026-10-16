class_name WormChain
extends Node2D
## Zuma-style worm chain built on a segment model.
##
## Index 0 = leader (closest to the path END). Last = rear (path START).
## [member Worm.target_path_distance] is the authoritative logical position;
## [member Worm.path_distance] is the displayed position that eases toward it.
##
## Rules (all deterministic, driven by [method step]):
## - Worms whose logical spacing is exactly [member worm_spacing] form a segment.
## - Only the REAR segment (fed by the spawner) is pushed forward by the march.
## - A front segment cut off by a match stops. If the two worms facing each
##   other across the gap share a color, the front segment rolls BACKWARD
##   (accelerating) until it hits the segment behind it.
## - Contacts are resolved by pushing worms forward; a join re-checks matches
##   at the joint, producing cascades.
## - Matches are only evaluated around an inserted worm or at a join point.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MIN_MATCH_SIZE: int = 3

## Display → logical easing for slides caused by inserts and pushes.
const FOLLOW_RATE: float = 20.0

## Two worms closer than spacing + this are treated as touching.
const JOIN_EPSILON: float = 0.5

## Delay between an insert landing and its match check (lets the slide read).
const INSERT_SETTLE_TIME: float = 0.09

## Reverse motion of a front segment pulled back toward a matching color (px/s).
const REVERSE_START_SPEED: float = 140.0
const REVERSE_ACCEL: float = 1100.0
const REVERSE_MAX_SPEED: float = 620.0

## Distance travelled at intro speed when a level starts (Zuma roll-in).
const INTRO_SPEED_MULTIPLIER: float = 7.0

const SPAWN_DISTANCE: float = 0.0

# ---------------------------------------------------------------------------
# Phase (derived, read-only for other systems)
# ---------------------------------------------------------------------------

enum Phase {
	## Rear segment marching, nothing pending.
	MARCHING,
	## A shot landed and its match check is pending.
	RESOLVING,
	## At least one front segment is rolling backward to close a gap.
	REVERSING,
	## Scripted hold (boss) or game paused.
	PAUSED,
	LEVEL_COMPLETE,
	LEVEL_FAILED,
}

# ---------------------------------------------------------------------------
# Exported
# ---------------------------------------------------------------------------

@export var worm_scene: PackedScene
@export var path: Path2D
@export var worm_spacing: float = 40.0
@export var march_speed: float = 55.0
@export var is_marching: bool = true
@export var spawn_interval: float = 0.72
@export var auto_spawn: bool = true
@export var max_worms: int = 120
@export var stop_spawn_at_cap: bool = true

## When >= 0, auto-spawn stops after this many additional rear spawns.
## -1 = infinite (sandbox). Set from LevelData.total_worms - initial.
@export var spawns_remaining: int = -1

## Pre-warmed pool size. 0 = create a child pool automatically.
@export var pool_warm_count: int = 64

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _worms: Array[Worm] = []
var _curve: Curve2D
var _path_length: float = 0.0
var _spawn_timer: float = 0.0
var _has_reached_end: bool = false
var _pool: WormPool

## LEVEL_COMPLETE / LEVEL_FAILED lock; otherwise -1.
var _terminal_phase: int = -1

## Pending insert checks: [{"worm": Worm, "time": float}]
var _pending_checks: Array[Dictionary] = []

## Reverse speed per gap, keyed by the instance id of the front segment's tail.
var _reverse_speed: Dictionary = {}
## Cascade depth carried by a gap (same key) — set when a match opens it.
var _gap_depth: Dictionary = {}

## Temporary chain slow from Slow special worms / ability (seconds).
var _slow_timer: float = 0.0
var _last_danger_emit: float = -1.0
## External hold (boss intro / scripted stare).
var _hold_march: bool = false
## Remaining distance to roll in at intro speed.
var _intro_remaining: float = 0.0

## World position of the most recent match / reverse (for feedback placement).
var last_match_position: Vector2 = Vector2.ZERO
var last_reverse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	assert(worm_scene != null, "WormChain requires worm_scene.")
	_ensure_pool()
	if path != null:
		_rebuild_curve_cache()
	_spawn_timer = spawn_interval


func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.is_playing():
		return
	step(delta)


## Advance the simulation by [param delta]. Called from [method _process];
## tests call it directly for deterministic stepping.
func step(delta: float) -> void:
	if _curve == null:
		if path != null:
			_rebuild_curve_cache()
		if _curve == null:
			return
	if _terminal_phase >= 0:
		_sync_worm_transforms(delta)
		return

	if _slow_timer > 0.0:
		_slow_timer = maxf(_slow_timer - delta, 0.0)

	var gaps_before: Array[int] = _gap_tail_ids()

	if not _hold_march and is_marching:
		if auto_spawn and not _has_reached_end:
			_process_auto_spawn(delta)
		_advance_rear_segment(delta)
	_process_reverse(delta)
	_resolve_contacts(gaps_before)
	_process_pending_checks(delta)

	_sync_worm_transforms(delta)
	if not is_busy():
		_check_end_condition()
	_emit_danger_warning()


# ---------------------------------------------------------------------------
# Public API — queries
# ---------------------------------------------------------------------------

func get_worm_count() -> int:
	return _worms.size()


func get_worms() -> Array[Worm]:
	return _worms


func get_path_length() -> float:
	return _path_length


func get_leader() -> Worm:
	return _worms[0] if not _worms.is_empty() else null


func get_rear() -> Worm:
	return _worms[_worms.size() - 1] if not _worms.is_empty() else null


## True while a match check or gap reversal is in progress.
func is_busy() -> bool:
	return not _pending_checks.is_empty() or is_reversing()


## True while any gap has matching edge colors — the front segment is (or is
## about to be, this very step) rolling backward.
func is_reversing() -> bool:
	for i: int in range(_worms.size() - 1):
		if not _is_connected(i) and _colors_link(_worms[i], _worms[i + 1]):
			return true
	return false


func get_phase() -> Phase:
	if _terminal_phase >= 0:
		return _terminal_phase as Phase
	if is_reversing():
		return Phase.REVERSING
	if not _pending_checks.is_empty():
		return Phase.RESOLVING
	if _hold_march or GameManager.is_paused:
		return Phase.PAUSED
	return Phase.MARCHING


## Number of separate segments (1 = one solid train).
func get_segment_count() -> int:
	return _segments().size()


## Colors currently on the visible chain — the shooter only deals these.
func get_present_colors() -> Array[int]:
	var colors: Array[int] = []
	for worm: Worm in _worms:
		if worm.target_path_distance < 0.0:
			continue
		var c: int = int(worm.worm_color)
		if not colors.has(c):
			colors.append(c)
	return colors


## Player / ability slow — stacks with Slow special worms.
func apply_slow(duration: float) -> void:
	_slow_timer = maxf(_slow_timer, maxf(duration, 0.0))


func get_slow_remaining() -> float:
	return _slow_timer


## Leader progress along the path in [0, 1].
func get_leader_progress() -> float:
	if _worms.is_empty() or _path_length <= 1.0:
		return 0.0
	return clampf(_worms[0].target_path_distance / _path_length, 0.0, 1.0)


## A visible worm is on the path (not still queued in the start tunnel).
func is_worm_targetable(worm: Worm) -> bool:
	return (
		is_instance_valid(worm)
		and worm.is_active_in_chain()
		and worm.target_path_distance >= 0.0
		and worm.path_distance >= 0.0
	)


# ---------------------------------------------------------------------------
# Public API — control
# ---------------------------------------------------------------------------

## Start the fast Zuma roll-in for the first [param distance] pixels.
func begin_intro_roll(distance: float) -> void:
	_intro_remaining = maxf(distance, 0.0)


## Bomb ability: clear the worm nearest [param global_pos] and its neighbors.
func detonate_at_nearest(global_pos: Vector2) -> int:
	if _worms.is_empty() or _terminal_phase >= 0:
		return 0
	var idx: int = find_nearest_worm_index(global_pos)
	if idx < 0:
		return 0
	var indices: Array[int] = []
	for i: int in [idx - 1, idx, idx + 1]:
		if i >= 0 and i < _worms.size():
			indices.append(i)
	var color: WormColor.Kind = _worms[idx].worm_color
	_remove_group(indices, color, 0, &"bomb")
	return indices.size()


## Inject a burst of rear worms (boss pattern support).
func inject_rear_burst(count: int, prefer_special: bool = false) -> void:
	for i: int in range(maxi(count, 0)):
		var rolled: Dictionary = GameManager.roll_worm()
		var type: WormType.Kind = rolled["type"] as WormType.Kind
		if prefer_special and type == WormType.Kind.NORMAL:
			type = WormType.Kind.BOMB if (i % 2 == 0) else WormType.Kind.SLOW
		spawn_rear(rolled["color"] as WormColor.Kind, type)
		if spawns_remaining > 0:
			spawns_remaining -= 1


## Boss attack: repaint up to [param count] visible worms. Returns the repainted
## worms. Matches are not triggered by repainting (only by inserts / joins).
func recolor_random(count: int, color: WormColor.Kind) -> Array[Worm]:
	var candidates: Array[Worm] = []
	for worm: Worm in _worms:
		if is_worm_targetable(worm) and worm.worm_color != color and worm.worm_type == WormType.Kind.NORMAL:
			candidates.append(worm)
	var rng: RandomNumberGenerator = GameManager.get_rng()
	var changed: Array[Worm] = []
	while changed.size() < count and not candidates.is_empty():
		var worm: Worm = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		worm.worm_color = color
		changed.append(worm)
	return changed


## Victory: pop every worm (no scoring) and lock the chain.
func pop_all(reason: StringName = &"victory") -> void:
	var removed: Array[Worm] = _worms.duplicate()
	_worms.clear()
	_pending_checks.clear()
	_reverse_speed.clear()
	_gap_depth.clear()
	for worm: Worm in removed:
		worm.begin_match()
		EventBus.worm_removed.emit(worm, reason)
	_kickoff_falls(removed)
	spawns_remaining = 0
	mark_level_complete()


## Scripted hold (boss intro / stare). Gap reversal and match checks continue.
func set_hold_march(hold: bool) -> void:
	_hold_march = hold


func is_holding() -> bool:
	return _hold_march


func mark_level_complete() -> void:
	is_marching = false
	auto_spawn = false
	_terminal_phase = Phase.LEVEL_COMPLETE
	_pending_checks.clear()
	_reverse_speed.clear()


func mark_level_failed() -> void:
	is_marching = false
	auto_spawn = false
	_terminal_phase = Phase.LEVEL_FAILED
	_pending_checks.clear()
	_reverse_speed.clear()


# ---------------------------------------------------------------------------
# Public API — mutation
# ---------------------------------------------------------------------------

## Append a worm behind the rear. Worms with negative distance wait hidden in
## the start tunnel and roll in as the train advances.
func spawn_rear(
	color: WormColor.Kind = WormColor.Kind.RED,
	type: WormType.Kind = WormType.Kind.NORMAL
) -> Worm:
	if stop_spawn_at_cap and _worms.size() >= max_worms:
		return null
	var distance: float = SPAWN_DISTANCE
	if not _worms.is_empty():
		distance = minf(get_rear().target_path_distance - worm_spacing, SPAWN_DISTANCE)
	var worm: Worm = _create_worm(color, distance, true, type)
	if worm == null:
		return null
	_worms.append(worm)
	_reindex()
	EventBus.worm_spawned.emit(worm)
	EventBus.chain_worms_inserted.emit(self, _worms.size() - 1, 1)
	return worm


## Configure finite-level spawning. Call after seeding the initial train.
func configure_spawn_budget(remaining_after_initial: int) -> void:
	spawns_remaining = maxi(remaining_after_initial, 0)
	if spawns_remaining == 0:
		auto_spawn = false


## Insert a worm next to [param hit_index]. [param before] = on the leader side.
## The new worm joins the hit worm's segment; contacts push worms forward.
func insert_at(
	hit_index: int,
	before: bool,
	color: WormColor.Kind,
	type: WormType.Kind = WormType.Kind.NORMAL,
	queue_check: bool = true
) -> Worm:
	if _terminal_phase >= 0:
		return null
	var worm: Worm
	if _worms.is_empty():
		worm = _create_worm(color, SPAWN_DISTANCE, true, type)
		if worm == null:
			return null
		_worms.append(worm)
	else:
		hit_index = clampi(hit_index, 0, _worms.size() - 1)
		var hit: Worm = _worms[hit_index]
		var gaps_before: Array[int] = _gap_tail_ids()
		if not before and hit_index + 1 < _worms.size() and not _is_connected(hit_index):
			# The new worm becomes the gap-facing tail; the old gap state is stale.
			var old_key: int = hit.get_instance_id()
			gaps_before.erase(old_key)
			_reverse_speed.erase(old_key)
			_gap_depth.erase(old_key)
		var array_index: int = hit_index if before else hit_index + 1
		var distance: float = hit.target_path_distance + (worm_spacing if before else -worm_spacing)
		worm = _create_worm(color, distance, false, type)
		if worm == null:
			return null
		# Start the slide from the hit worm so the insert visibly squeezes in.
		worm.path_distance = hit.path_distance
		worm.state = Worm.State.SETTLING
		_worms.insert(array_index, worm)
		_reindex()
		_resolve_contacts(gaps_before)
	_reindex()
	EventBus.worm_spawned.emit(worm)
	EventBus.chain_worms_inserted.emit(self, worm.chain_index, 1)
	if queue_check:
		_pending_checks.append({"worm": worm, "time": INSERT_SETTLE_TIME})
	return worm


## Insert from a projectile hit, then queue its match check.
func insert_from_projectile(global_pos: Vector2, color: WormColor.Kind, hit_worm: Worm = null) -> Worm:
	var hit: Worm = hit_worm
	if hit == null or not is_instance_valid(hit) or not _worms.has(hit):
		var nearest: int = find_nearest_worm_index(global_pos)
		if nearest < 0:
			return null
		hit = _worms[nearest]
	var hit_index: int = _worms.find(hit)
	return insert_at(hit_index, _is_impact_ahead(hit, global_pos), color)


func clear_all(reason: StringName = &"reset") -> void:
	var snapshot: Array[Worm] = _worms.duplicate()
	_worms.clear()
	for worm: Worm in snapshot:
		EventBus.worm_removed.emit(worm, reason)
		worm.kill()
	_has_reached_end = false
	_spawn_timer = 0.0
	_pending_checks.clear()
	_reverse_speed.clear()
	_gap_depth.clear()
	_hold_march = false
	_intro_remaining = 0.0


func rebuild_path_cache() -> void:
	_rebuild_curve_cache()


func find_nearest_worm_index(global_pos: Vector2) -> int:
	var best_index: int = -1
	var best_dist_sq: float = INF
	for i: int in range(_worms.size()):
		var worm: Worm = _worms[i]
		if not is_worm_targetable(worm):
			continue
		var dist_sq: float = worm.global_position.distance_squared_to(global_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index


## Array index the projectile would occupy after hitting [param hit_worm].
func get_insert_index_for_hit(hit_worm: Worm, hit_global_pos: Vector2) -> int:
	var hit_index: int = _worms.find(hit_worm)
	if hit_index < 0:
		return 0
	return hit_index if _is_impact_ahead(hit_worm, hit_global_pos) else hit_index + 1


# ---------------------------------------------------------------------------
# Segments
# ---------------------------------------------------------------------------

func _is_connected(front_index: int) -> bool:
	## True when worm [param front_index] touches the worm behind it.
	if front_index < 0 or front_index + 1 >= _worms.size():
		return false
	var gap: float = _worms[front_index].target_path_distance - _worms[front_index + 1].target_path_distance
	return gap <= worm_spacing + JOIN_EPSILON


## Segments as [start, end] inclusive index pairs, front to rear.
func _segments() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _worms.is_empty():
		return result
	var start: int = 0
	for i: int in range(_worms.size() - 1):
		if not _is_connected(i):
			result.append(Vector2i(start, i))
			start = i + 1
	result.append(Vector2i(start, _worms.size() - 1))
	return result


## Instance ids of every front-segment tail currently facing a gap.
func _gap_tail_ids() -> Array[int]:
	var ids: Array[int] = []
	for i: int in range(_worms.size() - 1):
		if not _is_connected(i):
			ids.append(_worms[i].get_instance_id())
	return ids


func _colors_link(a: Worm, b: Worm) -> bool:
	if a.worm_type == WormType.Kind.RAINBOW or b.worm_type == WormType.Kind.RAINBOW:
		return true
	return a.worm_color == b.worm_color


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _advance_rear_segment(delta: float) -> void:
	if _worms.is_empty():
		return
	var speed: float = march_speed * _march_tension_multiplier()
	if _slow_timer > 0.0:
		speed *= 0.45
	if _intro_remaining > 0.0:
		speed = maxf(speed, march_speed) * INTRO_SPEED_MULTIPLIER
	var distance: float = speed * delta
	if _intro_remaining > 0.0:
		distance = minf(distance, _intro_remaining)
		_intro_remaining -= distance
	var segs: Array[Vector2i] = _segments()
	var rear: Vector2i = segs[segs.size() - 1]
	for i: int in range(rear.x, rear.y + 1):
		_worms[i].target_path_distance += distance
		_worms[i].path_distance += distance


func _process_reverse(delta: float) -> void:
	## Front segments whose gap edges match roll backward; others stand still.
	var segs: Array[Vector2i] = _segments()
	var live_keys: Dictionary = {}
	for s: int in range(segs.size() - 1):
		var seg: Vector2i = segs[s]
		var tail: Worm = _worms[seg.y]
		var behind: Worm = _worms[seg.y + 1]
		var key: int = tail.get_instance_id()
		live_keys[key] = true
		if not _colors_link(tail, behind):
			_reverse_speed[key] = 0.0
			continue
		var speed: float = float(_reverse_speed.get(key, 0.0))
		if speed <= 0.0:
			speed = REVERSE_START_SPEED
			last_reverse_position = tail.global_position
			EventBus.chain_reversing.emit(self)
		else:
			speed = minf(speed + REVERSE_ACCEL * delta, REVERSE_MAX_SPEED)
		_reverse_speed[key] = speed
		# Never back past the worm behind: contact resolution snaps the join.
		var room: float = tail.target_path_distance - behind.target_path_distance - worm_spacing
		var move: float = minf(speed * delta, maxf(room, 0.0))
		for i: int in range(seg.x, seg.y + 1):
			_worms[i].target_path_distance -= move
			_worms[i].path_distance -= move
	# Forget gaps that no longer exist.
	for key: Variant in _reverse_speed.keys():
		if not live_keys.has(key):
			_reverse_speed.erase(key)
	for key: Variant in _gap_depth.keys():
		if not live_keys.has(key):
			_gap_depth.erase(key)


func _resolve_contacts(gaps_before: Array[int]) -> void:
	## Push worms forward so no two overlap, then fire join checks for gaps
	## that closed this step.
	for i: int in range(_worms.size() - 2, -1, -1):
		var required: float = _worms[i + 1].target_path_distance + worm_spacing
		if _worms[i].target_path_distance < required:
			_worms[i].target_path_distance = required
	if gaps_before.is_empty():
		return
	var joins: Array[Dictionary] = []
	for i: int in range(_worms.size() - 1):
		var key: int = _worms[i].get_instance_id()
		if gaps_before.has(key) and _is_connected(i):
			# Snap the join to exact spacing so segments stay perfectly packed.
			var exact: float = _worms[i + 1].target_path_distance + worm_spacing
			var correction: float = exact - _worms[i].target_path_distance
			if absf(correction) > 0.0001:
				var j: int = i
				while j >= 0:
					_worms[j].target_path_distance += correction
					if j == 0 or not _is_connected(j - 1):
						break
					j -= 1
			var was_reversing: bool = float(_reverse_speed.get(key, 0.0)) > 0.0
			joins.append({
				"tail": _worms[i],
				"depth": int(_gap_depth.get(key, 0)),
				"reversing": was_reversing,
			})
			_reverse_speed.erase(key)
			_gap_depth.erase(key)
	for join: Dictionary in joins:
		var tail: Worm = join["tail"] as Worm
		if bool(join["reversing"]):
			EventBus.chain_collapse_finished.emit(self)
		var idx: int = _worms.find(tail)
		if idx < 0 or idx + 1 >= _worms.size():
			continue
		_check_join(idx, int(join["depth"]))


func _march_tension_multiplier() -> float:
	## Speeds up as the leader nears the pit or the spawn budget runs low.
	var mul: float = 1.0
	if _path_length > 1.0 and not _worms.is_empty():
		var progress: float = get_leader_progress()
		if progress > 0.55:
			mul += (progress - 0.55) * 0.85
	if spawns_remaining >= 0 and spawns_remaining <= 8:
		mul += 0.12
	return mul


# ---------------------------------------------------------------------------
# Matching
# ---------------------------------------------------------------------------

func _process_pending_checks(delta: float) -> void:
	if _pending_checks.is_empty():
		return
	var due: Array[Dictionary] = []
	var still: Array[Dictionary] = []
	for entry: Dictionary in _pending_checks:
		entry["time"] = float(entry["time"]) - delta
		if float(entry["time"]) <= 0.0:
			due.append(entry)
		else:
			still.append(entry)
	_pending_checks = still
	for entry: Dictionary in due:
		var worm: Worm = entry["worm"] as Worm
		var idx: int = _worms.find(worm) if is_instance_valid(worm) else -1
		var scored: bool = idx < 0  # Already popped by another match.
		if idx >= 0:
			var run: Array[int] = _find_run(idx)
			if run.size() >= MIN_MATCH_SIZE:
				_remove_group(run, _run_color(run), 0, &"match")
				scored = true
		GameManager.notify_shot_resolved(scored)
		EventBus.shot_resolve_finished.emit(self, scored)


func _check_join(front_index: int, depth: int) -> void:
	## A gap just closed between [param front_index] and the worm behind it.
	var run: Array[int] = _find_run(front_index)
	if run.size() < MIN_MATCH_SIZE or not run.has(front_index + 1):
		return
	_remove_group(run, _run_color(run), depth, &"match")


## Contiguous same-color run (within one segment) containing [param index].
## Rainbow worms act as wildcards.
func _find_run(index: int) -> Array[int]:
	var best: Array[int] = []
	var seed: Worm = _worms[index]
	var candidates: Array[int] = []
	if seed.worm_type == WormType.Kind.RAINBOW:
		for n: int in [index - 1, index + 1]:
			if n >= 0 and n < _worms.size() and _worms[n].worm_type != WormType.Kind.RAINBOW:
				if (n < index and _is_connected(n)) or (n > index and _is_connected(index)):
					candidates.append(int(_worms[n].worm_color))
		if candidates.is_empty():
			candidates.append(int(seed.worm_color))
	else:
		candidates.append(int(seed.worm_color))
	for color: int in candidates:
		var run: Array[int] = [index]
		var i: int = index - 1
		while i >= 0 and _is_connected(i) and _worm_matches(_worms[i], color):
			run.push_front(i)
			i -= 1
		i = index + 1
		while i < _worms.size() and _is_connected(i - 1) and _worm_matches(_worms[i], color):
			run.append(i)
			i += 1
		if run.size() > best.size():
			best = run
	return best


func _worm_matches(worm: Worm, color: int) -> bool:
	return worm.worm_type == WormType.Kind.RAINBOW or int(worm.worm_color) == color


func _run_color(run: Array[int]) -> WormColor.Kind:
	for i: int in run:
		if _worms[i].worm_type != WormType.Kind.RAINBOW:
			return _worms[i].worm_color
	return _worms[run[0]].worm_color


func _remove_group(indices: Array[int], color: WormColor.Kind, depth: int, reason: StringName) -> void:
	if indices.is_empty():
		return
	var start: int = indices.min()
	var count: int = indices.size()
	var marked: Dictionary = {}
	var has_bonus: bool = false
	for i: int in indices:
		marked[i] = true
	# Specials inside the group: bombs take a neighbor on each side.
	for i: int in indices:
		var w: Worm = _worms[i]
		match w.worm_type:
			WormType.Kind.BOMB:
				for n: int in [i - 1, i + 1]:
					if n >= 0 and n < _worms.size():
						marked[n] = true
			WormType.Kind.SLOW:
				_slow_timer = maxf(_slow_timer, 2.4)
			WormType.Kind.BONUS:
				has_bonus = true

	var mid: Worm = _worms[clampi(start + count / 2, 0, _worms.size() - 1)]
	last_match_position = mid.global_position
	EventBus.chain_match_found.emit(self, start, count, color)
	EventBus.cascade_step.emit(self, depth, count, color)
	if depth == 0 and count >= 4 and reason == &"match":
		EventBus.good_shot.emit(mid.global_position, count)

	var first: int = _worms.size()
	for key: Variant in marked:
		first = mini(first, int(key))
	var kept: Array[Worm] = []
	var removed: Array[Worm] = []
	for i: int in range(_worms.size()):
		if marked.has(i):
			removed.append(_worms[i])
		else:
			kept.append(_worms[i])
	GameManager.register_match(removed.size(), color, depth, has_bonus)

	_worms = kept
	_reindex()
	for worm: Worm in removed:
		_pending_drop(worm)
		worm.begin_match()
		EventBus.worm_removed.emit(worm, reason)
	EventBus.chain_worms_removed.emit(self, first, removed.size())
	EventBus.chain_collapse_started.emit(self, removed.size())
	_kickoff_falls(removed)

	# The new gap carries the next cascade depth.
	if first > 0 and first < _worms.size():
		_gap_depth[_worms[first - 1].get_instance_id()] = depth + 1

	if _worms.is_empty():
		_try_emit_cleared()


func _pending_drop(worm: Worm) -> void:
	for i: int in range(_pending_checks.size() - 1, -1, -1):
		if _pending_checks[i]["worm"] == worm:
			# The shot's worm popped as part of this group — resolved as a score.
			_pending_checks.remove_at(i)
			GameManager.notify_shot_resolved(true)
			EventBus.shot_resolve_finished.emit(self, true)


## Level is won only when the chain is empty and no more worms will spawn.
func _try_emit_cleared() -> void:
	if not _worms.is_empty():
		return
	if spawns_remaining > 0:
		return
	EventBus.chain_cleared.emit(self)


func _is_impact_ahead(hit_worm: Worm, hit_global_pos: Vector2) -> bool:
	## True when the projectile struck the leader-facing side of [param hit_worm].
	if _curve == null or path == null:
		return true
	var sample: Transform2D = _sample_path(clampf(hit_worm.path_distance, 0.0, _path_length))
	var tangent: Vector2 = path.global_transform.basis_xform(sample.x).normalized()
	return (hit_global_pos - hit_worm.global_position).dot(tangent) >= 0.0


# ---------------------------------------------------------------------------
# Spawn / pool / fall
# ---------------------------------------------------------------------------

func _ensure_pool() -> void:
	_pool = get_node_or_null("WormPool") as WormPool
	if _pool == null:
		_pool = WormPool.new()
		_pool.name = "WormPool"
		add_child(_pool)
	_pool.worm_scene = worm_scene
	if _pool.get_available_count() + _pool.get_in_use_count() == 0:
		_pool.warm(pool_warm_count)


func _process_auto_spawn(delta: float) -> void:
	if spawns_remaining == 0:
		auto_spawn = false
		return
	_spawn_timer += delta
	if _spawn_timer < spawn_interval:
		return
	# Only feed the tunnel once the rear has rolled onto the path.
	if not _worms.is_empty() and get_rear().target_path_distance < 0.0:
		return
	_spawn_timer = 0.0
	var rolled: Dictionary = GameManager.roll_worm()
	var worm: Worm = spawn_rear(rolled["color"] as WormColor.Kind, rolled["type"] as WormType.Kind)
	if worm != null and spawns_remaining > 0:
		spawns_remaining -= 1
		if spawns_remaining == 0:
			auto_spawn = false


func _create_worm(
	color: WormColor.Kind,
	distance: float,
	snap: bool,
	type: WormType.Kind = WormType.Kind.NORMAL
) -> Worm:
	var worm: Worm = _pool.acquire() if _pool != null else null
	if worm == null:
		worm = worm_scene.instantiate() as Worm
		add_child(worm)
	elif worm.get_parent() != self:
		worm.reparent(self, false)
	worm.pool = _pool
	worm.setup(color, distance, type)
	worm.set_slot_distance(distance, snap)
	worm.owning_chain = self
	_apply_transform_to_worm(worm)
	return worm


func _emit_danger_warning() -> void:
	if _worms.is_empty() or _path_length <= 1.0:
		return
	var remaining: float = _path_length - _worms[0].target_path_distance
	var zone: float = 160.0
	if remaining > zone:
		if _last_danger_emit >= 0.0:
			_last_danger_emit = -1.0
			EventBus.danger_warning.emit(0.0)
		return
	var urgency: float = 1.0 - clampf(remaining / zone, 0.0, 1.0)
	if absf(urgency - _last_danger_emit) < 0.08:
		return
	_last_danger_emit = urgency
	EventBus.danger_warning.emit(urgency)


func _kickoff_falls(removed: Array[Worm]) -> void:
	# One pausable timer for the whole batch.
	var tree := get_tree()
	if tree == null:
		for worm: Worm in removed:
			if is_instance_valid(worm):
				worm.begin_fall()
		return
	await tree.create_timer(Worm.MATCH_POP_DURATION, false).timeout
	for worm: Worm in removed:
		if is_instance_valid(worm) and worm.state == Worm.State.MATCHED:
			worm.begin_fall()


# ---------------------------------------------------------------------------
# Transforms / path
# ---------------------------------------------------------------------------

func _sync_worm_transforms(delta: float) -> void:
	var t: float = 1.0 - exp(-FOLLOW_RATE * delta)
	for worm: Worm in _worms:
		if absf(worm.path_distance - worm.target_path_distance) > 0.2:
			worm.path_distance = lerpf(worm.path_distance, worm.target_path_distance, t)
		else:
			worm.path_distance = worm.target_path_distance
			if worm.state == Worm.State.SETTLING:
				worm.state = Worm.State.MOVING
		_apply_transform_to_worm(worm)


func _apply_transform_to_worm(worm: Worm) -> void:
	if _curve == null:
		return
	# Worms still in the start tunnel stay hidden until they roll onto the path.
	worm.visible = worm.path_distance >= 0.0
	var dist: float = clampf(worm.path_distance, 0.0, _path_length)
	var sample: Transform2D = _sample_path(dist)
	var pos: Vector2 = path.to_global(sample.origin)
	var tangent_global: Vector2 = path.global_transform.basis_xform(sample.x).normalized()
	worm.set_path_transform(pos, tangent_global)


func _sample_path(distance: float) -> Transform2D:
	return _curve.sample_baked_with_rotation(distance, false)


func _rebuild_curve_cache() -> void:
	if path == null or path.curve == null:
		_curve = null
		_path_length = 0.0
		return
	_curve = path.curve
	_path_length = _curve.get_baked_length()


func _reindex() -> void:
	for i: int in range(_worms.size()):
		_worms[i].chain_index = i
		_worms[i].owning_chain = self


func _check_end_condition() -> void:
	if _has_reached_end or _worms.is_empty():
		return
	if _worms[0].target_path_distance >= _path_length:
		_has_reached_end = true
		is_marching = false
		auto_spawn = false
		EventBus.chain_reached_end.emit(self)
