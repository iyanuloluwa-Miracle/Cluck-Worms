extends Node
## Flow controller: loads/unloads levels on EventBus requests and hosts UI.
## Does not own score, lives, or state — GameManager does.

@onready var _level_host: Node = $LevelHost


func _ready() -> void:
	EventBus.load_level_requested.connect(_on_load_level)
	EventBus.unload_level_requested.connect(_on_unload_level)
	# Ensure menu UI refreshes on boot.
	EventBus.game_state_changed.emit(
		int(GameManager.State.MAIN_MENU),
		int(GameManager.State.MAIN_MENU)
	)
	EventBus.high_score_changed.emit(SaveService.high_score, false)


func _on_load_level(level_def: LevelDef) -> void:
	_clear_level_host()
	var packed: PackedScene = load(level_def.scene_path) as PackedScene
	if packed == null:
		push_error("Main: failed to load level scene '%s'" % level_def.scene_path)
		GameManager.go_to_main_menu()
		return

	var level: Node = packed.instantiate()
	# Apply catalog fields BEFORE enter_tree/_ready so seeding uses them.
	if level is Level:
		var typed: Level = level as Level
		typed.level_id = level_def.id
		typed.initial_worm_count = level_def.initial_worm_count

	_level_host.add_child(level)

	if level is Level:
		(level as Level).apply_progression_tuning(level_def)


func _on_unload_level() -> void:
	_clear_level_host()


func _clear_level_host() -> void:
	for child: Node in _level_host.get_children():
		child.queue_free()
