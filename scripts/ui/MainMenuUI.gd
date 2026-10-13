extends Control
## Zuma-inspired welcome — greeting up top, stone tablet menu on the right.

@onready var _atmosphere: Control = $Atmosphere
@onready var _root: Control = $SafeArea/Root
@onready var _brand: Control = $SafeArea/Root/BrandBlock
@onready var _leaderboard: PanelContainer = $SafeArea/Root/Leaderboard
@onready var _board_header: Label = $SafeArea/Root/Leaderboard/Pad/Col/Header
@onready var _board_rows: VBoxContainer = $SafeArea/Root/Leaderboard/Pad/Col/Rows
@onready var _board_empty: Label = $SafeArea/Root/Leaderboard/Pad/Col/EmptyHint
@onready var _mascot: Control = $SafeArea/Root/Mascot
@onready var _cta: Control = $SafeArea/Root/CTA
@onready var _tagline: Label = $SafeArea/Root/BrandBlock/Tagline
@onready var _high_score: Label = $SafeArea/Root/BrandBlock/HighScore
@onready var _adventure_btn: Button = $SafeArea/Root/CTA/AdventureButton
@onready var _gauntlet_btn: Button = $SafeArea/Root/CTA/GauntletSlot/GauntletButton
@onready var _gauntlet_sub: Label = $SafeArea/Root/CTA/GauntletSlot/GauntletSubtitle
@onready var _options_btn: Button = $SafeArea/Root/CTA/OptionsButton
@onready var _howto_btn: Button = $SafeArea/Root/CTA/BottomRow/HowToPlayButton
@onready var _quit_btn: Button = $SafeArea/Root/CTA/BottomRow/QuitButton
@onready var _greeting_plaque: PanelContainer = $SafeArea/Root/BrandBlock/GreetingPlaque if has_node("SafeArea/Root/BrandBlock/GreetingPlaque") else null
@onready var _welcome_label: Label = (
	$SafeArea/Root/BrandBlock/GreetingPlaque/Margin/GreetingCol/WelcomeLabel
	if has_node("SafeArea/Root/BrandBlock/GreetingPlaque/Margin/GreetingCol/WelcomeLabel")
	else null
)
@onready var _switch_btn: Button = (
	$SafeArea/Root/BrandBlock/GreetingPlaque/Margin/GreetingCol/SwitchPlayerButton
	if has_node("SafeArea/Root/BrandBlock/GreetingPlaque/Margin/GreetingCol/SwitchPlayerButton")
	else null
)
@onready var _profile_dialog: Control = $PlayerProfileUI if has_node("PlayerProfileUI") else null
@onready var _instructions: Control = $InstructionsUI if has_node("InstructionsUI") else null

## Adventure = purple. Gauntlet = molten ember. Options/utility = teal.
const STONE_PURPLE := Color(0.48, 0.22, 0.55)
const STONE_PURPLE_HOT := Color(0.58, 0.30, 0.66)
const STONE_TEAL := Color(0.18, 0.48, 0.48)
const STONE_TEAL_HOT := Color(0.24, 0.58, 0.56)
const STONE_EMBER := Color(0.72, 0.28, 0.08)
const STONE_EMBER_HOT := Color(0.88, 0.42, 0.10)
const STONE_EMBER_EDGE := Color(1.0, 0.78, 0.28)
const STONE_EDGE := Color(0.72, 0.62, 0.28)
const STONE_GOLD := Color(1.0, 0.90, 0.42)

var _play_pulse: Tween
var _gauntlet_glow: Tween
var _gauntlet_styles: Array[StyleBoxFlat] = []
var _awaiting_instructions_after_profile: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style()
	_adventure_btn.pressed.connect(_on_adventure)
	_gauntlet_btn.pressed.connect(_on_gauntlet)
	_options_btn.pressed.connect(_on_settings)
	_howto_btn.pressed.connect(_on_howto)
	_quit_btn.pressed.connect(_on_quit)
	if _switch_btn:
		_switch_btn.pressed.connect(_on_switch_player)
	_adventure_btn.button_down.connect(func() -> void: UIFx.punch_button(_adventure_btn))
	EventBus.high_score_changed.connect(_on_high_score)
	EventBus.game_state_changed.connect(_on_state)
	EventBus.player_profile_changed.connect(_on_profile_changed)
	if _profile_dialog and _profile_dialog.has_signal("profile_confirmed"):
		_profile_dialog.profile_confirmed.connect(_on_profile_confirmed_for_instructions)
	_refresh_high_score(SaveService.high_score)
	_refresh_leaderboard()
	_refresh_greeting()
	_on_state(-1, int(GameManager.state))
	if not SaveService.profile_setup_done:
		_awaiting_instructions_after_profile = true
		call_deferred("_prompt_new_user")
	else:
		call_deferred("_maybe_show_instructions")


