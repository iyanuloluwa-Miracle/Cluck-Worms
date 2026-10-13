extends CanvasLayer
## In-run HUD — score, lives, combo, next worm, worm progress, danger.
## Gauntlet runs get an ember challenge chrome distinct from Adventure.

@onready var _root: Control = $Root
@onready var _top_bar: HBoxContainer = $Root/Safe/TopBar
@onready var _score_chip: PanelContainer = $Root/Safe/TopBar/ScoreChip
@onready var _score: Label = $Root/Safe/TopBar/ScoreChip/Margin/Score
@onready var _mode_badge: PanelContainer = $Root/Safe/TopBar/ModeBadge if has_node("Root/Safe/TopBar/ModeBadge") else null
@onready var _mode_label: Label = $Root/Safe/TopBar/ModeBadge/Margin/ModeLabel if has_node("Root/Safe/TopBar/ModeBadge/Margin/ModeLabel") else null
@onready var _lives_chip: PanelContainer = $Root/Safe/TopBar/LivesChip
@onready var _lives: Label = $Root/Safe/TopBar/LivesChip/Margin/Lives
@onready var _pause_btn: Button = $Root/Safe/TopBar/PauseButton
@onready var _level: Label = $Root/Safe/LevelLabel
@onready var _combo: Label = $Root/Safe/ComboLabel
@onready var _next_chip: PanelContainer = $Root/Safe/BottomBar/NextChip
@onready var _next_label: Label = $Root/Safe/BottomBar/NextChip/Margin/Row/NextLabel
@onready var _swatch: Control = $Root/Safe/BottomBar/NextChip/Margin/Row/WormSwatch
@onready var _status: Label = $Root/Safe/StatusLabel
@onready var _progress_bar: ProgressBar = $Root/Safe/ProgressBar if has_node("Root/Safe/ProgressBar") else null
@onready var _gauntlet_banner: Label = $Root/Safe/GauntletBanner if has_node("Root/Safe/GauntletBanner") else null

const EMBER := Color(0.72, 0.28, 0.08)
const EMBER_HOT := Color(1.0, 0.55, 0.12)
const EMBER_EDGE := Color(1.0, 0.82, 0.28)
const EMBER_CHIP := Color(0.12, 0.06, 0.03, 0.92)
const MEADOW_CHIP := Color(0.06, 0.12, 0.08, 0.88)

var _total_worms: int = 0
var _worms_cleared: int = 0
var _danger_urgency: float = 0.0
var _danger_pulse: float = 0.0
var _pending_gauntlet_banner: bool = false
var _gauntlet_banner_tween: Tween
var _gauntlet_themed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style_adventure()
	_pause_btn.pressed.connect(_on_pause)
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
		var danger_alpha: float = 0.15 + _danger_urgency * 0.55 + _danger_pulse * _danger_urgency * 0.30
		_status.modulate.a = danger_alpha


func _apply_run_theme() -> void:
	if GameManager.is_gauntlet_run:
		_style_gauntlet()
	else:
		_style_adventure()


