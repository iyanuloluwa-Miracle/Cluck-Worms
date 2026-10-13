extends Control
## Zuma-style "NEW USER" stone plaque modal for player name entry.

signal profile_confirmed(player_name: String)
signal profile_cancelled

const STONE_LIGHT := Color(0.78, 0.78, 0.74)
const STONE_MID := Color(0.58, 0.58, 0.54)
const STONE_DARK := Color(0.38, 0.38, 0.35)
const STONE_SHADOW := Color(0.22, 0.22, 0.20)
const FILL_GREEN := Color(0.22, 0.32, 0.18)
const FILL_DEEP := Color(0.10, 0.18, 0.10)
const JADE := Color(0.42, 0.78, 0.28)
const JADE_HOT := Color(0.52, 0.88, 0.34)
const JADE_PRESS := Color(0.34, 0.62, 0.22)
const TITLE_STONE := Color(0.86, 0.86, 0.80)

@onready var _frame: Control = $Center/StoneFrame
@onready var _fill: PanelContainer = $Center/StoneFrame/Inner/Fill
@onready var _title: Label = $Center/StoneFrame/Inner/Fill/Pad/VBox/Title
@onready var _subtitle: Label = $Center/StoneFrame/Inner/Fill/Pad/VBox/Subtitle
@onready var _name_edit: LineEdit = $Center/StoneFrame/Inner/Fill/Pad/VBox/NameInput
@onready var _profiles_box: HFlowContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/ProfilesScroll/ProfileChips
@onready var _ok_btn: Button = $Center/StoneFrame/Inner/Fill/Pad/VBox/ButtonRow/OkButton
@onready var _cancel_btn: Button = $Center/StoneFrame/Inner/Fill/Pad/VBox/ButtonRow/CancelButton
@onready var _profiles_scroll: ScrollContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/ProfilesScroll

var _first_time: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style_dialog()
	_frame.draw.connect(_draw_stone_frame)
	_frame.resized.connect(_frame.queue_redraw)

	_ok_btn.pressed.connect(_on_ok)
	_cancel_btn.pressed.connect(_on_cancel)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_ok())


func open_dialog(first_time: bool = false) -> void:
	_first_time = first_time
	visible = true
	modulate.a = 0.0

	_title.text = "NEW USER"
	_cancel_btn.visible = not _first_time
	_profiles_scroll.visible = not _first_time
	if _first_time:
		_name_edit.text = ""
	else:
		_name_edit.text = SaveService.current_player_name
		_rebuild_quick_profiles()
	_frame.queue_redraw()

	_frame.scale = Vector2(0.86, 0.86)
	_frame.pivot_offset = _frame.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_frame, "scale", Vector2.ONE, 0.28)

	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()


func close_dialog() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(func() -> void: visible = false)


func _style_dialog() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_GREEN
	fill.border_color = STONE_SHADOW
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(4)
	_fill.add_theme_stylebox_override("panel", fill)

	_title.text = "NEW USER"
	UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", TITLE_STONE)
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.12, 0.10, 0.85))
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_subtitle.text = "PLEASE ENTER YOUR NAME."
	UITheme.apply_font(_subtitle, UITheme.WEIGHT_BOLD)
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.04, 0.75))
	_subtitle.add_theme_constant_override("outline_size", 3)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var edit_n := StyleBoxFlat.new()
	edit_n.bg_color = FILL_DEEP
	edit_n.border_color = Color(0.05, 0.08, 0.04, 1.0)
	edit_n.set_border_width_all(2)
	edit_n.set_corner_radius_all(2)
	edit_n.content_margin_left = 12
	edit_n.content_margin_right = 12
	edit_n.content_margin_top = 10
	edit_n.content_margin_bottom = 10
	var edit_f := edit_n.duplicate() as StyleBoxFlat
	edit_f.border_color = Color(0.55, 0.72, 0.28, 0.85)
	_name_edit.add_theme_stylebox_override("normal", edit_n)
	_name_edit.add_theme_stylebox_override("focus", edit_f)
	UITheme.apply_font(_name_edit, UITheme.WEIGHT_SEMIBOLD)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", UITheme.CREAM)
	_name_edit.add_theme_color_override("caret_color", Color(0.72, 0.45, 0.95, 1.0))
	_name_edit.add_theme_color_override("font_placeholder_color", Color(0.7, 0.78, 0.65, 0.55))
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_edit.max_length = 16
	_name_edit.placeholder_text = ""

	_apply_jade_button(_ok_btn, "OK")
	_apply_jade_button(_cancel_btn, "CANCEL")


func _apply_jade_button(btn: Button, label: String) -> void:
	btn.text = label
	UITheme.apply_font(btn, UITheme.WEIGHT_BOLD)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.55, 1.0))
	btn.add_theme_color_override("font_pressed_color", UITheme.YOLK)
	btn.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.04, 0.8))
	btn.add_theme_constant_override("outline_size", 3)
	btn.custom_minimum_size = Vector2(150, 56)

	btn.add_theme_stylebox_override("normal", _jade_style(JADE))
	btn.add_theme_stylebox_override("hover", _jade_style(JADE_HOT))
	btn.add_theme_stylebox_override("pressed", _jade_style(JADE_PRESS, true))
	btn.add_theme_stylebox_override("focus", _jade_style(JADE_HOT))


