extends Control
## Premium campaign map — opaque overlay, large level tiles, stage tabs.

signal closed

const STAGE_SHORT: Array[String] = [
	"Backyard",
	"Wild Garden",
	"Forbidden Coop",
]

@onready var _title: Label = $Safe/VBox/Header/Title
@onready var _subtitle: Label = $Safe/VBox/Header/Subtitle
@onready var _stage_tabs: HBoxContainer = $Safe/VBox/StageTabs
@onready var _stage_hint: Label = $Safe/VBox/StageHint
@onready var _grid: GridContainer = $Safe/VBox/CenterWrap/Scroll/Grid
@onready var _scroll: ScrollContainer = $Safe/VBox/CenterWrap/Scroll
@onready var _back: Button = $Safe/VBox/Footer/BackButton
@onready var _panel_root: Control = $Safe/VBox

var _stage_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 20
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style_chrome()
	_back.pressed.connect(_on_back)
	_rebuild_stage_tabs()
	_rebuild_grid()


func open_select() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild_stage_tabs()
	_rebuild_grid()
	_panel_root.modulate.a = 0.0
	_panel_root.scale = Vector2(0.96, 0.96)
	_panel_root.pivot_offset = _panel_root.size * 0.5
	modulate.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel_root, "modulate:a", 1.0, 0.28)
	tween.tween_property(_panel_root, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK)


func _style_chrome() -> void:
	_title.text = "Campaign"
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_title.add_theme_color_override("font_outline_color", Color(0.06, 0.14, 0.08, 0.95))
	_title.add_theme_constant_override("outline_size", 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_subtitle.text = "Clear levels to unlock the path ahead"
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9, 0.85))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.05, 0.7))
	_subtitle.add_theme_constant_override("outline_size", 3)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_stage_hint.add_theme_font_size_override("font_size", 18)
	_stage_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 0.95))
	_stage_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.05, 0.65))
	_stage_hint.add_theme_constant_override("outline_size", 3)
	_stage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_ghost_button(_back)
	_back.text = "←  Back"
	_back.custom_minimum_size = Vector2(220, 52)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_back() -> void:
	UIFx.punch_button(_back)
	visible = false
	closed.emit()


func _rebuild_stage_tabs() -> void:
	for c: Node in _stage_tabs.get_children():
		c.queue_free()
	if GameManager.catalog == null:
		return
	for i: int in range(GameManager.catalog.get_stage_count()):
		var stage: StageDef = GameManager.catalog.get_stage(i)
		var btn := Button.new()
		var short: String = STAGE_SHORT[i] if i < STAGE_SHORT.size() else "Stage %d" % (i + 1)
		btn.text = short
		btn.tooltip_text = stage.display_name if stage else short
		btn.custom_minimum_size = Vector2(150, 50)
		if i == _stage_index:
			_style_tab_active(btn)
		else:
			_style_tab_idle(btn)
		var idx: int = i
		btn.pressed.connect(func() -> void:
			_stage_index = idx
			_rebuild_stage_tabs()
			_rebuild_grid()
		)
		_stage_tabs.add_child(btn)

	var st: StageDef = GameManager.catalog.get_stage(_stage_index)
	_stage_hint.text = st.display_name if st else "Stage"


func _style_tab_active(btn: Button) -> void:
	var s := UITheme.button_normal()
	s.set_corner_radius_all(18)
	s.shadow_size = 8
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.add_theme_color_override("font_color", UITheme.MEADOW_DEEP)
	btn.add_theme_font_size_override("font_size", 17)


func _style_tab_idle(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.14, 0.09, 0.92)
	s.border_color = Color(1, 1, 1, 0.22)
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.border_color = UITheme.YOLK
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus", h)
	btn.add_theme_color_override("font_color", UITheme.CREAM)
	btn.add_theme_color_override("font_hover_color", UITheme.YOLK_HOT)
	btn.add_theme_font_size_override("font_size", 16)


