extends CanvasLayer
## In-run HUD with a carved stone navbar (Zuma-style) and Cluck & Worms polish.

@onready var _root: Control = $Root
@onready var _navbar: Control = $Root/Safe/NavBar
@onready var _lives_well: PanelContainer = $Root/Safe/NavBar/Inner/Row/LivesWell
@onready var _lives: Label = $Root/Safe/NavBar/Inner/Row/LivesWell/Margin/Lives
@onready var _level_well: PanelContainer = $Root/Safe/NavBar/Inner/Row/LevelWell
@onready var _level: Label = $Root/Safe/NavBar/Inner/Row/LevelWell/Margin/Level
@onready var _score_well: PanelContainer = $Root/Safe/NavBar/Inner/Row/ScoreWell
@onready var _score: Label = $Root/Safe/NavBar/Inner/Row/ScoreWell/Margin/Score
@onready var _progress_well: PanelContainer = $Root/Safe/NavBar/Inner/Row/ProgressWell
@onready var _progress_bar: ProgressBar = $Root/Safe/NavBar/Inner/Row/ProgressWell/Margin/ProgressBar
@onready var _menu_btn: Button = $Root/Safe/NavBar/Inner/Row/MenuButton
@onready var _combo: Label = $Root/Safe/ComboLabel
@onready var _next_chip: PanelContainer = $Root/Safe/BottomBar/NextChip
@onready var _next_label: Label = $Root/Safe/BottomBar/NextChip/Margin/Row/NextLabel
@onready var _swatch: Control = $Root/Safe/BottomBar/NextChip/Margin/Row/WormSwatch
@onready var _status: Label = $Root/Safe/StatusLabel
@onready var _gauntlet_banner: Label = $Root/Safe/GauntletBanner if has_node("Root/Safe/GauntletBanner") else null

const WELL_GREEN := Color(0.08, 0.22, 0.12, 0.96)
const WELL_RED := Color(0.42, 0.10, 0.08, 0.96)
const WELL_BLACK := Color(0.05, 0.05, 0.05, 0.96)
const GOLD := Color(1.0, 0.90, 0.38)
const EMBER := Color(0.72, 0.28, 0.08)
const EMBER_HOT := Color(1.0, 0.55, 0.12)
const EMBER_EDGE := Color(1.0, 0.82, 0.28)

var _total_worms: int = 0
var _worms_cleared: int = 0
var _danger_urgency: float = 0.0
var _danger_pulse: float = 0.0
var _pending_gauntlet_banner: bool = false
var _gauntlet_banner_tween: Tween
var _stage_index_display: int = 1
var _level_number_display: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style_navbar(false)
	_menu_btn.pressed.connect(_on_pause)
	EventBus.score_changed.connect(_on_score)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.lives_changed.connect(_on_lives)
	EventBus.level_started.connect(_on_level_started)
	EventBus.game_state_changed.connect(_on_state)
	EventBus.cascade_step.connect(_on_cascade)
	EventBus.shot_resolve_finished.connect(_on_shot_resolved)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.chicken_loadout_changed.connect(_on_loadout)
	EventBus.danger_warning.connect(_on_danger)
	EventBus.chain_worms_removed.connect(_on_worms_removed)
	EventBus.gauntlet_run_started.connect(_on_gauntlet_run_started)
	_on_combo(0)
	if _gauntlet_banner:
		_gauntlet_banner.visible = false
		UITheme.apply_font(_gauntlet_banner, UITheme.WEIGHT_BOLD)
		_gauntlet_banner.add_theme_font_size_override("font_size", 56)
		_gauntlet_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1.0))
		_gauntlet_banner.add_theme_color_override("font_outline_color", Color(0.35, 0.08, 0.02, 0.95))
		_gauntlet_banner.add_theme_constant_override("outline_size", 12)
		_gauntlet_banner.text = "GAUNTLET"


func _process(_delta: float) -> void:
	if _danger_urgency > 0.0:
		_danger_pulse = sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
		_status.modulate.a = 0.15 + _danger_urgency * 0.55 + _danger_pulse * _danger_urgency * 0.30


