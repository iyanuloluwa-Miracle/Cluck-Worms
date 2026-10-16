extends Control
## Premium Zuma-style INSTRUCTIONS plaque — carved gold teaching board.

signal closed

const GOLD := Color(0.92, 0.78, 0.28)
const GOLD_DARK := Color(0.55, 0.40, 0.10)
const GOLD_LIGHT := Color(1.0, 0.94, 0.58)
const FILL_GREEN := Color(0.14, 0.24, 0.12)
const PANEL_GREEN := Color(0.10, 0.18, 0.09)
const PANEL_EDGE := Color(0.88, 0.72, 0.22)
const STONE_MID := Color(0.58, 0.58, 0.54)
const JADE := Color(0.42, 0.78, 0.28)
const JADE_HOT := Color(0.55, 0.90, 0.36)
const FOOTER_BG := Color(0.06, 0.10, 0.06, 0.92)

@onready var _frame: Control = $Center/StoneFrame
@onready var _fill: PanelContainer = $Center/StoneFrame/Inner/Fill
@onready var _title: Label = $Center/StoneFrame/Inner/Fill/Pad/VBox/Title
@onready var _title_rule: ColorRect = $Center/StoneFrame/Inner/Fill/Pad/VBox/TitleRule
@onready var _footer_bar: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/FooterBar
@onready var _dont_show: CheckButton = $Center/StoneFrame/Inner/Fill/Pad/VBox/FooterBar/Footer/DontShow
@onready var _ok_btn: Button = $Center/StoneFrame/Inner/Fill/Pad/VBox/FooterBar/Footer/OkButton
@onready var _cell_shoot: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/TopRow/Shoot
@onready var _cell_match: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/TopRow/Match
@onready var _cell_nest: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/BottomRow/Nest
@onready var _cell_bonus: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/BottomRow/Bonus
@onready var _cell_swap: PanelContainer = $Center/StoneFrame/Inner/Fill/Pad/VBox/Grid/BottomRow/Swap

var _ok_pulse: Tween
var _cells: Array[PanelContainer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cells = [_cell_shoot, _cell_match, _cell_nest, _cell_bonus, _cell_swap]
	_style()
	_frame.draw.connect(_draw_frame)
	_frame.resized.connect(_frame.queue_redraw)
	_ok_btn.pressed.connect(_on_ok)


func open_instructions(_from_startup: bool = false) -> void:
	_dont_show.button_pressed = SaveService.tutorial_done
	visible = true
	modulate.a = 0.0
	_frame.queue_redraw()
	_frame.scale = Vector2(0.86, 0.86)
	_frame.pivot_offset = _frame.size * 0.5

	for cell: PanelContainer in _cells:
		cell.modulate.a = 0.0
		cell.scale = Vector2(0.92, 0.92)
		cell.pivot_offset = cell.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(_frame, "scale", Vector2.ONE, 0.32)
	tween.chain().tween_callback(_stagger_cells)
	_start_ok_pulse()


func close_instructions() -> void:
	_stop_ok_pulse()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)


func _stagger_cells() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for i: int in range(_cells.size()):
		var cell: PanelContainer = _cells[i]
		cell.pivot_offset = cell.size * 0.5
		var d: float = 0.05 * float(i)
		tween.tween_property(cell, "modulate:a", 1.0, 0.22).set_delay(d)
		tween.tween_property(cell, "scale", Vector2.ONE, 0.28).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_GREEN
	fill.border_color = GOLD_DARK
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(6)
	_fill.add_theme_stylebox_override("panel", fill)

	_title.text = "INSTRUCTIONS"
	UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", GOLD_LIGHT)
	_title.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.02, 0.95))
	_title.add_theme_constant_override("outline_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_rule.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.7)

	_style_cell(
		_cell_shoot,
		"SHOOT WORMS BY CLICKING WHERE YOU WANT THEM TO GO.",
		"THE COLOR ON THE CHICKEN'S BACK SHOWS YOUR NEXT WORM."
	)
	_style_cell(
		_cell_match,
		"CLEAR WORMS BY GETTING THREE OR MORE OF THE SAME COLOR IN A ROW.",
		"AFTER A MATCH THE CHAIN REVERSES TO CLOSE THE GAP — SET UP CASCADES!"
	)
	_style_cell(_cell_nest, "DON'T LET THE WORMS REACH THE NEST!", "")
	_style_cell(_cell_bonus, "MATCH SPECIAL WORMS FOR BONUS POINTS & POWER-UPS!", "")
	_style_cell(
		_cell_swap,
		"RIGHT MOUSE / SPACE SWAPS. Q = SLOW PULSE. E = BOMB BLAST.",
		"ABILITIES USE LIMITED CHARGES — SPEND THEM WISELY!"
	)

	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = FOOTER_BG
	footer_style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	footer_style.set_border_width_all(2)
	footer_style.set_corner_radius_all(10)
	footer_style.content_margin_left = 16
	footer_style.content_margin_right = 16
	footer_style.content_margin_top = 10
	footer_style.content_margin_bottom = 10
	_footer_bar.add_theme_stylebox_override("panel", footer_style)

	UITheme.apply_font(_dont_show, UITheme.WEIGHT_BOLD)
	_dont_show.add_theme_font_size_override("font_size", 16)
	_dont_show.add_theme_color_override("font_color", GOLD_LIGHT)
	_dont_show.add_theme_color_override("font_pressed_color", GOLD)
	_dont_show.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.8, 1))
	_dont_show.text = "DON'T SHOW THIS SCREEN AT STARTUP."

	_ok_btn.text = "OK"
	UITheme.apply_font(_ok_btn, UITheme.WEIGHT_BOLD)
	_ok_btn.add_theme_font_size_override("font_size", 26)
	_ok_btn.add_theme_color_override("font_color", GOLD_LIGHT)
	_ok_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.75, 1.0))
	_ok_btn.add_theme_color_override("font_pressed_color", GOLD)
	_ok_btn.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.04, 0.85))
	_ok_btn.add_theme_constant_override("outline_size", 4)
	_ok_btn.custom_minimum_size = Vector2(160, 56)
	_ok_btn.add_theme_stylebox_override("normal", _jade_btn(JADE))
	_ok_btn.add_theme_stylebox_override("hover", _jade_btn(JADE_HOT))
	_ok_btn.add_theme_stylebox_override("pressed", _jade_btn(Color(0.34, 0.62, 0.22), true))
	_ok_btn.add_theme_stylebox_override("focus", _jade_btn(JADE_HOT))


