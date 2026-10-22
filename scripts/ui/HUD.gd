extends CanvasLayer
## In-run HUD with floating wells over a see-through top strip (Zuma-style).

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
var _boss_panel: PanelContainer
var _boss_label: Label
var _boss_bar: ProgressBar
var _boss_visible: bool = false
var _boss_status: Label
var _boss_fill: StyleBoxFlat
var _boss_name: String = "BOSS"
var _boss_phase: int = 1
var _boss_damage_ratio: float = 0.0
var _objective_ratio: float = 0.0
var _tracked_chain: WormChain
var _intro_box: VBoxContainer
var _intro_kicker: Label
var _intro_title: Label
var _intro_sub: Label
var _intro_tween: Tween
var _objective_label: Label
var _ability_row: HBoxContainer
var _slow_btn: Button
var _bomb_btn: Button
var _toast: Label
var _toast_tween: Tween
var _current_chip: PanelContainer
var _current_label: Label
var _current_swatch: Control
var _current_kind: WormColor.Kind = WormColor.Kind.RED
var _next_kind: WormColor.Kind = WormColor.Kind.RED
var _swap_btn: Button
var _guide_panel: PanelContainer
var _guide_label: Label
var _guide_skip: Button
var _guide_active: bool = false
var _guide_shot: bool = false
var _guide_swapped: bool = false
var _guide_matched: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style_navbar(false)
	_ensure_boss_hud()
	_menu_btn.pressed.connect(_on_pause)
	_menu_btn.focus_mode = Control.FOCUS_NONE
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
	EventBus.boss_introduced.connect(_on_boss_introduced)
	EventBus.boss_health_changed.connect(_on_boss_health)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_phase_changed.connect(_on_boss_phase)
	# Space swaps worms in play; a lingering focused button would swallow it.
	EventBus.game_state_changed.connect(func(_prev: int, next: int) -> void:
		if next == GameManager.State.PLAYING and is_inside_tree():
			get_viewport().gui_release_focus()
	)
	EventBus.boss_status_changed.connect(_on_boss_status)
	EventBus.chain_reversing.connect(_on_chain_reversing)
	EventBus.ability_charges_changed.connect(_on_ability_charges)
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.objective_progress_changed.connect(_on_objective_progress)
	EventBus.achievement_unlocked.connect(_on_achievement)
	EventBus.tutorial_step.connect(_on_tip)
	_ensure_meta_hud()
	_ensure_ammo_hud()
	_ensure_field_guide()
	EventBus.chicken_shot.connect(_on_guide_shot)
	EventBus.chicken_swapped.connect(_on_guide_swap)
	EventBus.chain_match_found.connect(_on_guide_match)
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
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

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
	_next_label.text = "NEXT\n%s" % WormColor.kind_name(_next_kind)


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
	if combo <= 1:
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


func _on_lives(lives: int, _max_lives: int) -> void:
	# Use supported text instead of platform-dependent emoji glyphs.
	_lives.text = "LIVES %d" % lives
	_lives_well.tooltip_text = "Lives remaining. Keep the chain away from the nest."


func _ensure_meta_hud() -> void:
	var safe: Control = $Root/Safe
	if _objective_label == null:
		_objective_label = Label.new()
		_objective_label.name = "ObjectiveLabel"
		_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_objective_label.offset_top = 72.0
		_objective_label.offset_bottom = 96.0
		_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_font(_objective_label, UITheme.WEIGHT_BOLD)
		_objective_label.add_theme_font_size_override("font_size", 15)
		_objective_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
		_objective_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.05, 0.85))
		_objective_label.add_theme_constant_override("outline_size", 4)
		_objective_label.visible = not _boss_visible
		safe.add_child(_objective_label)
	if _ability_row == null:
		_ability_row = HBoxContainer.new()
		_ability_row.name = "AbilityRow"
		_ability_row.mouse_filter = Control.MOUSE_FILTER_STOP
		_ability_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_ability_row.offset_left = 8.0
		_ability_row.offset_top = -52.0
		_ability_row.offset_right = 280.0
		_ability_row.offset_bottom = 0.0
		_ability_row.add_theme_constant_override("separation", 10)
		_slow_btn = _make_ability_button("SLOW [Q]", Color(0.25, 0.55, 0.85))
		_bomb_btn = _make_ability_button("BOMB [E]", Color(0.75, 0.28, 0.18))
		_slow_btn.tooltip_text = "Slow the chain for 3 seconds. Costs one charge. [Q]"
		_bomb_btn.tooltip_text = "Blast away a cluster of worms. Costs one charge. [E]"
		_slow_btn.pressed.connect(func() -> void: GameManager.try_use_slow_ability())
		_bomb_btn.pressed.connect(func() -> void: GameManager.try_use_bomb_ability())
		_ability_row.add_child(_slow_btn)
		_ability_row.add_child(_bomb_btn)
		safe.add_child(_ability_row)
	if _toast == null:
		_toast = Label.new()
		_toast.name = "AchievementToast"
		_toast.visible = false
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toast.offset_left = -220.0
		_toast.offset_right = 220.0
		_toast.offset_top = 140.0
		_toast.offset_bottom = 180.0
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_font(_toast, UITheme.WEIGHT_BOLD)
		_toast.add_theme_font_size_override("font_size", 22)
		_toast.add_theme_color_override("font_color", GOLD)
		_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
		_toast.add_theme_constant_override("outline_size", 6)
		safe.add_child(_toast)


