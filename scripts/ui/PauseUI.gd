extends OverlayBase
## Pause overlay — meadow default, ember plaque when in a Gauntlet run.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _subtitle: Label = $Center/Panel/VBox/Subtitle if has_node("Center/Panel/VBox/Subtitle") else null
@onready var _resume: Button = $Center/Panel/VBox/ResumeButton
@onready var _retry: Button = $Center/Panel/VBox/RetryButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton

const EMBER := Color(0.55, 0.2, 0.06)
const EMBER_HOT := Color(0.85, 0.4, 0.1)
const EMBER_EDGE := Color(1.0, 0.82, 0.28)
const EMBER_GOLD := Color(1.0, 0.92, 0.45)


func _ready() -> void:
	visible_state = GameManager.State.PAUSED
	super._ready()
	_style_default()
	_resume.pressed.connect(func() -> void:
		UIFx.punch_button(_resume)
		GameManager.resume_game()
	)
	_retry.pressed.connect(func() -> void:
		UIFx.punch_button(_retry)
		GameManager.retry_level()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)


func show_overlay() -> void:
	if GameManager.is_gauntlet_run:
		_style_gauntlet()
	else:
		_style_default()
	await super.show_overlay()


func _style_default() -> void:
	if _panel and _panel is PanelContainer:
		(_panel as PanelContainer).add_theme_stylebox_override("panel", UITheme.panel_style())
	if _backdrop:
		_backdrop.color = UITheme.DIM
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.text = "Paused"
	if _subtitle:
		_subtitle.visible = false
	UITheme.apply_primary_button(_resume)
	UITheme.apply_ghost_button(_retry)
	UITheme.apply_ghost_button(_menu)
	_resume.text = "Resume"
	_retry.text = "Retry Level"
	_menu.text = "Main Menu"


func _style_gauntlet() -> void:
	if _backdrop:
		_backdrop.color = Color(0.08, 0.02, 0.0, 0.78)

	var plaque := StyleBoxFlat.new()
	plaque.bg_color = Color(0.16, 0.07, 0.03, 0.97)
	plaque.border_color = EMBER_EDGE
	plaque.set_border_width_all(5)
	plaque.border_width_top = 7
	plaque.border_width_bottom = 4
	plaque.set_corner_radius_all(18)
	plaque.content_margin_left = 32
	plaque.content_margin_right = 32
	plaque.content_margin_top = 28
	plaque.content_margin_bottom = 28
	plaque.shadow_color = Color(1.0, 0.35, 0.05, 0.45)
	plaque.shadow_size = 18
	plaque.shadow_offset = Vector2(0, 8)
	if _panel and _panel is PanelContainer:
		(_panel as PanelContainer).add_theme_stylebox_override("panel", plaque)
		(_panel as Control).custom_minimum_size = Vector2(380, 0)

	UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
	_title.text = "GAUNTLET PAUSED"
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", EMBER_GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.25, 0.06, 0.0, 0.95))
	_title.add_theme_constant_override("outline_size", 7)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if _subtitle:
		_subtitle.visible = true
		_subtitle.text = "HIGH SCORE RUN"
		UITheme.apply_font(_subtitle, UITheme.WEIGHT_BOLD)
		_subtitle.add_theme_font_size_override("font_size", 14)
		_subtitle.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 0.95))
		_subtitle.add_theme_color_override("font_outline_color", Color(0.15, 0.04, 0.0, 0.8))
		_subtitle.add_theme_constant_override("outline_size", 2)
		_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_apply_ember_primary(_resume, "RESUME")
	_apply_ember_ghost(_retry, "RETRY LEVEL")
	_apply_ember_ghost(_menu, "MAIN MENU")


func _apply_ember_primary(btn: Button, label: String) -> void:
	btn.text = label
	UITheme.apply_font(btn, UITheme.WEIGHT_BOLD)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.18, 0.06, 0.02, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.12, 0.04, 0.01, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.08, 0.02, 1.0))
	btn.custom_minimum_size = Vector2(0, 60)
	var n := StyleBoxFlat.new()
	n.bg_color = EMBER_GOLD
	n.border_color = Color(0.75, 0.45, 0.1)
	n.set_border_width_all(3)
	n.set_corner_radius_all(16)
	n.content_margin_left = 20
	n.content_margin_right = 20
	n.content_margin_top = 14
	n.content_margin_bottom = 14
	n.shadow_color = Color(1.0, 0.4, 0.05, 0.4)
	n.shadow_size = 10
	n.shadow_offset = Vector2(0, 4)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(1.0, 0.96, 0.6)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus", h)


func _apply_ember_ghost(btn: Button, label: String) -> void:
	btn.text = label
	UITheme.apply_font(btn, UITheme.WEIGHT_BOLD)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", EMBER_GOLD)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.75, 1.0))
	btn.add_theme_color_override("font_pressed_color", EMBER_GOLD)
	btn.custom_minimum_size = Vector2(0, 54)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1.0, 0.45, 0.1, 0.12)
	n.border_color = EMBER_EDGE
	n.set_border_width_all(3)
	n.set_corner_radius_all(14)
	n.content_margin_left = 18
	n.content_margin_right = 18
	n.content_margin_top = 12
	n.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", n)
	btn.add_theme_stylebox_override("pressed", n)
	btn.add_theme_stylebox_override("focus", n)
