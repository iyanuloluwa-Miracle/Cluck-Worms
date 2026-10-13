class_name UITheme
extends RefCounted
## Design tokens for Cluck & Worms — meadow + yolk, high readability.
## Mobile-first: large touch targets, generous margins, strong contrast.

# --- Typography ---
const FONT_PATH := "res://fonts/Fredoka-Variable.ttf"
static var _font: Font

# --- Palette ---
const MEADOW_DEEP := Color(0.07, 0.16, 0.11)
const MEADOW := Color(0.12, 0.28, 0.18)
const MEADOW_LIGHT := Color(0.18, 0.38, 0.24)
const PANEL := Color(0.10, 0.20, 0.14, 0.96)
const PANEL_EDGE := Color(0.35, 0.55, 0.38, 0.55)
const YOLK := Color(0.98, 0.78, 0.18)
const YOLK_HOT := Color(1.0, 0.88, 0.35)
const CREAM := Color(0.99, 0.97, 0.90)
const CREAM_DIM := Color(0.82, 0.88, 0.78)
const DANGER := Color(0.90, 0.32, 0.28)
const SUCCESS := Color(0.42, 0.86, 0.40)
const DIM := Color(0.02, 0.05, 0.03, 0.72)

# --- Layout (mobile-first) ---
const MARGIN_SAFE := 20.0
const TOUCH_MIN := 56.0
const PANEL_RADIUS := 22.0
const CHIP_RADIUS := 14.0
const TITLE_SIZE := 44
const HEADING_SIZE := 32
const BODY_SIZE := 18
const CAPTION_SIZE := 14
const BUTTON_FONT := 20


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


static func apply_font(control: Control) -> void:
	var f := font()
	if f == null or control == null:
		return
	control.add_theme_font_override("font", f)


static func panel_style(fill: Color = PANEL, border: Color = PANEL_EDGE, radius: float = PANEL_RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	return s


static func chip_style(fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(CHIP_RADIUS))
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


static func button_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = YOLK
	s.border_color = Color(0.72, 0.48, 0.08)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


static func button_hover() -> StyleBoxFlat:
	var s := button_normal()
	s.bg_color = YOLK_HOT
	return s


static func button_pressed() -> StyleBoxFlat:
	var s := button_normal()
	s.bg_color = Color(0.88, 0.65, 0.12)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 1)
	return s


static func button_ghost() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.08)
	s.border_color = Color(1, 1, 1, 0.28)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func apply_primary_button(btn: Button) -> void:
	apply_font(btn)
	btn.add_theme_stylebox_override("normal", button_normal())
	btn.add_theme_stylebox_override("hover", button_hover())
	btn.add_theme_stylebox_override("pressed", button_pressed())
	btn.add_theme_stylebox_override("focus", button_hover())
	btn.add_theme_color_override("font_color", MEADOW_DEEP)
	btn.add_theme_color_override("font_hover_color", MEADOW_DEEP)
	btn.add_theme_color_override("font_pressed_color", MEADOW_DEEP)
	btn.add_theme_font_size_override("font_size", BUTTON_FONT)
	btn.custom_minimum_size = Vector2(0, TOUCH_MIN)


static func apply_ghost_button(btn: Button) -> void:
	apply_font(btn)
	var ghost := button_ghost()
	btn.add_theme_stylebox_override("normal", ghost)
	btn.add_theme_stylebox_override("hover", ghost)
	btn.add_theme_stylebox_override("pressed", button_pressed())
	btn.add_theme_stylebox_override("focus", ghost)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", YOLK_HOT)
	btn.add_theme_color_override("font_pressed_color", CREAM)
	btn.add_theme_font_size_override("font_size", BUTTON_FONT - 2)
	btn.custom_minimum_size = Vector2(0, TOUCH_MIN - 4)


static func style_title(label: Label, size: int = TITLE_SIZE) -> void:
	apply_font(label)
	label.add_theme_color_override("font_color", YOLK)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func style_body(label: Label, size: int = BODY_SIZE, dim: bool = false) -> void:
	apply_font(label)
	label.add_theme_color_override("font_color", CREAM_DIM if dim else CREAM)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
