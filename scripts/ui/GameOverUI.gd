extends OverlayBase
## Lives depleted — score + high score callout.

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _body: Label = $Center/Panel/VBox/Body
@onready var _retry: Button = $Center/Panel/VBox/RetryButton
@onready var _menu: Button = $Center/Panel/VBox/MenuButton
@onready var _continue_btn: Button = $Center/Panel/VBox/ContinueButton if has_node("Center/Panel/VBox/ContinueButton") else null


func _ready() -> void:
	visible_state = GameManager.State.GAME_OVER
	super._ready()
	UITheme.style_title(_title, UITheme.HEADING_SIZE)
	_title.add_theme_color_override("font_color", UITheme.DANGER)
	_title.text = "Game Over"
	UITheme.style_body(_body, UITheme.BODY_SIZE)
	UITheme.apply_primary_button(_retry)
	UITheme.apply_ghost_button(_menu)
	_retry.text = "Retry Level"
	_menu.text = "Main Menu"
	_ensure_continue_button()
	_retry.pressed.connect(func() -> void:
		UIFx.punch_button(_retry)
		# Restart the failed level with a fresh life pool (same stage/level).
		GameManager.restart_current_challenge()
	)
	_menu.pressed.connect(func() -> void:
		UIFx.punch_button(_menu)
		GameManager.go_to_main_menu()
	)
	EventBus.game_over.connect(_on_game_over)


func _ensure_continue_button() -> void:
	if _continue_btn == null:
		_continue_btn = Button.new()
		_continue_btn.name = "ContinueButton"
		var vbox: VBoxContainer = $Center/Panel/VBox
		vbox.add_child(_continue_btn)
		vbox.move_child(_continue_btn, _retry.get_index())
	UITheme.apply_primary_button(_continue_btn)
	_continue_btn.text = "Continue · ₦100"
	_continue_btn.visible = false
	if not _continue_btn.pressed.is_connected(_on_continue_pressed):
		_continue_btn.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	UIFx.punch_button(_continue_btn)
	_continue_btn.disabled = true
	var ok: bool = await VatarBridge.buy_extra_life()
	_continue_btn.disabled = false
	if not ok:
		_continue_btn.text = "Continue · try again"
		await get_tree().create_timer(1.2).timeout
		_continue_btn.text = "Continue · ₦100"


func _on_game_over(final_score: int, high_score: int, is_new_high: bool) -> void:
	var formatted_score: String = _format_score(final_score)
	var formatted_high: String = _format_score(high_score)
	if is_new_high:
		_body.add_theme_color_override("font_color", UITheme.YOLK_HOT)
		_body.text = "%s pts\n★ NEW BEST  ·  %s! ★" % [formatted_score, formatted_high]
		UIFx.pulse_label(_body)
	else:
		_body.add_theme_color_override("font_color", UITheme.CREAM)
		_body.text = "%s pts\nBest  ·  %s" % [formatted_score, formatted_high]
	if _continue_btn:
		_continue_btn.visible = VatarBridge != null and VatarBridge.is_available
		_continue_btn.text = "Continue · ₦100"
		_continue_btn.disabled = false


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
