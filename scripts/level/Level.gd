class_name Level
extends Node2D
## Playable level instance. Owns path, chain, and chicken.
## Progression / score / lives are owned by GameManager via EventBus.

@export var level_id: StringName = &"level_01"
@export var path_node: Path2D
@export var chain_node: WormChain
@export var chicken_node: Chicken
@export var initial_worm_count: int = 8
@export var show_path_guide: bool = true

@onready var _path_draw: Node2D = $PathGuide
@onready var _projectiles: Node2D = $Projectiles


func _ready() -> void:
	if path_node == null:
		path_node = $WormPath as Path2D
	if chain_node == null:
		chain_node = $WormChain as WormChain
	if chicken_node == null:
		chicken_node = $Chicken as Chicken

	chain_node.path = path_node
	chain_node.rebuild_path_cache()

	chicken_node.chain_path = chicken_node.get_path_to(chain_node)
	chicken_node.projectile_container_path = chicken_node.get_path_to(_projectiles)
	chicken_node.resolve_level_bindings()

	var was_auto: bool = chain_node.auto_spawn
	chain_node.auto_spawn = false
	chain_node.is_marching = false
	_seed_initial_chain()
	chain_node.is_marching = true
	chain_node.auto_spawn = was_auto

	EventBus.chain_reached_end.connect(_on_reached_end)
	EventBus.chain_cleared.connect(_on_cleared)
	EventBus.game_state_changed.connect(_on_game_state)

	if show_path_guide and _path_draw:
		_path_draw.queue_redraw()

	chicken_node.set_shooting_enabled(GameManager.can_player_act())


## Called by Main after instantiate so catalog tunables apply.
func apply_progression_tuning(level_def: LevelDef) -> void:
	if chain_node == null:
		chain_node = $WormChain as WormChain
	if chain_node == null or level_def == null:
		return
	chain_node.march_speed = level_def.march_speed
	chain_node.spawn_interval = level_def.spawn_interval
	chain_node.auto_spawn = level_def.auto_spawn
	chain_node.worm_spacing = level_def.worm_spacing


func _seed_initial_chain() -> void:
	for i: int in range(initial_worm_count):
		chain_node.spawn_rear(GameManager.roll_worm_color())
	var worms: Array[Worm] = chain_node.get_worms()
	if worms.is_empty():
		return
	var lead_offset: float = float(initial_worm_count) * chain_node.worm_spacing
	for worm: Worm in worms:
		worm.path_distance += lead_offset
		worm.target_path_distance += lead_offset


func _on_reached_end(_chain: WormChain) -> void:
	if chicken_node:
		chicken_node.set_shooting_enabled(false)


func _on_cleared(_chain: WormChain) -> void:
	if chicken_node:
		chicken_node.set_shooting_enabled(false)


func _on_game_state(_prev: int, next: int) -> void:
	var playing: bool = next == GameManager.State.PLAYING
	if chicken_node:
		chicken_node.set_shooting_enabled(playing)
	if chain_node and not chain_node.is_busy():
		chain_node.is_marching = playing
