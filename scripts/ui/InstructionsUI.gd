extends Control
## Zuma-style INSTRUCTIONS plaque — how to play Cluck & Worms.

signal closed

const GOLD := Color(0.92, 0.78, 0.28)
const GOLD_DARK := Color(0.62, 0.48, 0.12)
const GOLD_LIGHT := Color(1.0, 0.92, 0.55)
const FILL_GREEN := Color(0.16, 0.26, 0.14)
const PANEL_GREEN := Color(0.12, 0.20, 0.11)
const STONE_MID := Color(0.58, 0.58, 0.54)
const JADE := Color(0.42, 0.78, 0.28)
const JADE_HOT := Color(0.52, 0.88, 0.34)

@onready var _frame: Control = $Center/StoneFrame
@onready var _fill: PanelContainer = $Center/StoneFrame/Inner/Fill
@onready var _title: Label = $Center/StoneFrame/Inner/Fill/Pad/VBox/Title
@onready var _dont_show: CheckButton = $Center/StoneFrame/Inner/Fill/Pad/VBox/Footer/DontShow
@onready var _ok_btn: Button = $Center/StoneFrame/Inner/Fill/Pad/VBox/Footer/OkButton
@onready var _cell_shoot: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/TopRow/Shoot
@onready var _cell_match: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/TopRow/Match
@onready var _cell_nest: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/BottomRow/Nest
@onready var _cell_bonus: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/BottomRow/Bonus
@onready var _cell_swap: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/BottomRow/Swap


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style()
	_frame.draw.connect(_draw_frame)
	_frame.resized.connect(_frame.queue_redraw)
	_ok_btn.pressed.connect(_on_ok)


func open_instructions(from_startup: bool = false) -> void:
	_dont_show.button_pressed = SaveService.tutorial_done if from_startup else SaveService.tutorial_done
	visible = true
	modulate.a = 0.0
	_frame.queue_redraw()
	_frame.scale = Vector2(0.88, 0.88)
	_frame.pivot_offset = _frame.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_frame, "scale", Vector2.ONE, 0.28)


func close_instructions() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)


func _style() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_GREEN
	fill.border_color = GOLD_DARK
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(4)
	_fill.add_theme_stylebox_override("panel", fill)

	_title.text = "INSTRUCTIONS"
	UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", GOLD_LIGHT)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.02, 0.9))
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_style_cell(_cell_shoot, "🐔", [
		"SHOOT WORMS BY CLICKING WHERE YOU WANT THEM TO GO.",
		"THE COLOR ON THE CHICKEN SHOWS YOUR NEXT WORM."
	])
	_style_cell(_cell_match, "🐛🐛🐛", [
		"CLEAR WORMS BY GETTING THREE OR MORE OF THE SAME COLOR IN A ROW.",
		"LIKE COLORS ATTRACT AND CAN CREATE CHAIN REACTIONS!"
	])
	_style_cell(_cell_nest, "🪺", [
		"DON'T LET THE WORMS REACH THE NEST!"
	])
	_style_cell(_cell_bonus, "⭐", [
		"MATCH SPECIAL WORMS FOR BONUS POINTS AND POWER-UPS!"
	])
	_style_cell(_cell_swap, "🖱️", [
		"RIGHT MOUSE BUTTON OR SPACE WILL SWAP YOUR WORMS."
	])

	UITheme.apply_font(_dont_show, UITheme.WEIGHT_BOLD)
	_dont_show.add_theme_font_size_override("font_size", 15)
	_dont_show.add_theme_color_override("font_color", GOLD_LIGHT)
	_dont_show.text = "DON'T SHOW THIS SCREEN AT STARTUP."

	_ok_btn.text = "OK"
	UITheme.apply_font(_ok_btn, UITheme.WEIGHT_BOLD)
	_ok_btn.add_theme_font_size_override("font_size", 24)
	_ok_btn.add_theme_color_override("font_color", GOLD_LIGHT)
	_ok_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.7, 1.0))
	_ok_btn.add_theme_color_override("font_pressed_color", GOLD)
	_ok_btn.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.04, 0.8))
	_ok_btn.add_theme_constant_override("outline_size", 3)
	_ok_btn.custom_minimum_size = Vector2(140, 52)
	_ok_btn.add_theme_stylebox_override("normal", _jade_btn(JADE))
	_ok_btn.add_theme_stylebox_override("hover", _jade_btn(JADE_HOT))
	_ok_btn.add_theme_stylebox_override("pressed", _jade_btn(Color(0.34, 0.62, 0.22), true))
	_ok_btn.add_theme_stylebox_override("focus", _jade_btn(JADE_HOT))


func _style_cell(panel: PanelContainer, icon_text: String, lines: Array) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_GREEN
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = panel.get_node("VBox") as VBoxContainer
	var icon: Label = vbox.get_node("Icon") as Label
	icon.text = icon_text
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_font(icon, UITheme.WEIGHT_BOLD)
	icon.add_theme_font_size_override("font_size", 36)

	var body: Label = vbox.get_node("Body") as Label
	body.text = "\n\n".join(PackedStringArray(lines))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_font(body, UITheme.WEIGHT_BOLD)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", GOLD_LIGHT)
	body.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.02, 0.75))
	body.add_theme_constant_override("outline_size", 2)


func _jade_btn(fill: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = STONE_MID
	s.set_border_width_all(6)
	s.set_corner_radius_all(26)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.3 if not pressed else 0.15)
	s.shadow_size = 5 if not pressed else 2
	s.shadow_offset = Vector2(0, 3 if not pressed else 1)
	return s


func _draw_frame() -> void:
	var r := Rect2(Vector2.ZERO, _frame.size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	_frame.draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.4), true)
	_frame.draw_rect(r, GOLD_DARK, true)
	# Ornate gold rim
	_frame.draw_rect(r.grow(-4), GOLD, false, 5.0)
	_frame.draw_rect(r.grow(-10), GOLD_LIGHT, false, 2.0)
	# Corner blocks
	var corner := 22.0
	var corners: Array[Vector2] = [
		r.position + Vector2(6, 6),
		Vector2(r.end.x - corner - 6, r.position.y + 6),
		Vector2(r.position.x + 6, r.end.y - corner - 6),
		Vector2(r.end.x - corner - 6, r.end.y - corner - 6),
	]
	for c: Vector2 in corners:
		var cr := Rect2(c, Vector2(corner, corner))
		_frame.draw_rect(cr, GOLD_LIGHT, true)
		_frame.draw_rect(cr.grow(-3), GOLD, true)
		_frame.draw_rect(cr.grow(-6), GOLD_DARK, true)


func _on_ok() -> void:
	SaveService.set_tutorial_done(_dont_show.button_pressed)
	UIFx.punch_button(_ok_btn)
	close_instructions()
