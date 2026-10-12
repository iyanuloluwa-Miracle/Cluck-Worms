extends Control
## Compact worm color preview for HUD "Next" slot.

var worm_color: WormColor.Kind = WormColor.Kind.RED:
	set(value):
		worm_color = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(52, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_color_kind(kind: WormColor.Kind) -> void:
	worm_color = kind


func _draw() -> void:
	var fill: Color = WormColor.get_fill(worm_color)
	var outline: Color = WormColor.get_outline(worm_color)
	var c := size * 0.5
	draw_circle(c + Vector2(-10, 0), 7, outline)
	draw_circle(c + Vector2(8, 0), 11, outline)
	draw_circle(c + Vector2(-10, 0), 5.5, fill)
	draw_circle(c + Vector2(8, 0), 9, fill)
	draw_circle(c + Vector2(10, -3), 3, WormColor.get_highlight(worm_color))
	draw_circle(c + Vector2(11, -1), 2, Color.WHITE)
	draw_circle(c + Vector2(12, -1), 1, Color(0.1, 0.1, 0.1))
