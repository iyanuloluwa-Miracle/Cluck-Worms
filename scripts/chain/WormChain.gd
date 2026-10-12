class_name WormChain
extends Node2D
## Professional Zuma-style chain.
##
## Index 0 = leader (closest to path END). Last = rear (path START).
## Each worm has a logical [member Worm.target_path_distance] and a smoothed
## [member Worm.path_distance]. Inserts open a gap by shifting front targets;
## matches remove cleanly; the rear then magnetically surges forward; cascades
## re-check until stable.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MIN_MATCH_SIZE: int = 3

## Display → target easing while marching / settling.
const FOLLOW_RATE: float = 18.0

## Faster follow during magnetic collapse (rear surge).
const COLLAPSE_FOLLOW_RATE: float = 28.0

## Gap considered closed when adjacent error is below this (pixels).
const GAP_CLOSED_EPSILON: float = 1.25

## How long matched worms flash before leaving the chain visually.
const MATCH_FLASH_TIME: float = 0.12

## Brief pause after gap opens before match check (lets insert read).
const INSERT_SETTLE_TIME: float = 0.08

## Speed bonus applied to rear segment during magnetic pull (px/s).
const MAGNETIC_SURGE_SPEED: float = 420.0

const SPAWN_DISTANCE: float = 0.0

# ---------------------------------------------------------------------------
# Phase
# ---------------------------------------------------------------------------

enum Phase {
	MARCHING,
	INSERT_OPENING,
	MATCH_FLASH,
	COLLAPSING,
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

var _phase: Phase = Phase.MARCHING
var _phase_timer: float = 0.0
var _pool: WormPool

## True while a shot-triggered resolve sequence is running.
var _resolving_shot: bool = false
## Accumulates whether the current shot produced any match (incl. cascades).
var _shot_scored_match: bool = false
## Cascade depth for the active resolve (0 = first match group wave).
var _cascade_depth: int = 0

## During collapse: index of first rear worm after the gap (-1 if none).
var _collapse_rear_start: int = -1

## If a shot lands mid-resolve, re-evaluate once the current sequence ends.
var _pending_reevaluate: bool = false


func _ready() -> void:
	assert(worm_scene != null, "WormChain requires worm_scene.")
	_ensure_pool()
	if path != null:
		_rebuild_curve_cache()
	_spawn_timer = spawn_interval * 0.5


func _process(delta: float) -> void:
	# Allow in-flight resolve to finish even if overlays appear; block new march otherwise.
	if GameManager.is_paused:
		return
	if not GameManager.is_playing() and not _resolving_shot:
		return
	if _curve == null:
		if path != null:
			_rebuild_curve_cache()
		if _curve == null:
			return

	match _phase:
		Phase.MARCHING:
			_process_marching(delta)
		Phase.INSERT_OPENING:
			_process_insert_opening(delta)
		Phase.MATCH_FLASH:
			_process_match_flash(delta)
		Phase.COLLAPSING:
			_process_collapsing(delta)

	_sync_worm_transforms()
	_check_end_condition()


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


func is_busy() -> bool:
	return _phase != Phase.MARCHING or _resolving_shot


# ---------------------------------------------------------------------------
# Public API — mutation
# ---------------------------------------------------------------------------

func spawn_rear(color: WormColor.Kind = WormColor.Kind.RED) -> Worm:
	if stop_spawn_at_cap and _worms.size() >= max_worms:
		return null

	var distance: float = SPAWN_DISTANCE
	if not _worms.is_empty():
		distance = minf(get_rear().target_path_distance - worm_spacing, SPAWN_DISTANCE)

	var worm: Worm = _create_worm(color, distance, true)
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


## Level is won only when the chain is empty and no more worms will spawn.
func _try_emit_cleared() -> void:
	if not _worms.is_empty():
		return
	# Infinite sandbox (spawns_remaining < 0) still clears when empty.
	if spawns_remaining > 0:
		return
	EventBus.chain_cleared.emit(self)


## Structural insert with smooth gap-open (no full-chain snap).
func insert_worm(index: int, color: WormColor.Kind, animate_open: bool = true) -> Worm:
	index = clampi(index, 0, _worms.size())