func _style_cell(panel: PanelContainer, head: String, body: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_GREEN
	style.border_color = PANEL_EDGE
	style.set_border_width_all(4)
	style.border_width_top = 5
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = panel.get_node("VBox") as VBoxContainer
	var head_l: Label = vbox.get_node("Head") as Label
	UITheme.apply_font(head_l, UITheme.WEIGHT_BOLD)
	head_l.text = head
	head_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_l.add_theme_font_size_override("font_size", 15)
	head_l.add_theme_color_override("font_color", GOLD_LIGHT)
	head_l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.02, 0.85))
	head_l.add_theme_constant_override("outline_size", 3)

	var body_l: Label = vbox.get_node("Body") as Label
	if body.is_empty():
		body_l.visible = false
		body_l.text = ""
	else:
		body_l.visible = true
		body_l.text = body
		UITheme.apply_font(body_l, UITheme.WEIGHT_SEMIBOLD)
		body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body_l.add_theme_font_size_override("font_size", 13)
		body_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 0.92))
		body_l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.02, 0.7))
		body_l.add_theme_constant_override("outline_size", 2)


func _jade_btn(fill: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = STONE_MID
	s.set_border_width_all(7)
	s.border_width_top = 8
	s.border_width_bottom = 5
	s.set_corner_radius_all(28)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35 if not pressed else 0.15)
	s.shadow_size = 7 if not pressed else 2
	s.shadow_offset = Vector2(0, 4 if not pressed else 1)
	return s


func _draw_frame() -> void:
	var r := Rect2(Vector2.ZERO, _frame.size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return

	_frame.draw_rect(Rect2(r.position + Vector2(5, 8), r.size), Color(0, 0, 0, 0.45), true)

	# Carved gold slab
	_frame.draw_rect(r, GOLD_DARK, true)
	_frame.draw_rect(r.grow(-3), GOLD, true)
	_frame.draw_rect(r.grow(-7), GOLD_DARK, true)

	# Greek-key / notch rhythm on the rim
	var rim := 18.0
	var step := 16.0
	var x := r.position.x + 34.0
	while x < r.end.x - 34.0:
		_frame.draw_rect(Rect2(x, r.position.y + 5.0, 10.0, 6.0), GOLD_LIGHT, true)
		_frame.draw_rect(Rect2(x, r.end.y - 11.0, 10.0, 6.0), GOLD_LIGHT, true)
		x += step
	var y := r.position.y + 34.0
	while y < r.end.y - 34.0:
		_frame.draw_rect(Rect2(r.position.x + 5.0, y, 6.0, 10.0), GOLD_LIGHT, true)
		_frame.draw_rect(Rect2(r.end.x - 11.0, y, 6.0, 10.0), GOLD_LIGHT, true)
		y += step

	# Inner channel
	var inner := r.grow(-rim)
	_frame.draw_rect(inner, Color(0.08, 0.12, 0.06), false, 3.0)
	_frame.draw_rect(inner.grow(-3), GOLD, false, 2.0)

	# Corner bosses
	var corner := 28.0
	var corners: Array[Vector2] = [
		r.position + Vector2(5, 5),
		Vector2(r.end.x - corner - 5, r.position.y + 5),
		Vector2(r.position.x + 5, r.end.y - corner - 5),
		Vector2(r.end.x - corner - 5, r.end.y - corner - 5),
	]
	for c: Vector2 in corners:
		var cr := Rect2(c, Vector2(corner, corner))
		_frame.draw_rect(cr, GOLD_LIGHT, true)
		_frame.draw_rect(cr.grow(-4), GOLD, true)
		_frame.draw_rect(cr.grow(-8), GOLD_DARK, true)
		_frame.draw_rect(cr.grow(-11), Color(0.95, 0.85, 0.4), true)


func _start_ok_pulse() -> void:
	_stop_ok_pulse()
	if not is_instance_valid(_ok_btn):
		return
	_ok_btn.pivot_offset = _ok_btn.size * 0.5
	_ok_pulse = create_tween()
	_ok_pulse.set_loops()
	_ok_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ok_pulse.tween_property(_ok_btn, "scale", Vector2(1.05, 1.05), 0.85)
	_ok_pulse.tween_property(_ok_btn, "scale", Vector2.ONE, 0.85)


func _stop_ok_pulse() -> void:
	if _ok_pulse != null:
		_ok_pulse.kill()
		_ok_pulse = null
	if is_instance_valid(_ok_btn):
		_ok_btn.scale = Vector2.ONE


func _on_ok() -> void:
	SaveService.set_tutorial_done(_dont_show.button_pressed)
	UIFx.punch_button(_ok_btn)
	close_instructions()
