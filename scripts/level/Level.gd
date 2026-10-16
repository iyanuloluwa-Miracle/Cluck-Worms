class_name Level
extends Node2D
## Playable level instance. Configured entirely from [LevelData] before play.

@export var level_id: StringName = &"level_01"
@export var path_node: Path2D
@export var chain_node: WormChain
@export var chicken_node: Chicken
@export var initial_worm_count: int = 8
@export var show_path_guide: bool = true

var _level_data: LevelData = null
var _configured: bool = false

@onready var _path_draw: Node2D = $PathGuide
@onready var _projectiles: Node2D = $Projectiles
@onready var _bg_rect: ColorRect = $Background/ColorRect
@onready var _fx: Node2D = $FX
@onready var _camera: Camera2D = $LevelCamera

var _boss: BossController = null


func _ready() -> void:
	if path_node == null:
		path_node = $WormPath as Path2D
	if chain_node == null:
		chain_node = $WormChain as WormChain
	if chicken_node == null:
		chicken_node = $Chicken as Chicken

	# If Main already called apply_level_data before add_child, path/tuning exist.
	if not _configured and _level_data != null:
		_apply_data_internal(_level_data)

	chain_node.path = path_node
	chain_node.rebuild_path_cache()

	chicken_node.chain_path = chicken_node.get_path_to(chain_node)
	chicken_node.projectile_container_path = chicken_node.get_path_to(_projectiles)
	chicken_node.resolve_level_bindings()

	var was_auto: bool = chain_node.auto_spawn
	chain_node.auto_spawn = false
	chain_node.is_marching = false
	_seed_initial_chain()
	if _level_data != null:
		if GameManager.challenge_mode == &"practice":
			chain_node.spawns_remaining = -1
			chain_node.auto_spawn = true
		else:
			chain_node.configure_spawn_budget(_level_data.get_remaining_spawns_after_initial())
			chain_node.auto_spawn = _level_data.auto_spawn and chain_node.spawns_remaining != 0
	else:
		chain_node.auto_spawn = was_auto
	chain_node.is_marching = true

	EventBus.chain_reached_end.connect(_on_reached_end)
	EventBus.chain_cleared.connect(_on_cleared)
	EventBus.game_state_changed.connect(_on_game_state)

	if show_path_guide and _path_draw:
		_path_draw.queue_redraw()

	chicken_node.set_shooting_enabled(GameManager.can_player_act())
	JuiceDirector.bind_camera(_camera)
	# Keep FX host warm so first pop isn't delayed.
	if _fx:
		_fx.z_index = 20
	_spawn_boss_if_needed()


## Preferred entry: call on the instance BEFORE add_child so _ready seeds correctly.
func apply_level_data(data: LevelData) -> void:
	_level_data = data
	_apply_data_internal(data)
	_configured = true


## Back-compat name used by Main.
func apply_progression_tuning(level_def: LevelData) -> void:
	apply_level_data(level_def)
	# If already in tree, refresh curve cache + guide after late apply.
	if is_inside_tree() and path_node and chain_node:
		chain_node.path = path_node
		chain_node.rebuild_path_cache()
		if _path_draw:
			if _path_draw.has_method("queue_redraw"):
				_path_draw.queue_redraw()


func _apply_data_internal(data: LevelData) -> void:
	if data == null:
		return
	level_id = data.id
	initial_worm_count = data.initial_worm_count

	if path_node == null:
		path_node = get_node_or_null("WormPath") as Path2D
	if chain_node == null:
		chain_node = get_node_or_null("WormChain") as WormChain
	if chicken_node == null:
		chicken_node = get_node_or_null("Chicken") as Chicken

	if path_node:
		path_node.curve = data.build_curve()

	if chain_node:
		chain_node.march_speed = data.march_speed * data.speed_multiplier
		chain_node.spawn_interval = data.spawn_interval
		chain_node.auto_spawn = data.auto_spawn
		chain_node.worm_spacing = data.worm_spacing

	if chicken_node:
		chicken_node.position = data.chicken_position

	var bg: ColorRect = get_node_or_null("Background/ColorRect") as ColorRect
	var backdrop_host: Node = get_node_or_null("Background")
	if backdrop_host:
		var backdrop := backdrop_host.get_node_or_null("StageBackdrop") as StageBackdrop
		if backdrop == null:
			backdrop = StageBackdrop.new()
			backdrop.name = "StageBackdrop"
			backdrop_host.add_child(backdrop)
			backdrop_host.move_child(backdrop, 1)
		backdrop.configure(data.level_number, data.is_boss_level)
		var overlay: CanvasItem = backdrop_host.get_node_or_null("GradientOverlay") as CanvasItem
		if overlay:
			overlay.visible = false
		if bg:
			bg.color = backdrop.base_color()
	elif bg:
		bg.color = data.background_color

	var guide: Node = get_node_or_null("PathGuide")
	if guide and "danger_zone_length" in guide:
		guide.set("danger_zone_length", data.danger_zone_length)
		guide.set("path", path_node)
		if "sample_step" in guide:
			guide.set("sample_step", QualitySettings.path_sample_step)


func _seed_initial_chain() -> void:
	for i: int in range(initial_worm_count):
		chain_node.spawn_rear(GameManager.roll_worm_color())
	if chain_node.get_worm_count() == 0:
		return
	# Zuma roll-in: the train rushes out of the tunnel, capped at 35% of the path.
	var lead_offset: float = float(initial_worm_count) * chain_node.worm_spacing
	var path_len: float = chain_node.get_path_length()
	if path_len > 0.0:
		lead_offset = minf(lead_offset, path_len * 0.35)
	chain_node.begin_intro_roll(lead_offset)


func _on_reached_end(_chain: WormChain) -> void:
	if chicken_node:
		chicken_node.set_shooting_enabled(false)


func _on_cleared(_chain: WormChain) -> void:
	# On boss stages, a premature chain clear must not soft-lock — keep pressure up.
	if _level_data != null and _level_data.is_boss_level:
		if _boss == null or not _boss.is_defeated:
			chain_node.spawns_remaining = maxi(chain_node.spawns_remaining, 12)
			chain_node.auto_spawn = true
			chain_node.is_marching = true
			if chicken_node:
				chicken_node.set_shooting_enabled(GameManager.can_player_act())
			return
	if chicken_node:
		chicken_node.set_shooting_enabled(false)


func _spawn_boss_if_needed() -> void:
	if _level_data == null or not _level_data.is_boss_level or _level_data.boss == null:
		return
	if _boss != null and is_instance_valid(_boss):
		_boss.queue_free()
	_boss = BossController.new()
	_boss.name = "BossController"
	add_child(_boss)
	_boss.setup(_level_data.boss, chain_node)


func _on_game_state(_prev: int, next: int) -> void:
	var playing: bool = next == GameManager.State.PLAYING
	if chicken_node:
		chicken_node.set_shooting_enabled(playing)
	if chain_node and not chain_node.is_busy():
		chain_node.is_marching = playing