func _make_ability_button(text: String, fill: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(124, 48)
	# Q / E trigger abilities; focusable buttons would steal Space (swap) after a click.
	btn.focus_mode = Control.FOCUS_NONE
	var n := _inset(fill, 10, Color(1, 1, 1, 0.35))
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = fill.lightened(0.15)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("disabled", _inset(fill.darkened(0.35), 10, Color(0, 0, 0, 0.35)))
	UITheme.apply_font(btn, UITheme.WEIGHT_BOLD)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	return btn


func _on_ability_charges(slow_c: int, bomb_c: int) -> void:
	_ensure_meta_hud()
	_slow_btn.text = "SLOW ×%d [Q]" % slow_c
	_bomb_btn.text = "BOMB ×%d [E]" % bomb_c
	_slow_btn.disabled = slow_c <= 0
	_bomb_btn.disabled = bomb_c <= 0


func _on_ability_used(ability_id: StringName) -> void:
	_status.text = "Used %s!" % String(ability_id).to_upper()
	_status.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_status.modulate.a = 1.0


func _on_objective_progress(label: String, _ratio: float) -> void:
	_ensure_meta_hud()
	if _objective_label:
		_objective_label.text = label
	_objective_ratio = _ratio
	_update_progress_bar()


func _on_achievement(id: StringName) -> void:
	_ensure_meta_hud()
	_toast.text = "★ %s" % AchievementCatalog.title(id)
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _on_tip(step_id: StringName) -> void:
	_status.text = String(step_id)
	_status.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	_status.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(_status, "modulate:a", 0.0, 0.5)


func _ensure_boss_hud() -> void:
	if _boss_panel != null:
		return
	var safe: Control = $Root/Safe
	_boss_panel = PanelContainer.new()
	_boss_panel.name = "BossPanel"
	_boss_panel.visible = false
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_panel.offset_left = 220.0
	_boss_panel.offset_right = -220.0
	# Compact strip above PathFactory.BOSS_TOP_SAFE; replaces the objective line.
	_boss_panel.offset_top = 70.0
	_boss_panel.offset_bottom = 118.0
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_boss_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	margin.add_child(vbox)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	_boss_label = Label.new()
	_boss_label.text = "BOSS"
	UITheme.apply_font(_boss_label, UITheme.WEIGHT_BOLD)
	_boss_label.add_theme_font_size_override("font_size", 15)
	_boss_label.add_theme_color_override("font_color", GOLD)
	row.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boss_bar.custom_minimum_size = Vector2(0, 14)
	_boss_bar.max_value = 100.0
	_boss_bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.04, 0.03, 0.92)
	bg.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.28, 0.18)
	fill.set_corner_radius_all(7)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_fill = fill
	row.add_child(_boss_bar)
	_boss_status = Label.new()
	_boss_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_font(_boss_status, UITheme.WEIGHT_BOLD)
	_boss_status.add_theme_font_size_override("font_size", 13)
	_boss_status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	vbox.add_child(_boss_status)
	_boss_panel.add_theme_stylebox_override("panel", _inset(Color(0.12, 0.06, 0.04, 0.92), 12, Color(0.85, 0.45, 0.15, 0.65)))
	safe.add_child(_boss_panel)


