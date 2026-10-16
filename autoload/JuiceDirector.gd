extends Node
## Global game-feel director: shake, hit-stop, camera, particles, shot feedback.
## Scales automatically via QualitySettings for web / mobile browsers.

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

@export var max_shake_offset: float = 12.0
@export var shake_decay: float = 1.9
@export var camera_follow_rate: float = 3.0
## Kept subtle: a strong pull moves the aim reference and hurts accuracy.
@export var camera_action_pull: float = 0.08
@export var hit_stop_scale: float = 0.07

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _trauma: float = 0.0
var _camera: Camera2D
var _camera_home: Vector2 = Vector2(640, 360)
var _look_target: Vector2 = Vector2(640, 360)
# Kept in sync with PathFactory.CHICKEN_NEST for action pull defaults.
var _hit_stopping: bool = false
var _fx_host: Node2D
var _last_feedback_pos: Vector2 = Vector2(640, 300)
## Recently spawned float texts [{"p": Vector2, "t": float}] used to avoid overlap.
var _recent_texts: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.cascade_step.connect(_on_cascade)
	EventBus.chain_collapse_started.connect(_on_collapse)
	EventBus.chain_reversing.connect(_on_reversing)
	EventBus.boss_damaged.connect(_on_boss_damaged)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.projectile_hit_chain.connect(_on_projectile_hit)
	EventBus.chicken_shot.connect(_on_shot)
	EventBus.shot_resolve_finished.connect(_on_shot_resolved)
	EventBus.level_started.connect(_on_level_started)
	EventBus.load_level_requested.connect(_on_level_load)
	EventBus.unload_level_requested.connect(_on_unload)
	EventBus.good_shot.connect(_on_good_shot)
	EventBus.near_miss.connect(_on_near_miss)
	EventBus.worm_removed.connect(_on_worm_removed)


func _process(delta: float) -> void:
	var dt: float = delta if Engine.time_scale > 0.5 else delta / maxf(Engine.time_scale, 0.001)
	_trauma = maxf(_trauma - shake_decay * dt * (0.35 if _hit_stopping else 1.0), 0.0)
	_update_camera(delta)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func add_trauma(amount: float) -> void:
	if not QualitySettings.enable_camera_shake or SaveService.reduced_shake:
		return
	_trauma = clampf(_trauma + amount * QualitySettings.particle_scale, 0.0, 1.0)


func shake_for_combo(combo: int, match_count: int) -> void:
	var amount: float = 0.12 + float(match_count) * 0.04 + float(maxi(combo - 1, 0)) * 0.05
	add_trauma(minf(amount, 0.95))


func hit_stop(duration: float = 0.055) -> void:
	if not QualitySettings.enable_hit_stop or _hit_stopping:
		return
	_hit_stopping = true
	var prev_scale: float = Engine.time_scale
	Engine.time_scale = hit_stop_scale
	await get_tree().create_timer(duration, true, true, true).timeout
	Engine.time_scale = prev_scale if prev_scale > 0.01 else 1.0
	_hit_stopping = false


func pull_camera_toward(world_pos: Vector2, weight: float = 1.0) -> void:
	_look_target = _look_target.lerp(world_pos, clampf(weight * camera_action_pull, 0.0, 1.0))


func spawn_pop(world_pos: Vector2, color: Color, intensity: float = 1.0) -> void:
	if SaveService.reduced_fx:
		intensity *= 0.45
	var host := _get_fx_host()
	if host == null:
		return
	_trim_fx(host)
	var burst := PopBurst.new()
	host.add_child(burst)
	burst.global_position = world_pos
	burst.setup(color, intensity * QualitySettings.particle_scale)


func spawn_float_text(world_pos: Vector2, text: String, color: Color) -> void:
	var host := _get_fx_host()
	if host == null:
		return
	_trim_fx(host)
	var now: float = Time.get_ticks_msec() / 1000.0
	var pos: Vector2 = world_pos
	for i: int in range(_recent_texts.size() - 1, -1, -1):
		var rec: Dictionary = _recent_texts[i]
		if now - float(rec["t"]) > 0.6:
			_recent_texts.remove_at(i)
	var bumped: bool = true
	var guard: int = 0
	while bumped and guard < 6:
		bumped = false
		for rec: Dictionary in _recent_texts:
			var other: Vector2 = rec["p"]
			if absf(other.x - pos.x) < 110.0 and absf(other.y - pos.y) < 24.0:
				pos.y = other.y - 26.0
				bumped = true
		guard += 1
	_recent_texts.append({"p": pos, "t": now})
	var ft := FloatText.new()
	host.add_child(ft)
	ft.global_position = pos
	ft.setup(text, color)


func bind_camera(camera: Camera2D) -> void:
	_camera = camera
	if _camera:
		_camera_home = _camera.global_position
		_look_target = _camera_home
		_camera.make_current()


func clear_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
	_camera = null
	_fx_host = null
	_trauma = 0.0


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_look_target = _look_target.lerp(_camera_home, 1.0 - exp(-1.8 * delta))
	var desired: Vector2 = _camera_home.lerp(_look_target, 0.35)
	_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-camera_follow_rate * delta))
	_camera.offset = _shake_offset()


func _shake_offset() -> Vector2:
	if not QualitySettings.enable_camera_shake or _trauma <= 0.001:
		return Vector2.ZERO
	var shake_power: float = _trauma * _trauma
	var rng := GameManager.get_rng()
	var cap: float = max_shake_offset * (0.65 if QualitySettings.is_low() else 1.0)
	return Vector2(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	) * cap * shake_power