func _rebuild_grid() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	if GameManager.catalog == null:
		return
	var stage: StageDef = GameManager.catalog.get_stage(_stage_index)
	if stage == null:
		return

	var count: int = stage.get_level_count()
	_grid.columns = mini(count, 4) if count > 0 else 4

	# Fit scroll width to cards.
	var card_w: float = 210.0
	var gap: float = 16.0
	var cols: int = _grid.columns
	_scroll.custom_minimum_size = Vector2(
		float(cols) * card_w + float(maxi(cols - 1, 0)) * gap + 8.0,
		360.0
	)

	for i: int in range(count):
		var level: LevelData = stage.get_level(i)
		var unlocked: bool = SaveService.is_level_unlocked(level.level_number)
		var stars: int = SaveService.get_level_stars(level.id)
		var best: int = SaveService.get_level_best_score(level.id)
		var card: Control = _make_level_card(level, unlocked, stars, best, i)
		_grid.add_child(card)
	_focus_furthest_card.call_deferred()


func _focus_furthest_card() -> void:
	if not is_visible_in_tree():
		return
	var target: Control = null
	for c: Node in _grid.get_children():
		if c is Control and not c.is_queued_for_deletion() and c.has_meta(&"level_card"):
			target = c as Control
	if target:
		target.grab_focus()
	else:
		_back.grab_focus()


func _make_level_card(
	level: LevelData,
	unlocked: bool,
	stars: int,
	best: int,
	level_index: int
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 168)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	if unlocked:
		if level.is_boss_level:
			style.bg_color = Color(0.18, 0.10, 0.08, 0.96)
			style.border_color = Color(1.0, 0.45, 0.2, 0.9)
		else:
			style.bg_color = Color(0.10, 0.22, 0.14, 0.96)
			style.border_color = Color(0.95, 0.82, 0.28, 0.75) if stars > 0 else Color(1, 1, 1, 0.28)
	else:
		style.bg_color = Color(0.06, 0.1, 0.08, 0.9)
		style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var num := Label.new()
	num.text = "BOSS" if level.is_boss_level else ("LEVEL %d" % level.level_number)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 13)
	num.add_theme_color_override("font_color", Color(1, 1, 1, 0.55) if unlocked else Color(1, 1, 1, 0.3))
	vbox.add_child(num)

	var name_l := Label.new()
	name_l.text = level.display_name
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", UITheme.CREAM if unlocked else Color(0.7, 0.72, 0.68, 0.55))
	name_l.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.04, 0.7))
	name_l.add_theme_constant_override("outline_size", 3)
	vbox.add_child(name_l)

	var star_l := Label.new()
	star_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_l.add_theme_font_size_override("font_size", 22)
	if unlocked:
		star_l.text = "★".repeat(stars) + "☆".repeat(maxi(3 - stars, 0))
		star_l.add_theme_color_override("font_color", UITheme.YOLK if stars > 0 else Color(1, 1, 1, 0.35))
	else:
		star_l.text = "🔒"
		star_l.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35, 0.65))
	vbox.add_child(star_l)

	var score_l := Label.new()
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_l.add_theme_font_size_override("font_size", 14)
	if unlocked:
		score_l.text = "Best  %d" % best if best > 0 else "Not cleared"
		score_l.add_theme_color_override("font_color", Color(0.9, 0.92, 0.8, 0.75))
	else:
		score_l.text = "Locked"
		score_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	vbox.add_child(score_l)

	if unlocked:
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var s_idx: int = _stage_index
		var l_idx: int = level_index
		panel.focus_mode = Control.FOCUS_ALL
		panel.set_meta(&"level_card", true)
		panel.gui_input.connect(func(event: InputEvent) -> void:
			var activate: bool = false
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				activate = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
			elif event.is_action_pressed(&"ui_accept"):
				activate = true
			if activate:
				panel.accept_event()
				UIFx.punch_button(panel)
				# Don't emit closed — MainMenu stays hidden while the run loads.
				visible = false
				GameManager.start_run(s_idx, l_idx)
		)
		# Hover / keyboard focus brighten.
		var hs := style.duplicate() as StyleBoxFlat
		hs.border_color = UITheme.YOLK_HOT
		hs.bg_color = Color(0.14, 0.28, 0.18, 0.98)
		hs.set_border_width_all(3)
		var highlight := func() -> void: panel.add_theme_stylebox_override("panel", hs)
		var unhighlight := func() -> void:
			if not panel.has_focus():
				panel.add_theme_stylebox_override("panel", style)
		panel.mouse_entered.connect(highlight)
		panel.focus_entered.connect(highlight)
		panel.mouse_exited.connect(unhighlight)
		panel.focus_exited.connect(func() -> void: panel.add_theme_stylebox_override("panel", style))
	else:
		panel.modulate = Color(0.85, 0.85, 0.85, 0.9)

	return panel