func _style() -> void:
	if _greeting_plaque:
		var plaque := StyleBoxFlat.new()
		plaque.bg_color = Color(0.08, 0.14, 0.10, 0.55)
		plaque.border_color = Color(1.0, 0.88, 0.35, 0.28)
		plaque.set_border_width_all(2)
		plaque.set_corner_radius_all(14)
		plaque.content_margin_left = 0
		plaque.content_margin_right = 0
		plaque.content_margin_top = 0
		plaque.content_margin_bottom = 0
		_greeting_plaque.add_theme_stylebox_override("panel", plaque)

	UITheme.apply_font(_tagline, UITheme.WEIGHT_SEMIBOLD)
	_tagline.add_theme_font_size_override("font_size", 18)
	_tagline.add_theme_color_override("font_color", Color(0.98, 0.97, 0.9, 0.88))
	_tagline.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.07, 0.65))
	_tagline.add_theme_constant_override("outline_size", 4)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_high_score, UITheme.WEIGHT_BOLD)
	_high_score.add_theme_font_size_override("font_size", 17)
	_high_score.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 0.95))
	_high_score.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.05, 0.6))
	_high_score.add_theme_constant_override("outline_size", 4)
	_high_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var board_style := UITheme.panel_style(Color(0.06, 0.14, 0.09, 0.72), Color(1.0, 0.88, 0.35, 0.28), 16.0)
	board_style.content_margin_left = 0
	board_style.content_margin_right = 0
	board_style.content_margin_top = 0
	board_style.content_margin_bottom = 0
	board_style.shadow_size = 8
	board_style.shadow_offset = Vector2(0, 4)
	board_style.shadow_color = Color(0, 0, 0, 0.35)
	_leaderboard.add_theme_stylebox_override("panel", board_style)

	_board_header.text = "LEADERBOARD"
	UITheme.apply_font(_board_header, UITheme.WEIGHT_BOLD)
	_board_header.add_theme_font_size_override("font_size", 16)
	_board_header.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_board_header.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.05, 0.7))
	_board_header.add_theme_constant_override("outline_size", 3)
	_board_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_board_empty, UITheme.WEIGHT_SEMIBOLD)
	_board_empty.add_theme_font_size_override("font_size", 13)
	_board_empty.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88, 0.65))
	_board_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Stone tablet stack — Adventure purple, Gauntlet ember, utility teal.
	_apply_stone_button(_adventure_btn, "ADVENTURE", STONE_PURPLE, STONE_PURPLE_HOT, 28, 72)
	_style_gauntlet_button()
	_apply_stone_button(_options_btn, "OPTIONS", STONE_TEAL, STONE_TEAL_HOT, 24, 64)
	_apply_stone_button(_howto_btn, "HOW TO PLAY", STONE_TEAL, STONE_TEAL_HOT, 15, 56)
	_apply_stone_button(_quit_btn, "QUIT", STONE_TEAL, STONE_TEAL_HOT, 15, 56)


