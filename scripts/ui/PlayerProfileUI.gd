extends Control
## Zuma-inspired Player Profile modal dialog.
## Allows players to set their identity, switch profiles, and customize their name.

signal profile_confirmed(player_name: String)
signal profile_cancelled

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _subtitle: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var _name_edit: LineEdit = $Center/Panel/Margin/VBox/NameInput
@onready var _profiles_box: HFlowContainer = $Center/Panel/Margin/VBox/ProfilesScroll/ProfileChips
@onready var _ok_btn: Button = $Center/Panel/Margin/VBox/ButtonRow/OkButton
@onready var _cancel_btn: Button = $Center/Panel/Margin/VBox/ButtonRow/CancelButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style_dialog()

	_ok_btn.pressed.connect(_on_ok)
	_cancel_btn.pressed.connect(_on_cancel)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_ok())


func open_dialog() -> void:
	visible = true
	modulate.a = 0.0
	_name_edit.text = SaveService.current_player_name
	_rebuild_quick_profiles()

	# Staggered pop-in animation like classic PopCap dialogs.
	_panel.scale = Vector2(0.85, 0.85)
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.28)

	_name_edit.grab_focus()
	_name_edit.select_all()


func close_dialog() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(func() -> void: visible = false)


func _style_dialog() -> void:
	# Wooden/Stone Plaque Frame.
	var plaque_style := StyleBoxFlat.new()
	plaque_style.bg_color = Color(0.09, 0.16, 0.11, 0.98)
	plaque_style.border_color = Color(0.82, 0.68, 0.32, 0.90)
	plaque_style.set_border_width_all(5)
	plaque_style.set_corner_radius_all(14)
	plaque_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	plaque_style.shadow_size = 16
	plaque_style.shadow_offset = Vector2(0, 6)
	_panel.add_theme_stylebox_override("panel", plaque_style)

	# Title: Zuma-style Carved Header.
	_title.text = "PLAYER PROFILE"
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_title.add_theme_color_override("font_outline_color", Color(0.06, 0.14, 0.07, 0.95))
	_title.add_theme_constant_override("outline_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle: Retro PopCap Gold Prompt.
	_subtitle.text = "PLEASE ENTER YOUR NAME:"
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62, 0.90))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.05, 0.10, 0.05, 0.70))
	_subtitle.add_theme_constant_override("outline_size", 3)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Recessed Carved Input Field.
	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = Color(0.04, 0.08, 0.05, 0.95)
	edit_style.border_color = Color(0.65, 0.52, 0.25, 0.60)
	edit_style.set_border_width_all(3)
	edit_style.set_corner_radius_all(8)
	edit_style.content_margin_left = 14
	edit_style.content_margin_right = 14
	edit_style.content_margin_top = 10
	edit_style.content_margin_bottom = 10
	_name_edit.add_theme_stylebox_override("normal", edit_style)
	_name_edit.add_theme_stylebox_override("focus", edit_style)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", UITheme.YOLK)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 16

	# Action Buttons.
	UITheme.apply_primary_button(_ok_btn)
	_ok_btn.text = "OK"
	_ok_btn.add_theme_font_size_override("font_size", 20)
	_ok_btn.custom_minimum_size = Vector2(130, 48)

	UITheme.apply_ghost_button(_cancel_btn)
	_cancel_btn.text = "CANCEL"
	_cancel_btn.add_theme_font_size_override("font_size", 18)
	_cancel_btn.custom_minimum_size = Vector2(130, 48)


func _rebuild_quick_profiles() -> void:
	for child in _profiles_box.get_children():
		child.queue_free()

	for prof in SaveService.profiles:
		var p_name: String = String(prof)
		var chip := Button.new()
		chip.text = p_name
		UITheme.apply_ghost_button(chip)
		chip.add_theme_font_size_override("font_size", 13)
		chip.custom_minimum_size = Vector2(0, 32)
		chip.pressed.connect(func() -> void:
			_name_edit.text = p_name
			_on_ok()
		)
		_profiles_box.add_child(chip)


func _on_ok() -> void:
	var chosen: String = _name_edit.text.strip_edges()
	if chosen.is_empty():
		chosen = "Farmer Cluck"
	SaveService.set_player_name(chosen)
	UIFx.punch_button(_ok_btn)
	profile_confirmed.emit(chosen)
	close_dialog()


func _on_cancel() -> void:
	UIFx.punch_button(_cancel_btn)
	profile_cancelled.emit()
	close_dialog()