	var new_distance: float = SPAWN_DISTANCE
	if _worms.is_empty():
		new_distance = SPAWN_DISTANCE
	elif index == 0:
		new_distance = _worms[0].target_path_distance + worm_spacing
	elif index >= _worms.size():
		new_distance = _worms[_worms.size() - 1].target_path_distance - worm_spacing
	else:
		# Open a one-slot gap: shift the front group (+end direction) by spacing.
		for i: int in range(index):
			var w: Worm = _worms[i]
			w.set_slot_distance(w.target_path_distance + worm_spacing, not animate_open)
			w.state = Worm.State.SETTLING
		# Seat the new worm in the opened slot (just ahead of the unmoved rear).
		new_distance = _worms[index].target_path_distance + worm_spacing

	var worm: Worm = _create_worm(color, new_distance, not animate_open)
	if worm == null:
		return null
	worm.state = Worm.State.SETTLING
	_worms.insert(index, worm)
	_reindex()
	_rebuild_targets_from_leader()

	# After rebuild, keep display positions for a smooth open unless snapped.
	if animate_open:
		# Front worms already had display behind new targets; rear untouched.
		# Ensure the new worm starts near its neighbors visually.
		if index + 1 < _worms.size():
			worm.path_distance = _worms[index + 1].path_distance + worm_spacing * 0.5
		elif index > 0:
			worm.path_distance = _worms[index - 1].path_distance - worm_spacing * 0.5

	EventBus.worm_spawned.emit(worm)
	EventBus.chain_worms_inserted.emit(self, index, 1)
	return worm


func remove_worms(index: int, count: int, reason: StringName = &"match") -> void:
	if count <= 0 or _worms.is_empty():
		return
	index = clampi(index, 0, _worms.size() - 1)
	count = mini(count, _worms.size() - index)

	var removed: Array[Worm] = []
	for i: int in range(count):
		removed.append(_worms[index + i])

	for worm: Worm in removed:
		_worms.erase(worm)
		worm.begin_match()
		EventBus.worm_removed.emit(worm, reason)

	_reindex()
	EventBus.chain_worms_removed.emit(self, index, count)

	# Stagger fall kickoffs without creating one timer coroutine per worm.
	_kickoff_falls(removed)

	if _worms.is_empty():
		_try_emit_cleared()


## Insert from a projectile hit, then run the full match/cascade sequence.
func insert_from_projectile(global_pos: Vector2, color: WormColor.Kind, hit_worm: Worm = null) -> Worm:
	var hit: Worm = hit_worm
	if hit == null or not is_instance_valid(hit) or not _worms.has(hit):
		var nearest: int = find_nearest_worm_index(global_pos)
		if nearest < 0:
			var spawned: Worm = spawn_rear(color)
			if _resolving_shot:
				_pending_reevaluate = true
			else:
				_begin_shot_resolve(false)
			return spawned
		hit = _worms[nearest]

