extends Control
## Lifetime stats + achievement checklist. Driven by real SaveService data.


signal closed

@onready var _title: Label = $Safe/Panel/VBox/Title
@onready var _stats_box: VBoxContainer = $Safe/Panel/VBox/Scroll/Inner/Stats
@onready var _ach_box: VBoxContainer = $Safe/Panel/VBox/Scroll/Inner/Achievements
@onready var _back: Button = $Safe/Panel/VBox/Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if _back:
		_back.pressed.connect(_on_back)
		UITheme.apply_ghost_button(_back)
		_back.text = "← Back"
	if _title:
		_title.text = "Stats & Achievements"
		UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
		_title.add_theme_font_size_override("font_size", 36)
		_title.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	EventBus.stats_changed.connect(_refresh)
	EventBus.achievement_unlocked.connect(func(_id: StringName) -> void: _refresh())


func open_stats() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.22)


func _on_back() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	if _stats_box == null or _ach_box == null:
		return
	for c: Node in _stats_box.get_children():
		c.queue_free()
	for c: Node in _ach_box.get_children():
		c.queue_free()
	var s: Dictionary = SaveService.get_stats_summary()
	var mins: int = int(float(s.get("play_time_seconds", 0.0)) / 60.0)
	_add_stat("High score", str(s.get("high_score", 0)))
	_add_stat("Best combo", str(s.get("best_combo", 0)))
	_add_stat("Levels cleared", str(s.get("levels_completed", 0)))
	_add_stat("Bosses defeated", str(s.get("bosses_defeated", 0)))
	_add_stat("Total matches", str(s.get("total_matches", 0)))
	_add_stat("Largest match", str(s.get("largest_match", 0)))
	_add_stat("Shots fired", str(s.get("total_shots", 0)))
	_add_stat("Play time", "%dm" % mins)
	_add_stat("Stages cleared", str(s.get("stages_cleared", 0)))

	var head := Label.new()
	head.text = "Achievements"
	UITheme.apply_font(head, UITheme.WEIGHT_BOLD)
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", UITheme.YOLK)
	_ach_box.add_child(head)
	for id: StringName in AchievementCatalog.all_ids():
		var unlocked: bool = SaveService.has_achievement(id)
		var row := Label.new()
		row.text = "%s  %s — %s" % [
			"★" if unlocked else "☆",
			AchievementCatalog.title(id),
			AchievementCatalog.description(id),
		]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_color_override(
			"font_color",
			Color(1, 0.95, 0.7) if unlocked else Color(0.75, 0.78, 0.72, 0.65)
		)
		_ach_box.add_child(row)


func _add_stat(label: String, value: String) -> void:
	var row := Label.new()
	row.text = "%s: %s" % [label, value]
	UITheme.apply_font(row, UITheme.WEIGHT_SEMIBOLD)
	row.add_theme_font_size_override("font_size", 16)
	row.add_theme_color_override("font_color", UITheme.CREAM)
	_stats_box.add_child(row)
