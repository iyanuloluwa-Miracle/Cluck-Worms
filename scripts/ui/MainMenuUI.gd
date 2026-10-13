extends Control
## Premium welcome screen — brand-first meadow composition with live atmosphere.

@onready var _atmosphere: Control = $Atmosphere
@onready var _root: Control = $SafeArea/Root
@onready var _brand: Control = $SafeArea/Root/BrandBlock
@onready var _leaderboard: PanelContainer = $SafeArea/Root/Leaderboard
@onready var _board_header: Label = $SafeArea/Root/Leaderboard/Pad/Col/Header
@onready var _board_rows: VBoxContainer = $SafeArea/Root/Leaderboard/Pad/Col/Rows
@onready var _board_empty: Label = $SafeArea/Root/Leaderboard/Pad/Col/EmptyHint
@onready var _mascot: Control = $SafeArea/Root/Mascot
@onready var _cta: Control = $SafeArea/Root/CTA
@onready var _title: Label = $SafeArea/Root/BrandBlock/Title
@onready var _tagline: Label = $SafeArea/Root/BrandBlock/Tagline
@onready var _high_score: Label = $SafeArea/Root/BrandBlock/HighScore
@onready var _play_btn: Button = $SafeArea/Root/CTA/PlayButton
@onready var _campaign_btn: Button = $SafeArea/Root/CTA/SecondaryRow/CampaignButton
@onready var _settings_btn: Button = $SafeArea/Root/CTA/SecondaryRow/SettingsButton
@onready var _quit_btn: Button = $SafeArea/Root/CTA/QuitButton
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

var _play_pulse: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style()
	_play_btn.pressed.connect(_on_play)
	_campaign_btn.pressed.connect(_on_campaign)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)
	if _switch_btn:
		_switch_btn.pressed.connect(_on_switch_player)
	_play_btn.button_down.connect(func() -> void: UIFx.punch_button(_play_btn))
	EventBus.high_score_changed.connect(_on_high_score)
	EventBus.game_state_changed.connect(_on_state)
	EventBus.player_profile_changed.connect(_on_profile_changed)
	_refresh_high_score(SaveService.high_score)
	_refresh_leaderboard()
	_refresh_greeting()
	_on_state(-1, int(GameManager.state))


func _style() -> void:
	if _greeting_plaque:
		var plaque := UITheme.chip_style(Color(0.08, 0.16, 0.11, 0.82))
		plaque.border_color = Color(1.0, 0.88, 0.35, 0.22)
		plaque.set_border_width_all(2)
		plaque.content_margin_left = 0
		plaque.content_margin_right = 0
		plaque.content_margin_top = 0
		plaque.content_margin_bottom = 0
		_greeting_plaque.add_theme_stylebox_override("panel", plaque)

	# Hero title — thick Fredoka Bold with deep meadow outline.
	_title.text = "Cluck & Worms"
	UITheme.apply_font(_title, UITheme.WEIGHT_BOLD)
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.18, 0.10, 0.92))
	_title.add_theme_constant_override("outline_size", 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_tagline.text = "Aim. Match. Cascade."
	UITheme.apply_font(_tagline, UITheme.WEIGHT_SEMIBOLD)
	_tagline.add_theme_font_size_override("font_size", 22)
	_tagline.add_theme_color_override("font_color", Color(0.98, 0.97, 0.9, 0.95))
	_tagline.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.07, 0.7))
	_tagline.add_theme_constant_override("outline_size", 5)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_font(_high_score, UITheme.WEIGHT_BOLD)
	_high_score.add_theme_font_size_override("font_size", 18)
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

	UITheme.apply_primary_button(_play_btn)
	_play_btn.text = "PLAY"
	UITheme.apply_font(_play_btn, UITheme.WEIGHT_BOLD)
	_play_btn.add_theme_font_size_override("font_size", 28)
	_play_btn.custom_minimum_size = Vector2(0, 68)

	# Juicier primary button.
	var play_n := UITheme.button_normal()
	play_n.set_corner_radius_all(20)
	play_n.shadow_size = 10
	play_n.shadow_offset = Vector2(0, 5)
	play_n.content_margin_top = 16
	play_n.content_margin_bottom = 16
	var play_h := UITheme.button_hover()
	play_h.set_corner_radius_all(20)
	play_h.shadow_size = 12
	var play_p := UITheme.button_pressed()
	play_p.set_corner_radius_all(20)
	_play_btn.add_theme_stylebox_override("normal", play_n)
	_play_btn.add_theme_stylebox_override("hover", play_h)
	_play_btn.add_theme_stylebox_override("pressed", play_p)
	_play_btn.add_theme_stylebox_override("focus", play_h)

	UITheme.apply_ghost_button(_campaign_btn)
	_campaign_btn.text = "Campaign"
	UITheme.apply_font(_campaign_btn, UITheme.WEIGHT_BOLD)
	_campaign_btn.add_theme_font_size_override("font_size", 20)
	UITheme.apply_ghost_button(_settings_btn)
	_settings_btn.text = "Settings"
	UITheme.apply_font(_settings_btn, UITheme.WEIGHT_BOLD)
	_settings_btn.add_theme_font_size_override("font_size", 20)

	# Quit as quiet text action — not competing with Play.
	var quit_style := StyleBoxEmpty.new()
	_quit_btn.add_theme_stylebox_override("normal", quit_style)
	_quit_btn.add_theme_stylebox_override("hover", quit_style)
	_quit_btn.add_theme_stylebox_override("pressed", quit_style)
	_quit_btn.add_theme_stylebox_override("focus", quit_style)
	UITheme.apply_font(_quit_btn, UITheme.WEIGHT_SEMIBOLD)
	_quit_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_quit_btn.add_theme_color_override("font_hover_color", UITheme.YOLK_HOT)
	_quit_btn.add_theme_font_size_override("font_size", 16)
	_quit_btn.text = "Quit"
	_quit_btn.custom_minimum_size = Vector2(0, 36)