func _apply_run_theme() -> void:
	_style_navbar(GameManager.is_gauntlet_run)


func _inset(fill: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0.45)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


func _style_navbar(gauntlet: bool) -> void:
	if _navbar and _navbar.has_method("set_ember"):
		_navbar.set_ember(gauntlet)

	var green := WELL_GREEN if not gauntlet else Color(0.22, 0.10, 0.04, 0.96)
	var red := WELL_RED if not gauntlet else Color(0.55, 0.16, 0.06, 0.96)
	var black := WELL_BLACK if not gauntlet else Color(0.08, 0.03, 0.01, 0.96)
	var gold := GOLD if not gauntlet else Color(1.0, 0.88, 0.4)

	_lives_well.add_theme_stylebox_override("panel", _inset(green, 8))
	_level_well.add_theme_stylebox_override("panel", _inset(red, 16, Color(0.7, 0.2, 0.1, 0.7)))
	_score_well.add_theme_stylebox_override("panel", _inset(black, 8))
	_progress_well.add_theme_stylebox_override("panel", _inset(red, 16, Color(0.7, 0.2, 0.1, 0.7)))

	UITheme.apply_font(_lives, UITheme.WEIGHT_BOLD)
	_lives.add_theme_font_size_override("font_size", 18)
	_lives.add_theme_color_override("font_color", gold)
	_lives.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_level, UITheme.WEIGHT_BOLD)
	_level.add_theme_font_size_override("font_size", 18)
	_level.add_theme_color_override("font_color", gold)
	_level.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02, 0.9))
	_level.add_theme_constant_override("outline_size", 3)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_score, UITheme.WEIGHT_BOLD)
	_score.add_theme_font_size_override("font_size", 26)
	_score.add_theme_color_override("font_color", gold)
	_score.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.95))
	_score.add_theme_constant_override("outline_size", 4)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Progress bar fill
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.04, 0.03, 0.9)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = gold if not gauntlet else EMBER_HOT
	fill.set_corner_radius_all(8)
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", bg)
	_progress_bar.add_theme_stylebox_override("fill", fill)

	# MENU button (green well / ember well)
	var menu_fill := green
	var menu_n := _inset(menu_fill, 8)
	menu_n.set_border_width_all(0)
	var menu_h := menu_n.duplicate() as StyleBoxFlat
	menu_h.bg_color = menu_fill.lightened(0.12)
	_menu_btn.add_theme_stylebox_override("normal", menu_n)
	_menu_btn.add_theme_stylebox_override("hover", menu_h)
	_menu_btn.add_theme_stylebox_override("pressed", menu_h)
	_menu_btn.add_theme_stylebox_override("focus", menu_h)
	UITheme.apply_font(_menu_btn, UITheme.WEIGHT_BOLD)
	_menu_btn.text = "MENU"
	_menu_btn.add_theme_font_size_override("font_size", 20)
	_menu_btn.add_theme_color_override("font_color", gold)
	_menu_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.7, 1.0))
	_menu_btn.add_theme_color_override("font_pressed_color", gold)
	_menu_btn.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.85))
	_menu_btn.add_theme_constant_override("outline_size", 3)

	# Combo / status / next
	UITheme.apply_font(_combo, UITheme.WEIGHT_BOLD)
	_combo.add_theme_font_size_override("font_size", 22 if gauntlet else 20)
	_combo.add_theme_color_override("font_color", EMBER_HOT if gauntlet else UITheme.YOLK)
	_combo.add_theme_constant_override("outline_size", 4)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_status, UITheme.WEIGHT_BOLD if gauntlet else UITheme.WEIGHT_SEMIBOLD)
	_status.add_theme_font_size_override("font_size", 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UITheme.DANGER)

	var next_fill := Color(0.08, 0.14, 0.10, 0.94) if not gauntlet else Color(0.14, 0.06, 0.02, 0.94)
	var next_edge := Color(0.35, 0.55, 0.38, 0.55) if not gauntlet else EMBER_EDGE
	_next_chip.add_theme_stylebox_override("panel", _inset(next_fill, 14, next_edge))
	UITheme.apply_font(_next_label, UITheme.WEIGHT_BOLD)
	_next_label.add_theme_font_size_override("font_size", 14)
	_next_label.add_theme_color_override("font_color", gold if gauntlet else UITheme.CREAM_DIM)
	_next_label.text = "NEXT"


