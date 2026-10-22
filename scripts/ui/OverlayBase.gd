class_name OverlayBase
extends Control
## Modal overlays: dim backdrop, panel pop-in, EventBus-driven visibility.

@export var visible_state: int = -1

var _backdrop: ColorRect
var _panel: Control
var _showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0
	_backdrop = get_node_or_null("Backdrop") as ColorRect
	_panel = get_node_or_null("Center/Panel") as Control
	if _backdrop:
		_backdrop.color = UITheme.DIM
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel and _panel is PanelContainer:
		(_panel as PanelContainer).add_theme_stylebox_override("panel", UITheme.panel_style())
	EventBus.game_state_changed.connect(_on_state)


func _on_state(_prev: int, next: int) -> void:
	var should_show: bool = visible_state >= 0 and next == visible_state
	if should_show:
		show_overlay()
	else:
		hide_overlay()


func show_overlay() -> void:
	_showing = true
	visible = true
	modulate.a = 1.0
	if _panel:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2.ONE if SaveService.reduced_fx else Vector2(0.88, 0.88)
		# Wait one frame so size/pivot are valid on first show.
		await get_tree().process_frame
		if not _showing:
			return
		_panel.pivot_offset = _panel.size * 0.5
		UIFx.pop_in(_panel, 0.34)
	else:
		UIFx.fade_in(self, 0.25)
	focus_default()


## Keyboard / gamepad: focus the first visible, enabled button in the overlay.
func focus_default() -> void:
	var btn: Button = _first_button(_panel if _panel else self)
	if btn:
		btn.grab_focus()


func _first_button(root: Node) -> Button:
	for child: Node in root.get_children():
		if child is Button:
			var b := child as Button
			if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
				return b
		var nested: Button = _first_button(child)
		if nested:
			return nested
	return null


func hide_overlay() -> void:
	if not visible:
		_showing = false
		return
	_showing = false
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void:
		if not _showing:
			visible = false
			modulate.a = 1.0
	)