func _jade_style(fill: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = STONE_MID
	s.set_border_width_all(7)
	s.border_width_top = 8
	s.border_width_bottom = 6
	s.set_corner_radius_all(28)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35 if not pressed else 0.18)
	s.shadow_size = 6 if not pressed else 2
	s.shadow_offset = Vector2(0, 3 if not pressed else 1)
	return s


func _draw_stone_frame() -> void:
	var r := Rect2(Vector2.ZERO, _frame.size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return

	# Drop shadow under the plaque.
	_frame.draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35), true)

	# Outer stone slab.
	_frame.draw_rect(r, STONE_MID, true)

	# Bevel highlight / shadow on the slab edge.
	var bevel := 5.0
	_frame.draw_rect(Rect2(r.position, Vector2(r.size.x, bevel)), STONE_LIGHT, true)
	_frame.draw_rect(Rect2(r.position + Vector2(0, r.size.y - bevel), Vector2(r.size.x, bevel)), STONE_DARK, true)
	_frame.draw_rect(Rect2(r.position, Vector2(bevel, r.size.y)), STONE_LIGHT, true)
	_frame.draw_rect(Rect2(r.position + Vector2(r.size.x - bevel, 0), Vector2(bevel, r.size.y)), STONE_DARK, true)

	# Notched masonry rhythm along the frame ring.
	var ring := 22.0
	var notch_w := 18.0
	var notch_d := 7.0
	# Top & bottom notches
	var x := r.position.x + 36.0
	while x < r.end.x - 36.0:
		_frame.draw_rect(Rect2(x, r.position.y + 6.0, notch_w, notch_d), STONE_DARK, true)
		_frame.draw_rect(Rect2(x, r.end.y - 6.0 - notch_d, notch_w, notch_d), STONE_LIGHT, true)
		x += notch_w + 10.0
	# Left & right notches
	var y := r.position.y + 36.0
	while y < r.end.y - 36.0:
		_frame.draw_rect(Rect2(r.position.x + 6.0, y, notch_d, notch_w), STONE_DARK, true)
		_frame.draw_rect(Rect2(r.end.x - 6.0 - notch_d, y, notch_d, notch_w), STONE_LIGHT, true)
		y += notch_w + 10.0

	# Inner channel before the green fill.
	var inner := r.grow(-ring)
	_frame.draw_rect(inner, STONE_SHADOW, false, 3.0)

	# Corner stone blocks (protruding cubes).
	var corner := 26.0
	var corners: Array[Vector2] = [
		r.position + Vector2(4, 4),
		Vector2(r.end.x - corner - 4, r.position.y + 4),
		Vector2(r.position.x + 4, r.end.y - corner - 4),
		Vector2(r.end.x - corner - 4, r.end.y - corner - 4),
	]
	for c: Vector2 in corners:
		var cr := Rect2(c, Vector2(corner, corner))
		_frame.draw_rect(cr, STONE_LIGHT, true)
		_frame.draw_rect(cr.grow(-3), STONE_MID, true)
		_frame.draw_rect(Rect2(cr.position, Vector2(cr.size.x, 4)), Color(0.9, 0.9, 0.86), true)
		_frame.draw_rect(Rect2(cr.position + Vector2(0, cr.size.y - 4), Vector2(cr.size.x, 4)), STONE_DARK, true)


func _rebuild_quick_profiles() -> void:
	for child in _profiles_box.get_children():
		child.queue_free()

	for prof in SaveService.profiles:
		var p_name: String = String(prof)
		var chip := Button.new()
		chip.text = p_name
		UITheme.apply_font(chip, UITheme.WEIGHT_SEMIBOLD)
		chip.add_theme_font_size_override("font_size", 13)
		chip.add_theme_color_override("font_color", UITheme.YOLK_HOT)
		chip.add_theme_color_override("font_hover_color", Color(1, 1, 0.85, 1))
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.12, 0.2, 0.1, 0.9)
		cs.border_color = STONE_MID
		cs.set_border_width_all(2)
		cs.set_corner_radius_all(10)
		cs.content_margin_left = 10
		cs.content_margin_right = 10
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		chip.add_theme_stylebox_override("normal", cs)
		chip.add_theme_stylebox_override("hover", cs)
		chip.add_theme_stylebox_override("pressed", cs)
		chip.add_theme_stylebox_override("focus", cs)
		chip.custom_minimum_size = Vector2(0, 30)
		chip.pressed.connect(func() -> void:
			_name_edit.text = p_name
			_on_ok()
		)
		_profiles_box.add_child(chip)


func _on_ok() -> void:
	var chosen: String = _name_edit.text.strip_edges()
	if chosen.is_empty():
		if _first_time:
			_flash_name_required()
			return
		chosen = "Farmer Cluck"
	SaveService.set_player_name(chosen)
	UIFx.punch_button(_ok_btn)
	profile_confirmed.emit(chosen)
	close_dialog()


func _flash_name_required() -> void:
	_name_edit.grab_focus()
	var base := _name_edit.modulate
	_name_edit.modulate = UITheme.YOLK_HOT
	var tween := create_tween()
	tween.tween_property(_name_edit, "modulate", base, 0.35)


func _on_cancel() -> void:
	if _first_time:
		return
	UIFx.punch_button(_cancel_btn)
	profile_cancelled.emit()
	close_dialog()