func _get_fx_host() -> Node2D:
	if _fx_host != null and is_instance_valid(_fx_host):
		return _fx_host
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var level := tree.current_scene.find_child("LevelHost", true, false)
	if level and level.get_child_count() > 0:
		var play_level: Node = level.get_child(0)
		var fx: Node = play_level.get_node_or_null("FX")
		if fx is Node2D:
			_fx_host = fx as Node2D
			return _fx_host
		var created := Node2D.new()
		created.name = "FX"
		play_level.add_child(created)
		_fx_host = created
		return _fx_host
	return null


func _trim_fx(host: Node2D) -> void:
	var limit: int = QualitySettings.max_live_fx
	while host.get_child_count() >= limit:
		var oldest: Node = host.get_child(0)
		host.remove_child(oldest)
		oldest.free()


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_level_load(_data: LevelData) -> void:
	_fx_host = null
	_trauma = 0.0


func _on_level_started(_id: StringName, _name: String) -> void:
	_trauma = 0.0
	call_deferred("_try_auto_bind_camera")


func _try_auto_bind_camera() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var cam: Camera2D = tree.root.find_child("LevelCamera", true, false) as Camera2D
	if cam:
		bind_camera(cam)


func _on_unload() -> void:
	clear_camera()


func _on_cascade(chain: WormChain, depth: int, count: int, color: WormColor.Kind) -> void:
	var pos := chain.last_match_position if chain.last_match_position != Vector2.ZERO else _approx_chain_center(chain)
	_last_feedback_pos = pos
	var fill: Color = WormColor.get_fill(color)
	var intensity: float = 0.9 + float(count) * 0.1 + float(depth) * 0.2
	spawn_pop(pos, fill, intensity)
	shake_for_combo(GameManager.combo, count + depth)
	pull_camera_toward(pos, 1.0 + float(count) * 0.12 + float(depth) * 0.2)
	EventBus.chicken_react.emit(&"celebrate" if depth > 0 or count >= 4 else &"peck", pos)

	if depth >= 1:
		hit_stop(0.055 + float(depth) * 0.015)
		spawn_float_text(pos + Vector2(0, -28), "CASCADE x%d" % (depth + 1), Color(1.0, 0.75, 0.2))
	elif count >= 4:
		hit_stop(0.05)
	elif count >= WormChain.MIN_MATCH_SIZE:
		hit_stop(0.035)
		if QualitySettings.enable_small_float_text:
			spawn_float_text(pos + Vector2(0, -16), "POP!", fill.lightened(0.25))


func _on_collapse(_chain: WormChain, removed: int) -> void:
	add_trauma(0.08 + float(removed) * 0.01)


func _on_reversing(chain: WormChain) -> void:
	var pos := chain.last_reverse_position if chain.last_reverse_position != Vector2.ZERO else _approx_chain_center(chain)
	add_trauma(0.06)
	if QualitySettings.enable_small_float_text:
		spawn_float_text(pos + Vector2(0, -20), "REVERSE!", Color(0.55, 0.9, 1.0))


func _on_boss_damaged(_id: StringName, amount: float, world_pos: Vector2) -> void:
	spawn_pop(world_pos, Color(1.0, 0.45, 0.2), 0.85 + amount * 0.05)
	add_trauma(0.18)
	hit_stop(0.04)
	pull_camera_toward(world_pos, 1.1)


func _on_boss_defeated(_id: StringName) -> void:
	add_trauma(0.55)
	hit_stop(0.1)


func _on_projectile_hit(projectile: ShootingWorm, hit: Worm, _chain: WormChain) -> void:
	var pos: Vector2 = hit.global_position if is_instance_valid(hit) else projectile.global_position
	spawn_pop(pos, WormColor.get_fill(projectile.worm_color), 0.7)


func _on_shot(_color: WormColor.Kind, _origin: Vector2, _dir: Vector2) -> void:
	pass


func _on_shot_resolved(_chain: WormChain, scored: bool) -> void:
	if scored and GameManager.combo >= 2:
		spawn_float_text(_last_feedback_pos + Vector2(0, -56), "COMBO x%d" % GameManager.combo, Color(1.0, 0.85, 0.3))


func _on_good_shot(world_pos: Vector2, match_count: int) -> void:
	var label: String = "GREAT!" if match_count < 6 else "AMAZING!"
	spawn_float_text(world_pos + Vector2(0, -24), label, Color(0.55, 1.0, 0.55))
	add_trauma(0.15 + float(match_count) * 0.02)
	pull_camera_toward(world_pos, 1.2)
	EventBus.chicken_react.emit(&"celebrate", world_pos)


func _on_near_miss(world_pos: Vector2) -> void:
	if QualitySettings.enable_small_float_text:
		spawn_float_text(world_pos + Vector2(0, -10), "close…", Color(1.0, 1.0, 1.0, 0.85))
	add_trauma(0.03)
	EventBus.chicken_react.emit(&"sigh", world_pos)


func _on_worm_removed(worm: Worm, reason: StringName) -> void:
	if reason != &"match" or not is_instance_valid(worm):
		return
	if not QualitySettings.enable_per_worm_pop:
		return
	spawn_pop(worm.global_position, WormColor.get_fill(worm.worm_color), 0.55)


func _approx_chain_center(chain: WormChain) -> Vector2:
	var worms: Array[Worm] = chain.get_worms()
	if worms.is_empty():
		return _look_target
	var mid: int = worms.size() / 2
	return worms[mid].global_position