func _on_state(_prev: int, next: int) -> void:
	var show: bool = (
		next == GameManager.State.PLAYING
		or next == GameManager.State.PAUSED
	)
	if show and not visible:
		_apply_run_theme()
		visible = true
		_root.modulate.a = 0.0
		UIFx.fade_in(_root, 0.28)
		if _pending_gauntlet_banner or GameManager.is_gauntlet_run:
			_pending_gauntlet_banner = false
			call_deferred("_show_gauntlet_banner")
	elif not show:
		visible = false
		_hide_gauntlet_banner_immediate()


func _on_gauntlet_run_started() -> void:
	_pending_gauntlet_banner = true


func _show_gauntlet_banner() -> void:
	if _gauntlet_banner == null or not visible or not GameManager.is_gauntlet_run:
		return
	if _gauntlet_banner_tween != null:
		_gauntlet_banner_tween.kill()
	_gauntlet_banner.visible = true
	_gauntlet_banner.modulate.a = 0.0
	_gauntlet_banner.scale = Vector2(0.55, 0.55)
	_gauntlet_banner.pivot_offset = _gauntlet_banner.size * 0.5
	_gauntlet_banner_tween = create_tween()
	_gauntlet_banner_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gauntlet_banner_tween.tween_property(_gauntlet_banner, "modulate:a", 1.0, 0.2)
	_gauntlet_banner_tween.parallel().tween_property(_gauntlet_banner, "scale", Vector2(1.08, 1.08), 0.28)
	_gauntlet_banner_tween.tween_property(_gauntlet_banner, "scale", Vector2.ONE, 0.12)
	_gauntlet_banner_tween.tween_interval(1.0)
	_gauntlet_banner_tween.tween_property(_gauntlet_banner, "modulate:a", 0.0, 0.4)
	_gauntlet_banner_tween.tween_callback(func() -> void:
		if _gauntlet_banner:
			_gauntlet_banner.visible = false
	)


func _hide_gauntlet_banner_immediate() -> void:
	_pending_gauntlet_banner = false
	if _gauntlet_banner_tween != null:
		_gauntlet_banner_tween.kill()
		_gauntlet_banner_tween = null
	if _gauntlet_banner:
		_gauntlet_banner.visible = false
		_gauntlet_banner.modulate.a = 1.0
		_gauntlet_banner.scale = Vector2.ONE


func _on_score(new_score: int, delta: int) -> void:
	_score.text = _format_score(new_score)
	if delta > 0:
		UIFx.pulse_label(_score_well)


