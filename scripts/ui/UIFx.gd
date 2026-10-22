class_name UIFx
extends RefCounted
## Shared UI motion helpers — snappy, commercial casual feel.


static func punch_button(btn: Control) -> void:
	if btn == null or SaveService.reduced_fx:
		return
	btn.pivot_offset = btn.size * 0.5
	var tween := btn.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12)


static func fade_in(node: CanvasItem, duration: float = 0.28) -> Tween:
	node.modulate.a = 0.0
	node.visible = true
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	return tween


static func fade_out(node: CanvasItem, duration: float = 0.2) -> Tween:
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(func() -> void: node.visible = false)
	return tween


static func pop_in(node: Control, duration: float = 0.32) -> Tween:
	node.visible = true
	node.modulate.a = 0.0
	node.scale = Vector2.ONE if SaveService.reduced_fx else Vector2(0.86, 0.86)
	node.pivot_offset = node.size * 0.5
	# Size may be zero on first frame — defer pivot via delayed set.
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.7)
	tween.tween_property(node, "scale", Vector2.ONE, duration)
	return tween


static func slide_down_in(node: Control, from_y: float = -40.0, duration: float = 0.3) -> Tween:
	node.visible = true
	node.modulate.a = 0.0
	var target := node.position
	node.position = target if SaveService.reduced_fx else target + Vector2(0, from_y)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.8)
	tween.tween_property(node, "position", target, duration)
	return tween


static func pulse_label(label: Control) -> void:
	if label == null or SaveService.reduced_fx:
		return
	label.pivot_offset = label.size * 0.5
	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.1)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)
