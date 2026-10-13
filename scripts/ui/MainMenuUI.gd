extends Control
## Premium welcome screen — brand-first meadow composition with live atmosphere.

@onready var _atmosphere: Control = $Atmosphere
@onready var _root: Control = $SafeArea/Root
@onready var _brand: Control = $SafeArea/Root/BrandBlock
@onready var _mascot: Control = $SafeArea/Root/Mascot
@onready var _cta: Control = $SafeArea/Root/CTA
@onready var _title: Label = $SafeArea/Root/BrandBlock/Title
@onready var _tagline: Label = $SafeArea/Root/BrandBlock/Tagline
@onready var _high_score: Label = $SafeArea/Root/BrandBlock/HighScore
@onready var _play_btn: Button = $SafeArea/Root/CTA/PlayButton
@onready var _campaign_btn: Button = $SafeArea/Root/CTA/SecondaryRow/CampaignButton
@onready var _settings_btn: Button = $SafeArea/Root/CTA/SecondaryRow/SettingsButton
@onready var _quit_btn: Button = $SafeArea/Root/CTA/QuitButton

var _play_pulse: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style()
	_play_btn.pressed.connect(_on_play)
	_campaign_btn.pressed.connect(_on_campaign)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)
	_play_btn.button_down.connect(func() -> void: UIFx.punch_button(_play_btn))
	EventBus.high_score_changed.connect(_on_high_score)
	EventBus.game_state_changed.connect(_on_state)
	_refresh_high_score(SaveService.high_score)
	_on_state(-1, int(GameManager.state))


func _style() -> void:
	# Hero title — big yolk type with deep meadow outline.
	_title.text = "Cluck & Worms"
	_title.add_theme_font_size_override("font_size", 68)
	_title.add_theme_color_override("font_color", UITheme.YOLK_HOT)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.18, 0.10, 0.92))
	_title.add_theme_constant_override("outline_size", 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_tagline.text = "Aim. Match. Cascade."
	_tagline.add_theme_font_size_override("font_size", 20)
	_tagline.add_theme_color_override("font_color", Color(0.98, 0.97, 0.9, 0.92))
	_tagline.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.07, 0.65))
	_tagline.add_theme_constant_override("outline_size", 4)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_high_score.add_theme_font_size_override("font_size", 16)
	_high_score.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 0.9))
	_high_score.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.05, 0.55))
	_high_score.add_theme_constant_override("outline_size", 3)
	_high_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.apply_primary_button(_play_btn)
	_play_btn.text = "PLAY"
	_play_btn.add_theme_font_size_override("font_size", 26)
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
	UITheme.apply_ghost_button(_settings_btn)
	_settings_btn.text = "Settings"

	# Quit as quiet text action — not competing with Play.
	var quit_style := StyleBoxEmpty.new()
	_quit_btn.add_theme_stylebox_override("normal", quit_style)
	_quit_btn.add_theme_stylebox_override("hover", quit_style)
	_quit_btn.add_theme_stylebox_override("pressed", quit_style)
	_quit_btn.add_theme_stylebox_override("focus", quit_style)
	_quit_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_quit_btn.add_theme_color_override("font_hover_color", UITheme.YOLK_HOT)
	_quit_btn.add_theme_font_size_override("font_size", 16)
	_quit_btn.text = "Quit"
	_quit_btn.custom_minimum_size = Vector2(0, 36)


func _refresh_high_score(high: int) -> void:
	_high_score.text = "Best  %s" % _format_score(high)


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
	if is_new:
		UIFx.pulse_label(_high_score)


func _on_state(_prev: int, next: int) -> void:
	var show: bool = next == GameManager.State.MAIN_MENU
	if show:
		visible = true
		modulate.a = 1.0
		_play_entrance()
	else:
		_stop_play_pulse()
		if visible:
			UIFx.fade_out(self, 0.22)
		else:
			visible = false


func _play_entrance() -> void:
	# Staggered reveal: atmosphere already live; brand → mascot → CTA.
	_brand.modulate.a = 0.0
	_brand.scale = Vector2(0.94, 0.94)
	_brand.pivot_offset = Vector2(_brand.size.x * 0.5, 40.0)
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
	tween.tween_property(_mascot, "modulate:a", 1.0, 0.5).set_delay(0.1)
	tween.tween_property(_mascot, "scale", Vector2.ONE, 0.55).set_delay(0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_cta, "modulate:a", 1.0, 0.4).set_delay(0.2)
	tween.tween_property(_cta, "scale", Vector2.ONE, 0.45).set_delay(0.2)
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