func _format_score(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _on_combo(combo: int) -> void:
	if combo <= 0:
		var tween := create_tween()
		tween.tween_property(_combo, "modulate:a", 0.0, 0.18)
		return
	_combo.modulate.a = 1.0
	var mul: float = GameManager.get_combo_multiplier()
	if GameManager.is_gauntlet_run:
		_combo.text = "⚔ COMBO ×%d  (%.1fx)" % [maxi(combo, 1), mul] if combo > 1 else "⚔ COMBO ×1"
	elif combo == 1:
		_combo.text = "COMBO ×1"
	else:
		_combo.text = "COMBO ×%d  (%.1fx)" % [combo, mul]
	var ramp_t: float = clampf(float(combo - 1) / 9.0, 0.0, 1.0)
	var combo_color: Color
	if GameManager.is_gauntlet_run:
		combo_color = Color(1.0, 0.85, 0.35).lerp(Color(1.0, 0.35, 0.1), ramp_t)
	elif ramp_t < 0.33:
		combo_color = UITheme.SUCCESS.lerp(UITheme.YOLK, ramp_t * 3.0)
	elif ramp_t < 0.66:
		combo_color = UITheme.YOLK.lerp(Color(1.0, 0.55, 0.15), (ramp_t - 0.33) * 3.0)
	else:
		combo_color = Color(1.0, 0.55, 0.15).lerp(UITheme.DANGER, (ramp_t - 0.66) * 3.0)
	_combo.add_theme_color_override("font_color", combo_color)
	UIFx.pulse_label(_combo)


func _on_lives(lives: int, max_lives: int) -> void:
	# Chicken icons for lives (Cluck & Worms twist on Zuma frogs).
	var icons: String = ""
	for i: int in range(max_lives):
		icons += "🐔" if i < lives else "·"
	_lives.text = icons


func _on_level_started(_id: StringName, _display_name: String) -> void:
	_apply_run_theme()
	_stage_index_display = GameManager.stage_index + 1
	_level_number_display = 1
	if GameManager.current_level_def:
		_level_number_display = GameManager.current_level_def.level_number
		_total_worms = GameManager.current_level_def.total_worms
	else:
		_total_worms = 0
	_worms_cleared = 0
	# Compact Zuma-style LVL stamp (stage-level within campaign numbering).
	var stage_part: int = _stage_index_display
	var level_in_stage: int = GameManager.level_index + 1
	if GameManager.is_gauntlet_run:
		_level.text = "G-%d" % _level_number_display
	else:
		_level.text = "LVL %d-%d" % [stage_part, level_in_stage]
	_status.text = ""
	_danger_urgency = 0.0
	_update_progress_bar()


func _on_worms_removed(_chain: WormChain, _index: int, count: int) -> void:
	_worms_cleared += count
	_update_progress_bar()


func _update_progress_bar() -> void:
	if _progress_bar == null:
		return
	_progress_bar.max_value = maxf(float(_total_worms), 1.0)
	_progress_bar.value = clampf(float(_worms_cleared), 0.0, _progress_bar.max_value)


func _on_loadout(_current: WormColor.Kind, next_color: WormColor.Kind) -> void:
	if _swatch and _swatch.has_method("set_color_kind"):
		_swatch.set_color_kind(next_color)
		UIFx.pulse_label(_next_chip)


func _on_cascade(_chain: WormChain, depth: int, count: int, color: WormColor.Kind) -> void:
	if depth <= 0:
		_status.text = "%s ×%d" % [WormColor.kind_name(color), count]
	else:
		_status.text = "✦ CASCADE %d!  %s ×%d" % [depth + 1, WormColor.kind_name(color), count]
	_status.add_theme_color_override(
		"font_color",
		EMBER_HOT if GameManager.is_gauntlet_run else (UITheme.YOLK_HOT if depth >= 1 else UITheme.SUCCESS)
	)
	_status.modulate.a = 1.0
	UIFx.pulse_label(_status)
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_status, "modulate:a", 0.0, 0.5)


func _on_shot_resolved(_chain: WormChain, scored: bool) -> void:
	if not scored and _danger_urgency <= 0.25:
		_status.text = "Combo reset"
		_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
		_status.modulate.a = 0.85
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(_status, "modulate:a", 0.0, 0.4)


func _on_life_lost(remaining: int) -> void:
	_status.text = "Life lost — %d left" % remaining
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	_status.modulate.a = 1.0


func _on_danger(urgency: float) -> void:
	_danger_urgency = urgency
	if urgency < 0.2:
		_danger_urgency = 0.0
		_status.text = ""
		_status.modulate.a = 0.0
		return
	var msg: String
	if urgency > 0.75:
		msg = "⚠ DANGER!" if not GameManager.is_gauntlet_run else "⚠ GAUNTLET BREAKING!"
	elif urgency > 0.45:
		msg = "Chain approaching…"
	else:
		msg = "Watch the pit…"
	_status.text = msg
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	_status.modulate.a = 1.0


func _on_pause() -> void:
	UIFx.punch_button(_menu_btn)
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.pause_game()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()