	var index: int = get_insert_index_for_hit(hit, global_pos)
	var worm: Worm = insert_worm(index, color, true)
	if _resolving_shot:
		_pending_reevaluate = true
	else:
		_begin_shot_resolve(true)
	return worm

## Immediate match scan (debug / tools). Prefer shot resolve for gameplay.
func resolve_matches() -> bool:
	var groups: Array[Dictionary] = _find_all_matches()
	if groups.is_empty():
		return false
	_resolving_shot = true
	_shot_scored_match = false
	_cascade_depth = 0
	_apply_match_groups(groups, 0)
	return true


func clear_all(reason: StringName = &"reset") -> void:
	var snapshot: Array[Worm] = _worms.duplicate()
	_worms.clear()
	for worm: Worm in snapshot:
		EventBus.worm_removed.emit(worm, reason)
		worm.kill()
	_has_reached_end = false
	_spawn_timer = 0.0
	_phase = Phase.MARCHING
	_resolving_shot = false
	_shot_scored_match = false
	_cascade_depth = 0
	_collapse_rear_start = -1
	_pending_reevaluate = false


func rebuild_path_cache() -> void:
	_rebuild_curve_cache()


func find_nearest_worm_index(global_pos: Vector2) -> int:
	var best_index: int = -1
	var best_dist_sq: float = INF
	for i: int in range(_worms.size()):
		var worm: Worm = _worms[i]
		if not worm.is_active_in_chain():
			continue
		var dist_sq: float = worm.global_position.distance_squared_to(global_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index


func get_insert_index_for_hit(hit_worm: Worm, hit_global_pos: Vector2) -> int:
	var hit_index: int = hit_worm.chain_index
	if hit_index < 0:
		hit_index = _worms.find(hit_worm)
	if hit_index < 0:
		return 0

	var insert_before: bool = true
	if _curve != null:
		var sample: Transform2D = _sample_path(clampf(hit_worm.target_path_distance, 0.0, _path_length))
		var tangent: Vector2 = path.global_transform.basis_xform(sample.x).normalized()
		var to_impact: Vector2 = hit_global_pos - hit_worm.global_position
		insert_before = to_impact.dot(tangent) >= 0.0
	elif hit_index + 1 < _worms.size():
		var behind: Worm = _worms[hit_index + 1]
		insert_before = (
			hit_worm.global_position.distance_squared_to(hit_global_pos)
			<= behind.global_position.distance_squared_to(hit_global_pos)
		)

	return hit_index if insert_before else hit_index + 1


# ---------------------------------------------------------------------------
# Shot resolve state machine
# ---------------------------------------------------------------------------

func _begin_shot_resolve(wait_for_insert: bool) -> void:
	_resolving_shot = true
	_shot_scored_match = false
	_cascade_depth = 0
	if wait_for_insert:
		_phase = Phase.INSERT_OPENING
		_phase_timer = INSERT_SETTLE_TIME
	else:
		_evaluate_matches_or_finish()


func _process_insert_opening(delta: float) -> void:
	# Front still marches slowly so the train doesn't feel frozen.
	if is_marching:
		_advance_targets(delta * 0.35)
	_follow_targets(delta, FOLLOW_RATE)
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	# Snap any remaining micro-error at the insert site, then evaluate.
	_rebuild_targets_from_leader()
	_evaluate_matches_or_finish()


func _evaluate_matches_or_finish() -> void:
	var groups: Array[Dictionary] = _find_all_matches()
	if groups.is_empty():
		_finish_shot_resolve()
		return
	_apply_match_groups(groups, _cascade_depth)


func _apply_match_groups(groups: Array[Dictionary], cascade_depth: int) -> void:
	_shot_scored_match = true
	_cascade_depth = cascade_depth

	# Mark every matched index in one pass (supports multiple groups per wave).
	var matched: Array[bool] = []
	matched.resize(_worms.size())
	for i: int in range(matched.size()):
		matched[i] = false
	var gap_index: int = _worms.size()
	var total_removed: int = 0

	for group: Dictionary in groups:
		var start: int = int(group["start"])
		var count: int = int(group["count"])
		var color: WormColor.Kind = group["color"] as WormColor.Kind
		EventBus.chain_match_found.emit(self, start, count, color)
		EventBus.cascade_step.emit(self, cascade_depth, count, color)
		GameManager.register_match(count, color, cascade_depth)
		# Strong opening match → explicit good-shot juice.
		if cascade_depth == 0 and count >= 4:
			var mid: int = clampi(start + count / 2, 0, _worms.size() - 1)
			var shot_pos: Vector2 = _worms[mid].global_position if mid >= 0 else global_position
			EventBus.good_shot.emit(shot_pos, count)
		gap_index = mini(gap_index, start)
		total_removed += count
		for i: int in range(start, start + count):
			if i >= 0 and i < matched.size():
				matched[i] = true

	var kept: Array[Worm] = []
	var removed: Array[Worm] = []
	for i: int in range(_worms.size()):
		var worm: Worm = _worms[i]
		if matched[i]:
			removed.append(worm)
			worm.begin_match()
			EventBus.worm_removed.emit(worm, &"match")
		else:
			kept.append(worm)

	_worms = kept
	_reindex()
	EventBus.chain_worms_removed.emit(self, gap_index, total_removed)
	_kickoff_falls(removed)

	if _worms.is_empty():
		_try_emit_cleared()
		_finish_shot_resolve()
		return

	# Rear segment starts at the forward-most hole (worms behind have shifted left).
	_collapse_rear_start = gap_index
	if _collapse_rear_start >= _worms.size():
		_collapse_rear_start = -1

	_phase = Phase.MATCH_FLASH
	_phase_timer = MATCH_FLASH_TIME
	EventBus.chain_collapse_started.emit(self, total_removed)


func _process_match_flash(delta: float) -> void:
	# Hold front gently; don't close gaps yet so the pop reads.
	if is_marching:
		_advance_targets(delta * 0.2)
	_follow_targets(delta, FOLLOW_RATE * 0.5)
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return

	_rebuild_targets_from_leader()
	_phase = Phase.COLLAPSING
	# Mark rear worms as retracting for subtle state feedback.
	if _collapse_rear_start >= 0:
		for i: int in range(_collapse_rear_start, _worms.size()):
			if _worms[i].is_active_in_chain():
				_worms[i].state = Worm.State.RETRACTING


func _process_collapsing(delta: float) -> void:
	# Front continues a soft march; rear surges toward rebuilt targets.
	if is_marching:
		_advance_targets(delta * 0.25)

	# Magnetic surge: pull rear display distances toward targets quickly.
	if _collapse_rear_start >= 0 and _collapse_rear_start < _worms.size():
		for i: int in range(_collapse_rear_start, _worms.size()):
			var worm: Worm = _worms[i]
			var err: float = worm.target_path_distance - worm.path_distance
			if err > 0.0:
				worm.path_distance += minf(err, MAGNETIC_SURGE_SPEED * delta)

	_follow_targets(delta, COLLAPSE_FOLLOW_RATE)

	if _is_gap_closed():
		# Join complete — clear retracting states.
		for worm: Worm in _worms:
			if worm.state == Worm.State.RETRACTING or worm.state == Worm.State.SETTLING:
				worm.state = Worm.State.MOVING
		_collapse_rear_start = -1
		EventBus.chain_collapse_finished.emit(self)
		# Cascade check.
		_cascade_depth += 1
		_evaluate_matches_or_finish()


func _finish_shot_resolve() -> void:
	_phase = Phase.MARCHING
	_resolving_shot = false
	_collapse_rear_start = -1
	for worm: Worm in _worms:
		if worm.state == Worm.State.SETTLING or worm.state == Worm.State.RETRACTING:
			worm.state = Worm.State.MOVING
	_rebuild_targets_from_leader()

	var scored: bool = _shot_scored_match
	GameManager.notify_shot_resolved(scored)
	EventBus.shot_resolve_finished.emit(self, scored)
	_shot_scored_match = false
	_cascade_depth = 0

	if _pending_reevaluate:
		_pending_reevaluate = false
		_begin_shot_resolve(false)


func _is_gap_closed() -> bool:
	if _worms.size() < 2:
		return true
	# Entire chain within epsilon of ideal spacing from leader.
	var anchor: float = _worms[0].target_path_distance
	for i: int in range(_worms.size()):
		var ideal: float = anchor - float(i) * worm_spacing
		if absf(_worms[i].path_distance - ideal) > GAP_CLOSED_EPSILON:
			return false
		if absf(_worms[i].target_path_distance - ideal) > GAP_CLOSED_EPSILON:
			return false
	return true


# ---------------------------------------------------------------------------
# Marching
# ---------------------------------------------------------------------------

func _process_marching(delta: float) -> void:
	if auto_spawn and not _has_reached_end and not _resolving_shot:
		_process_auto_spawn(delta)
	if is_marching and not _worms.is_empty():
		_advance_targets(delta)
	_follow_targets(delta, FOLLOW_RATE)


func _advance_targets(delta: float) -> void:
	var step: float = march_speed * delta
	for worm: Worm in _worms:
		if worm.is_active_in_chain():
			worm.target_path_distance += step


func _follow_targets(delta: float, rate: float) -> void:
	var t: float = 1.0 - exp(-rate * delta)
	for worm: Worm in _worms:
		if not worm.is_active_in_chain():
			continue
		worm.path_distance = lerpf(worm.path_distance, worm.target_path_distance, t)
		if absf(worm.path_distance - worm.target_path_distance) <= 0.2:
			worm.path_distance = worm.target_path_distance
			if worm.state == Worm.State.SETTLING and _phase == Phase.MARCHING:
				worm.state = Worm.State.MOVING


func _rebuild_targets_from_leader() -> void:
	if _worms.is_empty():
		return
	var anchor: float = _worms[0].target_path_distance
	# Prefer displayed leader if it's ahead (keeps collapse from yanking forward).
	anchor = maxf(anchor, _worms[0].path_distance)
	_worms[0].set_slot_distance(anchor, false)
	for i: int in range(1, _worms.size()):
		_worms[i].set_slot_distance(anchor - float(i) * worm_spacing, false)


# ---------------------------------------------------------------------------
# Match finding — all groups in one pass
# ---------------------------------------------------------------------------

func _find_all_matches() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if _worms.size() < MIN_MATCH_SIZE:
		return results

	var run_start: int = 0
	var run_color: WormColor.Kind = _worms[0].worm_color
	var run_count: int = 1

	for i: int in range(1, _worms.size()):
		if _worms[i].worm_color == run_color:
			run_count += 1
		else:
			if run_count >= MIN_MATCH_SIZE:
				results.append({"start": run_start, "count": run_count, "color": run_color})
			run_start = i
			run_color = _worms[i].worm_color
			run_count = 1

	if run_count >= MIN_MATCH_SIZE:
		results.append({"start": run_start, "count": run_count, "color": run_color})
	return results


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
	if not _worms.is_empty():
		var rear: Worm = get_rear()
		if rear.target_path_distance < worm_spacing * 0.85:
			return
	_spawn_timer = 0.0
	var worm: Worm = spawn_rear(GameManager.roll_worm_color())
	if worm != null and spawns_remaining > 0:
		spawns_remaining -= 1
		if spawns_remaining == 0:
			auto_spawn = false


func _create_worm(color: WormColor.Kind, distance: float, snap: bool) -> Worm:
	var worm: Worm = _pool.acquire() if _pool != null else null
	if worm == null:
		# Fallback instantiate if pool exhausted.
		worm = worm_scene.instantiate() as Worm
		add_child(worm)
	else:
		# Reparent from pool to chain for correct transforms.
		if worm.get_parent() != self:
			worm.reparent(self, false)
	worm.pool = _pool
	worm.setup(color, distance)
	worm.set_slot_distance(distance, snap)
	worm.owning_chain = self
	_apply_transform_to_worm(worm)
	return worm


func _kickoff_falls(removed: Array[Worm]) -> void:
	# Single await serves the whole batch — no per-worm coroutine stutter.
	var tree := get_tree()
	if tree == null:
		for worm: Worm in removed:
			if is_instance_valid(worm):
				worm.begin_fall()
		return
	await tree.create_timer(MATCH_FLASH_TIME).timeout
	for worm: Worm in removed:
		if is_instance_valid(worm) and worm.state == Worm.State.MATCHED:
			worm.begin_fall()


# ---------------------------------------------------------------------------
# Transforms / path
# ---------------------------------------------------------------------------

func _sync_worm_transforms() -> void:
	for worm: Worm in _worms:
		_apply_transform_to_worm(worm)


func _apply_transform_to_worm(worm: Worm) -> void:
	if _curve == null:
		return
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
	# Only lose while marching — not mid-cascade.
	if _phase != Phase.MARCHING:
		return
	var leader: Worm = get_leader()
	if leader.path_distance >= _path_length:
		_has_reached_end = true
		is_marching = false
		auto_spawn = false
		EventBus.chain_reached_end.emit(self)