func _style_gauntlet_button() -> void:
	_gauntlet_btn.text = "GAUNTLET"
	UITheme.apply_font(_gauntlet_btn, UITheme.WEIGHT_BOLD)
	_gauntlet_btn.add_theme_font_size_override("font_size", 26)
	_gauntlet_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55, 1.0))
	_gauntlet_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.78, 1.0))
	_gauntlet_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.82, 0.35, 1.0))
	_gauntlet_btn.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.02, 0.95))
	_gauntlet_btn.add_theme_constant_override("outline_size", 6)
	_gauntlet_btn.custom_minimum_size = Vector2(0, 76)

	_gauntlet_styles.clear()
	var n := _ember_style(STONE_EMBER, false, false)
	var h := _ember_style(STONE_EMBER_HOT, true, false)
	var p := _ember_style(STONE_EMBER.darkened(0.12), false, true)
	_gauntlet_styles.append(n)
	_gauntlet_styles.append(h)
	_gauntlet_styles.append(p)
	_gauntlet_btn.add_theme_stylebox_override("normal", n)
	_gauntlet_btn.add_theme_stylebox_override("hover", h)
	_gauntlet_btn.add_theme_stylebox_override("pressed", p)
	_gauntlet_btn.add_theme_stylebox_override("focus", h)

	_gauntlet_sub.text = "HIGH SCORE RUN"
	UITheme.apply_font(_gauntlet_sub, UITheme.WEIGHT_BOLD)
	_gauntlet_sub.add_theme_font_size_override("font_size", 12)
	_gauntlet_sub.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32, 0.95))
	_gauntlet_sub.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02, 0.8))
	_gauntlet_sub.add_theme_constant_override("outline_size", 2)
	_gauntlet_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ember_style(fill: Color, lit: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = STONE_EMBER_EDGE.lightened(0.2) if lit else STONE_EMBER_EDGE
	s.set_border_width_all(6)
	s.border_width_top = 8 if not pressed else 4
	s.border_width_bottom = 5 if not pressed else 7
	s.set_corner_radius_all(12)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14 if not pressed else 16
	s.content_margin_bottom = 14 if not pressed else 12
	s.shadow_color = Color(1.0, 0.4, 0.05, 0.45 if not pressed else 0.2)
	s.shadow_size = 16 if not pressed else 4
	s.shadow_offset = Vector2(0, 4 if not pressed else 1)
	return s


func _apply_stone_button(
	btn: Button,
	label: String,
	fill: Color,
	hover: Color,
	font_size: int,
	min_h: float
) -> void:
	btn.text = label
	UITheme.apply_font(btn, UITheme.WEIGHT_BOLD)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", STONE_GOLD)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.65, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.82, 0.3, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.02, 0.9))
	btn.add_theme_constant_override("outline_size", 5)
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.add_theme_stylebox_override("normal", _stone_style(fill))
	btn.add_theme_stylebox_override("hover", _stone_style(hover, true))
	btn.add_theme_stylebox_override("pressed", _stone_style(fill.darkened(0.12), false, true))
	btn.add_theme_stylebox_override("focus", _stone_style(hover, true))


func _stone_style(fill: Color, lit: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = STONE_EDGE.lightened(0.15) if lit else STONE_EDGE
	s.set_border_width_all(5)
	s.border_width_top = 6 if not pressed else 3
	s.border_width_bottom = 4 if not pressed else 6
	s.set_corner_radius_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12 if not pressed else 14
	s.content_margin_bottom = 12 if not pressed else 10
	s.shadow_color = Color(0, 0, 0, 0.4 if not pressed else 0.2)
	s.shadow_size = 10 if not pressed else 3
	s.shadow_offset = Vector2(0, 5 if not pressed else 1)
	return s


func _refresh_greeting() -> void:
	var pname: String = SaveService.current_player_name.to_upper()
	if _welcome_label:
		_welcome_label.text = "WELCOME TO CLUCK & WORMS, %s!" % pname
		UITheme.apply_font(_welcome_label, UITheme.WEIGHT_BOLD)
		_welcome_label.add_theme_font_size_override("font_size", 24)
		_welcome_label.add_theme_color_override("font_color", STONE_GOLD)
		_welcome_label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.04, 0.9))
		_welcome_label.add_theme_constant_override("outline_size", 5)
	if _switch_btn:
		_switch_btn.text = "(IF THIS IS NOT YOU, CLICK HERE.)"
		UITheme.apply_font(_switch_btn, UITheme.WEIGHT_SEMIBOLD)
		_switch_btn.add_theme_font_size_override("font_size", 13)
		_switch_btn.add_theme_color_override("font_color", Color(0.92, 0.95, 0.85, 0.88))
		_switch_btn.add_theme_color_override("font_hover_color", STONE_GOLD)
		_switch_btn.flat = true
		var empty := StyleBoxEmpty.new()
		_switch_btn.add_theme_stylebox_override("normal", empty)
		_switch_btn.add_theme_stylebox_override("hover", empty)
		_switch_btn.add_theme_stylebox_override("pressed", empty)
		_switch_btn.add_theme_stylebox_override("focus", empty)


func _prompt_new_user() -> void:
	if SaveService.profile_setup_done:
		_maybe_show_instructions()
		return
	if _profile_dialog and _profile_dialog.has_method("open_dialog"):
		_profile_dialog.open_dialog(true)


func _maybe_show_instructions() -> void:
	if not SaveService.profile_setup_done:
		return
	if SaveService.tutorial_done:
		return
	if _instructions and _instructions.has_method("open_instructions"):
		_instructions.open_instructions(true)


