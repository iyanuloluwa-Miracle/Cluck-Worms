extends Control
## Campaign map — stages and levels with lock / stars / best score.

signal closed

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Safe/VBox/Title
@onready var _stage_tabs: HBoxContainer = $Safe/VBox/StageTabs
@onready var _grid: GridContainer = $Safe/VBox/Scroll/Grid
@onready var _back: Button = $Safe/VBox/BackButton

var _stage_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_backdrop.color = Color(0.05, 0.12, 0.08, 0.94)
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.text = "Campaign"
	UITheme.apply_ghost_button(_back)
	_back.text = "Back"
	_back.pressed.connect(func() -> void:
		visible = false
		closed.emit()
	)
	_rebuild_stage_tabs()
	_rebuild_grid()


func open_select() -> void:
	visible = true
	_rebuild_stage_tabs()
	_rebuild_grid()
	modulate.a = 0.0
	UIFx.fade_in(self, 0.2)


func _rebuild_stage_tabs() -> void:
	for c: Node in _stage_tabs.get_children():
		c.queue_free()
	if GameManager.catalog == null:
		return
	for i: int in range(GameManager.catalog.get_stage_count()):
		var stage: StageDef = GameManager.catalog.get_stage(i)
		var btn := Button.new()
		btn.text = stage.display_name if stage else "Stage %d" % (i + 1)
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == _stage_index:
			UITheme.apply_primary_button(btn)
		else:
			UITheme.apply_ghost_button(btn)
		var idx: int = i
		btn.pressed.connect(func() -> void:
			_stage_index = idx
			_rebuild_stage_tabs()
			_rebuild_grid()
		)
		_stage_tabs.add_child(btn)


func _rebuild_grid() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	if GameManager.catalog == null:
		return
	var stage: StageDef = GameManager.catalog.get_stage(_stage_index)
	if stage == null:
		return
	for i: int in range(stage.get_level_count()):
		var level: LevelData = stage.get_level(i)
		var unlocked: bool = SaveService.is_level_unlocked(level.level_number)
		var stars: int = SaveService.get_level_stars(level.id)
		var best: int = SaveService.get_level_best_score(level.id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 96)
		var star_txt: String = "★".repeat(stars) + "☆".repeat(maxi(3 - stars, 0))
		if unlocked:
			btn.text = "L%d\n%s\n%s\n%d" % [level.level_number, level.display_name, star_txt, best]
			UITheme.apply_primary_button(btn) if stars > 0 else UITheme.apply_ghost_button(btn)
			var s_idx: int = _stage_index
			var l_idx: int = i
			btn.pressed.connect(func() -> void:
				visible = false
				GameManager.start_run(s_idx, l_idx)
			)
		else:
			btn.text = "L%d\n🔒 Locked" % level.level_number
			btn.disabled = true
			UITheme.apply_ghost_button(btn)
		_grid.add_child(btn)
