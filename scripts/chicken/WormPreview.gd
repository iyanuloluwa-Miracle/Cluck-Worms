extends Node2D
## Mini worm icon for current / next loadout display.

@export var preview_scale: float = 1.0
@export var show_label: bool = false

var _color: WormColor.Kind = WormColor.Kind.RED


func set_preview_color(color: WormColor.Kind) -> void:
	_color = color
	queue_redraw()


func _draw() -> void:
	var fill: Color = WormColor.get_fill(_color)
	var outline: Color = WormColor.get_outline(_color)
	var highlight: Color = WormColor.get_highlight(_color)
	var s: float = preview_scale

	draw_circle(Vector2(-8.0, 0.0) * s, 5.0 * s, outline)
	draw_circle(Vector2(6.0, 0.0) * s, 8.0 * s, outline)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-10.0, -4.0) * s,
			Vector2(4.0, -6.5) * s,
			Vector2(8.0, 0.0) * s,
			Vector2(4.0, 6.5) * s,
			Vector2(-10.0, 4.0) * s,
		]),
		outline
	)

	draw_circle(Vector2(-8.0, 0.0) * s, 3.8 * s, fill)
	draw_circle(Vector2(6.0, 0.0) * s, 6.5 * s, fill)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-8.0, -2.8) * s,
			Vector2(3.0, -5.0) * s,
			Vector2(6.0, 0.0) * s,
			Vector2(3.0, 5.0) * s,
			Vector2(-8.0, 2.8) * s,
		]),
		fill
	)
	draw_circle(Vector2(7.5, -2.5) * s, 2.5 * s, highlight)
	draw_circle(Vector2(8.5, -1.0) * s, 1.6 * s, Color.WHITE)
	draw_circle(Vector2(9.2, -1.0) * s, 0.8 * s, Color(0.1, 0.1, 0.1))
