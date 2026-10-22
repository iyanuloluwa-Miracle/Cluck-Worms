extends Control
## Volume, mute, and accessibility toggles — local only.

signal closed

@onready var _master: HSlider = $Safe/VBox/MasterRow/Slider
@onready var _sfx: HSlider = $Safe/VBox/SfxRow/Slider
@onready var _music: HSlider = $Safe/VBox/MusicRow/Slider
@onready var _mute: CheckButton = $Safe/VBox/Mute
@onready var _shake: CheckButton = $Safe/VBox/ReducedShake
@onready var _fx: CheckButton = $Safe/VBox/ReducedFx
@onready var _how_to: Button = $Safe/VBox/HowToPlayButton if has_node("Safe/VBox/HowToPlayButton") else null
@onready var _back: Button = $Safe/VBox/BackButton
@onready var _title: Label = $Safe/VBox/Title


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.text = "Settings"
	_shake.text = "Keep the camera still"
	_fx.text = "Reduced motion and effects"
	if _how_to:
		UITheme.apply_ghost_button(_how_to)
		_how_to.text = "How to Play"
		_how_to.pressed.connect(_on_how_to_play)
	UITheme.apply_ghost_button(_back)
	_back.text = "Back"
	_back.pressed.connect(_on_back)
	_load_from_save()
	_master.value_changed.connect(_on_changed)
	_sfx.value_changed.connect(_on_changed)
	_music.value_changed.connect(_on_changed)
	_mute.toggled.connect(func(_v: bool) -> void: _on_changed(0.0))
	_shake.toggled.connect(func(_v: bool) -> void: _on_changed(0.0))
	_fx.toggled.connect(func(_v: bool) -> void: _on_changed(0.0))


func open_settings() -> void:
	_load_from_save()
	visible = true
	UIFx.fade_in(self, 0.2)


func _load_from_save() -> void:
	_master.value = SaveService.master_volume
	_sfx.value = SaveService.sfx_volume
	_music.value = SaveService.music_volume
	_mute.button_pressed = SaveService.mute_all
	_shake.button_pressed = SaveService.reduced_shake
	_fx.button_pressed = SaveService.reduced_fx


func _on_changed(_v: float) -> void:
	SaveService.apply_settings(
		_master.value,
		_sfx.value,
		_music.value,
		_mute.button_pressed,
		_shake.button_pressed,
		_fx.button_pressed
	)
	EventBus.settings_changed.emit()


func _on_how_to_play() -> void:
	if _how_to:
		UIFx.punch_button(_how_to)
	var menu: Node = get_parent().get_node_or_null("MainMenuUI")
	var instructions: Node = menu.get_node_or_null("InstructionsUI") if menu else null
	if instructions and instructions.has_method("open_instructions"):
		visible = false
		instructions.open_instructions(false)
		if not instructions.closed.is_connected(_on_instructions_closed):
			instructions.closed.connect(_on_instructions_closed, CONNECT_ONE_SHOT)


func _on_instructions_closed() -> void:
	if GameManager.state == GameManager.State.MAIN_MENU:
		open_settings()


func _on_back() -> void:
	_on_changed(0.0)
	visible = false
	closed.emit()