func _set_boss_hud_visible(show_boss: bool) -> void:
	_boss_visible = show_boss
	if _boss_panel:
		_boss_panel.visible = show_boss
	if _objective_label:
		_objective_label.visible = not show_boss and not _guide_active


func _on_boss_phase(_id: StringName, phase: int) -> void:
	_ensure_boss_hud()
	_boss_phase = phase
	_boss_label.text = "%s  ·  PHASE %d" % [_boss_name, phase] if phase > 1 else _boss_name


func _on_boss_status(_id: StringName, status: StringName, detail: String) -> void:
	_ensure_boss_hud()
	_boss_status.text = detail
	var col := Color(0.95, 0.9, 0.8)
	var bar_col := Color(0.92, 0.28, 0.18)
	match status:
		&"weak":
			col = Color(1.0, 0.95, 0.4)
			bar_col = Color(1.0, 0.78, 0.2)
		&"shielded":
			col = Color(0.65, 0.85, 1.0)
			bar_col = Color(0.45, 0.6, 0.85)
		&"attacking":
			col = Color(1.0, 0.5, 0.3)
	_boss_status.add_theme_color_override("font_color", col)
	if _boss_fill:
		_boss_fill.bg_color = bar_col


func _on_boss_introduced(_id: StringName, display_name: String) -> void:
	_ensure_boss_hud()
	_boss_name = display_name.to_upper()
	_boss_label.text = _boss_name
	_set_boss_hud_visible(true)
	_status.text = "%s approaches!" % display_name
	_status.add_theme_color_override("font_color", GOLD)
	_status.modulate.a = 1.0


func _on_boss_health(_id: StringName, current: float, maximum: float) -> void:
	_ensure_boss_hud()
	_boss_bar.max_value = maxf(maximum, 1.0)
	_boss_bar.value = clampf(current, 0.0, _boss_bar.max_value)
	_boss_damage_ratio = 1.0 - _boss_bar.value / _boss_bar.max_value
	_update_progress_bar()
	_set_boss_hud_visible(true)


func _on_boss_defeated(_id: StringName) -> void:
	_status.text = "Boss defeated!"
	_status.add_theme_color_override("font_color", UITheme.SUCCESS)
	_status.modulate.a = 1.0
	if _boss_bar:
		_boss_bar.value = 0.0


func _on_chain_reversing(_chain: WormChain) -> void:
	_status.text = "Chain reverse!"
	_status.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_status.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_status, "modulate:a", 0.0, 0.35)


func _on_level_started(_id: StringName, _display_name: String) -> void:
	_apply_run_theme()
	_stage_index_display = GameManager.stage_index + 1
	_level_number_display = 1
	var is_boss := false
	if GameManager.current_level_def:
		_level_number_display = GameManager.current_level_def.level_number
		_total_worms = GameManager.current_level_def.total_worms
		is_boss = GameManager.current_level_def.is_boss_level
	else:
		_total_worms = 0
	_worms_cleared = 0
	_objective_ratio = 0.0
	_tracked_chain = null
	if not is_boss:
		_boss_damage_ratio = 0.0
	# Boss signals can fire before level_started; only hide on non-boss levels.
	if not is_boss:
		_set_boss_hud_visible(false)
	# Compact Zuma-style LVL stamp (stage-level within campaign numbering).
	var stage_part: int = _stage_index_display
	var level_in_stage: int = GameManager.level_index + 1
	if GameManager.is_gauntlet_run:
		_level.text = "G-%d" % _level_number_display
	elif is_boss:
		_level.text = "BOSS %d" % stage_part
	else:
		_level.text = "LVL %d-%d" % [stage_part, level_in_stage]
	_status.text = ""
	_danger_urgency = 0.0
	_update_progress_bar()
	_begin_field_guide()
	if not is_boss and not _guide_active:
		_show_level_intro()