func _refresh_greeting() -> void:
	if _welcome_label:
		_welcome_label.text = "★ WELCOME TO CLUCK & WORMS! ★"
		UITheme.apply_font(_welcome_label, UITheme.WEIGHT_BOLD)
		_welcome_label.add_theme_font_size_override("font_size", 18)
		_welcome_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65, 0.98))
		_welcome_label.add_theme_color_override("font_outline_color", Color(0.06, 0.14, 0.07, 0.85))
		_welcome_label.add_theme_constant_override("outline_size", 4)
	if _switch_btn:
		_switch_btn.text = "(If you are not %s, click here to switch)" % SaveService.current_player_name
		UITheme.apply_font(_switch_btn, UITheme.WEIGHT_SEMIBOLD)
		_switch_btn.add_theme_font_size_override("font_size", 14)
		_switch_btn.add_theme_color_override("font_color", Color(0.85, 0.92, 0.82, 0.85))
		_switch_btn.add_theme_color_override("font_hover_color", UITheme.YOLK_HOT)


func _on_switch_player() -> void:
	if _switch_btn:
		UIFx.punch_button(_switch_btn)
	if _profile_dialog and _profile_dialog.has_method("open_dialog"):
		_profile_dialog.open_dialog()


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
		if visible:
			UIFx.fade_out(self, 0.22)
		else:
			visible = false


func _play_entrance() -> void:
	# Staggered reveal: atmosphere already live; brand → board → mascot → CTA.
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
	_cta.pivot_offset = Vector2(_cta.size.x * 0.5, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_brand, "modulate:a", 1.0, 0.42)
	tween.tween_property(_brand, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_leaderboard, "modulate:a", 1.0, 0.4).set_delay(0.08)
	tween.tween_property(_leaderboard, "scale", Vector2.ONE, 0.45).set_delay(0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_mascot, "modulate:a", 1.0, 0.5).set_delay(0.12)
	tween.tween_property(_mascot, "scale", Vector2.ONE, 0.55).set_delay(0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_cta, "modulate:a", 1.0, 0.4).set_delay(0.22)
	tween.tween_property(_cta, "scale", Vector2.ONE, 0.45).set_delay(0.22)
	tween.chain().tween_callback(_start_play_pulse)


func _start_play_pulse() -> void:
	_stop_play_pulse()
	if not is_instance_valid(_play_btn) or not visible:
		return
	_play_btn.pivot_offset = _play_btn.size * 0.5
	_play_pulse = create_tween()
	_play_pulse.set_loops()
	_play_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse.tween_property(_play_btn, "scale", Vector2(1.035, 1.035), 0.95)
	_play_pulse.tween_property(_play_btn, "scale", Vector2.ONE, 0.95)


func _stop_play_pulse() -> void:
	if _play_pulse != null:
		_play_pulse.kill()
		_play_pulse = null
	if is_instance_valid(_play_btn):
		_play_btn.scale = Vector2.ONE


func _on_play() -> void:
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


func _on_campaign() -> void:
	UIFx.punch_button(_campaign_btn)
	var sel: Node = get_parent().get_node_or_null("LevelSelectUI")
	if sel and sel.has_method("open_select"):
		# Hide title chrome so Campaign is the only screen.
		visible = false
		if not sel.closed.is_connected(_on_campaign_closed):
			sel.closed.connect(_on_campaign_closed)
		sel.open_select()


func _on_campaign_closed() -> void:
	if GameManager.state == GameManager.State.MAIN_MENU:
		visible = true
		modulate.a = 1.0
		_play_entrance()


func _on_settings() -> void:
	UIFx.punch_button(_settings_btn)
	var settings: Node = get_parent().get_node_or_null("SettingsUI")
	if settings and settings.has_method("open_settings"):
		settings.open_settings()


func _on_quit() -> void:
	get_tree().quit()