func _chip(fill: Color, edge: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


func _style_adventure() -> void:
	_gauntlet_themed = false
	if _mode_badge:
		_mode_badge.visible = false
	var chip := _chip(MEADOW_CHIP, Color(0.35, 0.55, 0.38, 0.55))
	_score_chip.add_theme_stylebox_override("panel", chip)
	_lives_chip.add_theme_stylebox_override("panel", chip.duplicate())
	_next_chip.add_theme_stylebox_override("panel", _chip(Color(0.08, 0.14, 0.10, 0.92), Color(0.35, 0.55, 0.38, 0.45)))
	UITheme.apply_font(_score, UITheme.WEIGHT_BOLD)
	_score.add_theme_font_size_override("font_size", 22)
	_score.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_score.add_theme_constant_override("outline_size", 3)
	UITheme.apply_font(_lives, UITheme.WEIGHT_BOLD)
	_lives.add_theme_font_size_override("font_size", 18)
	_lives.add_theme_color_override("font_color", Color(1.0, 0.68, 0.65))
	UITheme.apply_font(_level, UITheme.WEIGHT_SEMIBOLD)
	_level.add_theme_font_size_override("font_size", 14)
	_level.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_font(_combo, UITheme.WEIGHT_BOLD)
	_combo.add_theme_font_size_override("font_size", 20)
	_combo.add_theme_color_override("font_color", UITheme.YOLK)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_font(_status, UITheme.WEIGHT_SEMIBOLD)
	_status.add_theme_font_size_override("font_size", 15)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	UITheme.apply_font(_next_label, UITheme.WEIGHT_BOLD)
	_next_label.add_theme_font_size_override("font_size", 13)
	_next_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	_next_label.text = "NEXT"
	UITheme.apply_ghost_button(_pause_btn)
	_pause_btn.text = "Ⅱ"
	_pause_btn.custom_minimum_size = Vector2(UITheme.TOUCH_MIN, UITheme.TOUCH_MIN)
	_pause_btn.add_theme_font_size_override("font_size", 22)
	_style_progress(UITheme.YOLK_HOT, Color(0.04, 0.08, 0.05, 0.75))


func _style_gauntlet() -> void:
	_gauntlet_themed = true
	var chip := _chip(EMBER_CHIP, EMBER_EDGE, 16)
	chip.set_border_width_all(3)
	chip.shadow_color = Color(1.0, 0.35, 0.05, 0.4)
	chip.shadow_size = 10
	_score_chip.add_theme_stylebox_override("panel", chip)
	_lives_chip.add_theme_stylebox_override("panel", chip.duplicate())
	var next := _chip(Color(0.14, 0.06, 0.02, 0.94), EMBER_HOT, 16)
	next.set_border_width_all(3)
	_next_chip.add_theme_stylebox_override("panel", next)

	if _mode_badge and _mode_label:
		_mode_badge.visible = true
		var badge := _chip(EMBER, EMBER_EDGE, 12)
		badge.set_border_width_all(3)
		badge.shadow_color = Color(1.0, 0.4, 0.05, 0.5)
		badge.shadow_size = 8
		_mode_badge.add_theme_stylebox_override("panel", badge)
		UITheme.apply_font(_mode_label, UITheme.WEIGHT_BOLD)
		_mode_label.text = "GAUNTLET"
		_mode_label.add_theme_font_size_override("font_size", 14)
		_mode_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55, 1.0))
		_mode_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0, 0.9))
		_mode_label.add_theme_constant_override("outline_size", 3)

	UITheme.apply_font(_score, UITheme.WEIGHT_BOLD)
	_score.add_theme_font_size_override("font_size", 26)
	_score.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4, 1.0))
	_score.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.02, 0.95))
	_score.add_theme_constant_override("outline_size", 5)

	UITheme.apply_font(_lives, UITheme.WEIGHT_BOLD)
	_lives.add_theme_font_size_override("font_size", 20)
	_lives.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))

	UITheme.apply_font(_level, UITheme.WEIGHT_BOLD)
	_level.add_theme_font_size_override("font_size", 15)
	_level.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45, 0.95))
	_level.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02, 0.8))
	_level.add_theme_constant_override("outline_size", 3)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_combo, UITheme.WEIGHT_BOLD)
	_combo.add_theme_font_size_override("font_size", 22)
	_combo.add_theme_color_override("font_color", EMBER_HOT)
	_combo.add_theme_constant_override("outline_size", 4)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_status, UITheme.WEIGHT_BOLD)
	_status.add_theme_font_size_override("font_size", 17)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25, 1.0))

	UITheme.apply_font(_next_label, UITheme.WEIGHT_BOLD)
	_next_label.add_theme_font_size_override("font_size", 14)
	_next_label.add_theme_color_override("font_color", EMBER_EDGE)
	_next_label.text = "NEXT"

	# Ember pause button
	var pause_n := StyleBoxFlat.new()
	pause_n.bg_color = EMBER
	pause_n.border_color = EMBER_EDGE
	pause_n.set_border_width_all(3)
	pause_n.set_corner_radius_all(14)
	pause_n.shadow_color = Color(1.0, 0.35, 0.05, 0.4)
	pause_n.shadow_size = 8
	var pause_h := pause_n.duplicate() as StyleBoxFlat
	pause_h.bg_color = EMBER_HOT
	_pause_btn.add_theme_stylebox_override("normal", pause_n)
	_pause_btn.add_theme_stylebox_override("hover", pause_h)
	_pause_btn.add_theme_stylebox_override("pressed", pause_h)
	_pause_btn.add_theme_stylebox_override("focus", pause_h)
	UITheme.apply_font(_pause_btn, UITheme.WEIGHT_BOLD)
	_pause_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	_pause_btn.text = "Ⅱ"
	_pause_btn.custom_minimum_size = Vector2(UITheme.TOUCH_MIN, UITheme.TOUCH_MIN)
	_pause_btn.add_theme_font_size_override("font_size", 22)

	_style_progress(EMBER_HOT, Color(0.12, 0.05, 0.02, 0.85))
	if _progress_bar:
		_progress_bar.custom_minimum_size = Vector2(320, 12)


func _style_progress(fill_col: Color, bg_col: Color) -> void:
	if _progress_bar == null:
		return
	_progress_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(1)
	bg.border_color = Color(fill_col.r, fill_col.g, fill_col.b, 0.35)
	_progress_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(6)
	_progress_bar.add_theme_stylebox_override("fill", fill)


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
		_gauntlet_themed = false


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
		UIFx.pulse_label(_score_chip)


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
	else:
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
	var hearts: String = ""
	for i: int in range(max_lives):
		hearts += "♥" if i < lives else "♡"
	_lives.text = hearts


func _on_level_started(_id: StringName, display_name: String) -> void:
	_apply_run_theme()
	var stage: StageDef = GameManager.get_current_stage()
	var stage_name: String = stage.display_name if stage else "Stage"
	var num: int = 0
	if GameManager.current_level_def:
		num = GameManager.current_level_def.level_number
		_total_worms = GameManager.current_level_def.total_worms
	else:
		_total_worms = 0
	_worms_cleared = 0
	if GameManager.is_gauntlet_run:
		if num > 0:
			_level.text = "GAUNTLET  ·  L%d  %s" % [num, display_name]
		else:
			_level.text = "GAUNTLET  ·  %s" % display_name
	elif num > 0:
		_level.text = "%s  ·  L%d  %s" % [stage_name, num, display_name]
	else:
		_level.text = "%s  ·  %s" % [stage_name, display_name]
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
	UIFx.punch_button(_pause_btn)
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.pause_game()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()
