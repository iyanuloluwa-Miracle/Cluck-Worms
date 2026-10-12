extends Control
## Premium title screen — brand hero, chicken mascot, high score, play CTA.

@onready var _backdrop: ColorRect = $Backdrop
@onready var _vignette: ColorRect = $Vignette
@onready var _content: Control = $SafeArea/Content
@onready var _mascot: Control = $SafeArea/Content/Mascot
@onready var _title: Label = $SafeArea/Content/Title
@onready var _tagline: Label = $SafeArea/Content/Tagline
@onready var _high_score_chip: PanelContainer = $SafeArea/Content/HighScoreChip
@onready var _high_score: Label = $SafeArea/Content/HighScoreChip/Margin/HighScore
@onready var _play_btn: Button = $SafeArea/Content/PlayButton
@onready var _campaign_btn: Button = $SafeArea/Content/CampaignButton
@onready var _settings_btn: Button = $SafeArea/Content/SettingsButton
@onready var _quit_btn: Button = $SafeArea/Content/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style()
	_play_btn.pressed.connect(_on_play)
	_campaign_btn.pressed.connect(_on_campaign)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)
	EventBus.high_score_changed.connect(_on_high_score)
	EventBus.game_state_changed.connect(_on_state)
	_refresh_high_score(SaveService.high_score)
	_on_state(-1, int(GameManager.state))


func _style() -> void:
	_backdrop.color = UITheme.MEADOW
	_vignette.color = Color(0.02, 0.06, 0.03, 0.35)
	UITheme.style_title(_title, UITheme.TITLE_SIZE)
	_title.text = "Cluck & Worms"
	UITheme.style_body(_tagline, UITheme.BODY_SIZE, true)
	_tagline.text = "Aim. Match. Cascade. Don't let them reach the pit."
	_high_score_chip.add_theme_stylebox_override(
		"panel", UITheme.chip_style(Color(0.08, 0.16, 0.11, 0.85))
	)
	UITheme.style_body(_high_score, UITheme.CAPTION_SIZE + 2, false)
	_high_score.add_theme_color_override("font_color", UITheme.YOLK)
	UITheme.apply_primary_button(_play_btn)
	_play_btn.text = "Play"
	UITheme.apply_ghost_button(_campaign_btn)
	_campaign_btn.text = "Campaign"
	UITheme.apply_ghost_button(_settings_btn)
	_settings_btn.text = "Settings"
	UITheme.apply_ghost_button(_quit_btn)
	_quit_btn.text = "Quit"


func _refresh_high_score(high: int) -> void:
	_high_score.text = "★  High Score  %d" % high


func _on_high_score(high: int, is_new: bool) -> void:
	_refresh_high_score(high)
	if is_new:
		UIFx.pulse_label(_high_score_chip)


func _on_state(_prev: int, next: int) -> void:
	var show: bool = next == GameManager.State.MAIN_MENU
	if show:
		visible = true
		modulate.a = 1.0
		_content.modulate.a = 0.0
		_content.scale = Vector2(0.96, 0.96)
		_content.pivot_offset = _content.size * 0.5
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_content, "modulate:a", 1.0, 0.35)
		tween.tween_property(_content, "scale", Vector2.ONE, 0.4)
		if _mascot:
			_mascot.modulate.a = 0.0
			tween.tween_property(_mascot, "modulate:a", 1.0, 0.45)
	else:
		if visible:
			UIFx.fade_out(self, 0.2)
		else:
			visible = false


func _on_play() -> void:
	# Continue from furthest unlocked level when possible.
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
	var sel: Node = get_parent().get_node_or_null("LevelSelectUI")
	if sel and sel.has_method("open_select"):
		sel.open_select()


func _on_settings() -> void:
	var settings: Node = get_parent().get_node_or_null("SettingsUI")
	if settings and settings.has_method("open_settings"):
		settings.open_settings()


func _on_quit() -> void:
	get_tree().quit()