func _show_level_intro() -> void:
	var def: LevelData = GameManager.current_level_def
	if def == null:
		return
	_ensure_intro_banner()
	var stage: StageDef = GameManager.get_current_stage()
	var kicker: String
	var hold: float = 1.6
	if GameManager.is_gauntlet_run:
		kicker = "GAUNTLET"
	elif GameManager.level_index == 0 and stage != null:
		kicker = "STAGE %d  ·  %s" % [GameManager.stage_index + 1, stage.display_name.to_upper()]
		hold = 2.4
	else:
		kicker = "LEVEL %d-%d" % [GameManager.stage_index + 1, GameManager.level_index + 1]
	_intro_kicker.text = kicker
	_intro_title.text = def.display_name
	_intro_sub.text = LevelObjective.display_name(def.objective)
	if _intro_tween:
		_intro_tween.kill()
	_intro_box.modulate.a = 0.0
	_intro_box.pivot_offset = _intro_box.size * 0.5
	_intro_tween = _intro_box.create_tween()
	_intro_tween.tween_property(_intro_box, "modulate:a", 1.0, 0.25)
	_intro_tween.parallel().tween_property(_intro_box, "scale", Vector2.ONE, 0.35).from(Vector2.ONE if SaveService.reduced_fx else Vector2(0.85, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_interval(hold)
	_intro_tween.tween_property(_intro_box, "modulate:a", 0.0, 0.4)


func _ensure_intro_banner() -> void:
	if _intro_box != null:
		return
	_intro_box = VBoxContainer.new()
	_intro_box.name = "LevelIntro"
	_intro_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_intro_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_intro_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_intro_box.offset_top = -150.0
	_intro_box.offset_bottom = -40.0
	_intro_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_intro_box.add_theme_constant_override("separation", 0)
	_intro_kicker = _intro_label(20, Color(1.0, 0.8, 0.4))
	_intro_title = _intro_label(52, UITheme.YOLK_HOT)
	_intro_sub = _intro_label(18, UITheme.CREAM)
	_intro_box.modulate.a = 0.0
	$Root/Safe.add_child(_intro_box)


func _intro_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_font(l, UITheme.WEIGHT_BOLD)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.92))
	l.add_theme_constant_override("outline_size", maxi(5, font_size / 6))
	_intro_box.add_child(l)
	return l


func _on_worms_removed(chain: WormChain, _index: int, count: int) -> void:
	_tracked_chain = chain
	_worms_cleared += count
	_update_progress_bar()


func _update_progress_bar() -> void:
	if _progress_bar == null:
		return
	_progress_bar.max_value = 1.0
	_progress_bar.step = 0.0
	var ratio: float = _objective_ratio
	var def: LevelData = GameManager.current_level_def
	if def != null:
		match def.objective:
			LevelObjective.Kind.CLEAR_CHAIN, LevelObjective.Kind.LIMITED_SHOTS:
				# Inserts grow the chain, so measure against what's actually left.
				var remaining: int = _total_worms
				if _tracked_chain != null and is_instance_valid(_tracked_chain):
					remaining = _tracked_chain.get_worm_count() + _tracked_chain.spawns_remaining
				ratio = float(_worms_cleared) / maxf(float(_worms_cleared + remaining), 1.0)
			LevelObjective.Kind.DEFEAT_BOSS:
				ratio = _boss_damage_ratio
	_progress_bar.value = clampf(ratio, 0.0, 1.0)


func _on_loadout(current: WormColor.Kind, next_color: WormColor.Kind) -> void:
	_current_kind = current
	_next_kind = next_color
	_next_label.text = "NEXT\n%s" % WormColor.kind_name(next_color)
	if _current_swatch:
		_current_swatch.set_color_kind(current)
		_current_label.text = "NOW\n%s" % WormColor.kind_name(current)
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


func _ensure_ammo_hud() -> void:
	var dock: HBoxContainer = $Root/Safe/BottomBar
	dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dock.offset_left = -458.0
	dock.offset_right = -8.0
	dock.offset_top = -52.0
	dock.offset_bottom = 0.0
	dock.add_theme_constant_override("separation", 8)
	var margin: MarginContainer = _next_chip.get_node("Margin")
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	_current_chip = _next_chip.duplicate() as PanelContainer
	_current_chip.name = "CurrentChip"
	dock.add_child(_current_chip)
	dock.move_child(_current_chip, 0)
	_current_label = _current_chip.get_node("Margin/Row/NextLabel")
	_current_swatch = _current_chip.get_node("Margin/Row/WormSwatch")
	_current_chip.add_theme_stylebox_override("panel", _inset(Color(0.20, 0.23, 0.09), 12, GOLD))
	_current_label.text = "NOW\nRed"
	_current_label.add_theme_color_override("font_color", GOLD)
	_swap_btn = _make_ability_button("SWAP [SPACE]", Color(0.22, 0.32, 0.16))
	_swap_btn.tooltip_text = "Exchange your current and next worm. Also right-click or tap with a second finger."
	_swap_btn.pressed.connect(func() -> void: GameManager.try_swap_ammo())
	dock.add_child(_swap_btn)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 292.0
	_status.offset_right = 758.0
	_status.offset_top = -48.0
	_status.offset_bottom = -4.0
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)