func _on_profile_confirmed_for_instructions(_player_name: String) -> void:
	if _awaiting_instructions_after_profile:
		_awaiting_instructions_after_profile = false
		call_deferred("_maybe_show_instructions")


func _on_switch_player() -> void:
	if _switch_btn:
		UIFx.punch_button(_switch_btn)
	if _profile_dialog and _profile_dialog.has_method("open_dialog"):
		_profile_dialog.open_dialog(false)


func _on_profile_changed(_player_name: String) -> void:
	_refresh_greeting()
	_refresh_leaderboard()


func _refresh_high_score(high: int) -> void:
	_high_score.text = "Best  %s" % _format_score(high)


func _refresh_leaderboard() -> void:
	for child: Node in _board_rows.get_children():
		child.queue_free()
	var entries: Array = SaveService.get_leaderboard()
	_board_empty.visible = entries.is_empty()
	for i: int in range(entries.size()):
		var entry: Dictionary = entries[i] as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var rank := Label.new()
		rank.custom_minimum_size = Vector2(28, 0)
		rank.text = "#%d" % (i + 1)
		UITheme.apply_font(rank, UITheme.WEIGHT_BOLD)
		rank.add_theme_font_size_override("font_size", 14)
		rank.add_theme_color_override("font_color", _rank_color(i))
		rank.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.05, 0.55))
		rank.add_theme_constant_override("outline_size", 2)
		var name_l := Label.new()
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.text = String(entry.get("name", "You"))
		UITheme.apply_font(name_l, UITheme.WEIGHT_SEMIBOLD)
		name_l.add_theme_font_size_override("font_size", 14)
		name_l.add_theme_color_override("font_color", Color(0.96, 0.97, 0.92, 0.92))
		var score_l := Label.new()
		score_l.text = _format_score(int(entry.get("score", 0)))
		UITheme.apply_font(score_l, UITheme.WEIGHT_BOLD)
		score_l.add_theme_font_size_override("font_size", 14)
		score_l.add_theme_color_override("font_color", UITheme.YOLK if i == 0 else Color(1.0, 0.92, 0.55, 0.88))
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rank)
		row.add_child(name_l)
		row.add_child(score_l)
		_board_rows.add_child(row)


func _rank_color(index: int) -> Color:
	match index:
		0:
			return UITheme.YOLK_HOT
		1:
			return Color(0.85, 0.88, 0.92, 0.95)
		2:
			return Color(0.92, 0.72, 0.42, 0.95)
		_:
			return Color(0.78, 0.88, 0.78, 0.75)


func _format_score(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var c: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		if c > 0 and c % 3 == 0:
			out = "," + out
		out = s[i] + out
		c += 1
	return out


func _on_high_score(high: int, is_new: bool) -> void:
	_refresh_high_score(high)
	_refresh_leaderboard()
	if is_new:
		UIFx.pulse_label(_high_score)


func _on_state(_prev: int, next: int) -> void:
	var show: bool = next == GameManager.State.MAIN_MENU
	if show:
		visible = true
		modulate.a = 1.0
		_refresh_leaderboard()
		_play_entrance()
	else:
		_stop_play_pulse()
		_stop_gauntlet_glow()
		if visible:
			UIFx.fade_out(self, 0.22)
		else:
			visible = false


func _play_entrance() -> void:
	_brand.modulate.a = 0.0
	_brand.scale = Vector2(0.94, 0.94)
	_brand.pivot_offset = Vector2(_brand.size.x * 0.5, 40.0)
	_leaderboard.modulate.a = 0.0
	_leaderboard.scale = Vector2(0.96, 0.96)
	_leaderboard.pivot_offset = Vector2(0.0, _leaderboard.size.y * 0.5)
	_mascot.modulate.a = 0.0
	_mascot.scale = Vector2(0.86, 0.86)
	_mascot.pivot_offset = _mascot.size * 0.5
	_cta.modulate.a = 0.0
	_cta.scale = Vector2(0.96, 0.96)
	_cta.pivot_offset = Vector2(_cta.size.x * 0.5, _cta.size.y * 0.5)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_brand, "modulate:a", 1.0, 0.42)
	tween.tween_property(_brand, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_leaderboard, "modulate:a", 1.0, 0.4).set_delay(0.08)
	tween.tween_property(_leaderboard, "scale", Vector2.ONE, 0.45).set_delay(0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_mascot, "modulate:a", 1.0, 0.5).set_delay(0.12)
	tween.tween_property(_mascot, "scale", Vector2.ONE, 0.55).set_delay(0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_cta, "modulate:a", 1.0, 0.4).set_delay(0.18)
	tween.tween_property(_cta, "scale", Vector2.ONE, 0.5).set_delay(0.18).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(_start_menu_pulses)