func _ensure_field_guide() -> void:
	_guide_panel = PanelContainer.new()
	_guide_panel.name = "FieldGuide"
	_guide_panel.visible = false
	_guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_guide_panel.offset_left = 8.0
	_guide_panel.offset_right = -8.0
	_guide_panel.offset_top = 74.0
	_guide_panel.offset_bottom = 112.0
	_guide_panel.add_theme_stylebox_override("panel", _inset(Color(0.08, 0.16, 0.10, 0.98), 10, Color(0.65, 0.59, 0.25)))
	$Root/Safe.add_child(_guide_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_guide_panel.add_child(row)
	_guide_label = Label.new()
	_guide_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_font(_guide_label, UITheme.WEIGHT_BOLD)
	_guide_label.add_theme_font_size_override("font_size", 15)
	_guide_label.add_theme_color_override("font_color", UITheme.CREAM)
	row.add_child(_guide_label)
	_guide_skip = Button.new()
	_guide_skip.text = "SKIP"
	_guide_skip.focus_mode = Control.FOCUS_NONE
	_guide_skip.custom_minimum_size = Vector2(68, 30)
	UITheme.apply_font(_guide_skip, UITheme.WEIGHT_BOLD)
	_guide_skip.add_theme_font_size_override("font_size", 13)
	_guide_skip.pressed.connect(_skip_field_guide)
	row.add_child(_guide_skip)


func _begin_field_guide() -> void:
	_guide_active = not SaveService.field_guide_done and not GameManager.is_gauntlet_run and GameManager.challenge_mode == &"" and GameManager.stage_index == 0 and GameManager.level_index == 0
	_guide_shot = false
	_guide_swapped = false
	_guide_matched = false
	_guide_panel.visible = _guide_active
	_guide_skip.visible = true
	_objective_label.visible = not _boss_visible and not _guide_active
	_combo.visible = not _guide_active
	if _guide_active:
		_refresh_field_guide()


func _refresh_field_guide() -> void:
	if not _guide_active:
		return
	if not _guide_shot:
		_guide_label.text = "FIELD TRAINING  1 / 3     Aim at the chain and click to fire. On touch, tap where you want to shoot."
	elif not _guide_swapped:
		_guide_label.text = "FIELD TRAINING  2 / 3     Change your shot: press Space, right-click, or tap SWAP below."
	elif not _guide_matched:
		_guide_label.text = "FIELD TRAINING  3 / 3     Fire into a matching pair to make 3. The same symbols mark matching colors."
	else:
		_guide_active = false
		SaveService.set_field_guide_done()
		_guide_label.text = "TRAINING COMPLETE     Keep the nest safe! Q slows the chain. E blasts a cluster. Each uses one charge."
		_guide_skip.visible = false
		get_tree().create_timer(3.5, false).timeout.connect(func() -> void:
			if not _guide_active:
				_guide_panel.visible = false
				_objective_label.visible = not _boss_visible
				_combo.visible = true
		)


func _skip_field_guide() -> void:
	_guide_active = false
	SaveService.set_field_guide_done()
	_guide_panel.visible = false
	_objective_label.visible = not _boss_visible
	_combo.visible = true


func _on_guide_shot(_color: WormColor.Kind, _origin: Vector2, _direction: Vector2) -> void:
	if _guide_active:
		_guide_shot = true
		_refresh_field_guide()


func _on_guide_swap(_current: WormColor.Kind, _next: WormColor.Kind) -> void:
	if _guide_active:
		_guide_swapped = true
		_refresh_field_guide()


func _on_guide_match(_chain: WormChain, _start: int, _count: int, _color: WormColor.Kind) -> void:
	if _guide_active:
		_guide_matched = true
		_refresh_field_guide()