func _start_menu_pulses() -> void:
	_start_play_pulse()
	_start_gauntlet_glow()


func _start_play_pulse() -> void:
	_stop_play_pulse()
	if not is_instance_valid(_adventure_btn) or not visible:
		return
	_adventure_btn.pivot_offset = _adventure_btn.size * 0.5
	_play_pulse = create_tween()
	_play_pulse.set_loops()
	_play_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse.tween_property(_adventure_btn, "scale", Vector2(1.04, 1.04), 0.95)
	_play_pulse.tween_property(_adventure_btn, "scale", Vector2.ONE, 0.95)


func _stop_play_pulse() -> void:
	if _play_pulse != null:
		_play_pulse.kill()
		_play_pulse = null
	if is_instance_valid(_adventure_btn):
		_adventure_btn.scale = Vector2.ONE


func _start_gauntlet_glow() -> void:
	_stop_gauntlet_glow()
	if not is_instance_valid(_gauntlet_btn) or not visible:
		return
	_gauntlet_glow = create_tween()
	_gauntlet_glow.set_loops()
	_gauntlet_glow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gauntlet_glow.tween_method(_set_gauntlet_ember_glow, 0.0, 1.0, 1.1)
	_gauntlet_glow.tween_method(_set_gauntlet_ember_glow, 1.0, 0.0, 1.1)


func _stop_gauntlet_glow() -> void:
	if _gauntlet_glow != null:
		_gauntlet_glow.kill()
		_gauntlet_glow = null
	_set_gauntlet_ember_glow(0.0)
	if is_instance_valid(_gauntlet_btn):
		_gauntlet_btn.modulate = Color.WHITE
	if is_instance_valid(_gauntlet_sub):
		_gauntlet_sub.modulate = Color.WHITE


func _set_gauntlet_ember_glow(t: float) -> void:
	for s: StyleBoxFlat in _gauntlet_styles:
		s.shadow_color = Color(1.0, 0.42 + t * 0.2, 0.05, 0.35 + t * 0.4)
		s.shadow_size = int(14.0 + t * 12.0)
		s.border_color = STONE_EMBER_EDGE.lerp(Color(1.0, 0.95, 0.55), t * 0.55)
	if is_instance_valid(_gauntlet_btn):
		_gauntlet_btn.modulate = Color(1.0, 0.96 + t * 0.04, 0.9 + t * 0.08, 1.0)
	if is_instance_valid(_gauntlet_sub):
		_gauntlet_sub.modulate = Color(1.0, 0.9 + t * 0.1, 0.75 + t * 0.2, 1.0)


func _on_adventure() -> void:
	UIFx.punch_button(_adventure_btn)
	var sel: Node = get_parent().get_node_or_null("LevelSelectUI")
	if sel and sel.has_method("open_select"):
		visible = false
		if not sel.closed.is_connected(_on_campaign_closed):
			sel.closed.connect(_on_campaign_closed)
		sel.open_select()


func _on_gauntlet() -> void:
	UIFx.punch_button(_gauntlet_btn)
	EventBus.gauntlet_run_started.emit()
	# Jump into the highest unlocked level — arcade-style gauntlet run.
	var unlocked: int = SaveService.max_level_unlocked
	var stage_i: int = 0
	var level_i: int = 0
	if GameManager.catalog:
		for s: int in range(GameManager.catalog.get_stage_count()):
			var stage: StageDef = GameManager.catalog.get_stage(s)
			for l: int in range(stage.get_level_count()):
				var ld: LevelData = stage.get_level(l)
				if ld.level_number <= unlocked:
					stage_i = s
					level_i = l
	GameManager.start_run(stage_i, level_i)


func _on_campaign_closed() -> void:
	if GameManager.state == GameManager.State.MAIN_MENU:
		visible = true
		modulate.a = 1.0
		_play_entrance()


func _on_settings() -> void:
	UIFx.punch_button(_options_btn)
	var settings: Node = get_parent().get_node_or_null("SettingsUI")
	if settings and settings.has_method("open_settings"):
		settings.open_settings()


func _on_howto() -> void:
	UIFx.punch_button(_howto_btn)
	if _instructions and _instructions.has_method("open_instructions"):
		_instructions.open_instructions(false)


func _on_quit() -> void:
	get_tree().quit()
