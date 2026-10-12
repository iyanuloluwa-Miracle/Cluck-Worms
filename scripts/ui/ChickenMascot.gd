extends Control
## Animated chicken mascot for the main menu — funny, readable, on-brand.

@export var bob_amplitude: float = 6.0
@export var bob_speed: float = 2.2

var _time: float = 0.0
var _blink: float = 2.5
var _blinking: bool = false
var _blink_left: float = 0.0
var _redraw_accum: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	_blink -= delta
	if _blink <= 0.0 and not _blinking:
		_blinking = true
		_blink_left = 0.1
	if _blinking:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_blinking = false
			_blink = randf_range(2.0, 5.0)
	var interval: float = QualitySettings.chicken_redraw_interval
	if interval <= 0.0:
		queue_redraw()
		return
	_redraw_accum += delta
	if _redraw_accum >= interval:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.55 + sin(_time * bob_speed) * bob_amplitude
	var origin := Vector2(cx, cy)

	# Soft ground shadow
	_fill_ellipse(origin + Vector2(0, 48), Vector2(42, 12), Color(0, 0, 0, 0.22))

	var body := Color(1.0, 0.92, 0.42)
	var outline := Color(0.72, 0.48, 0.12)
	var comb := Color(0.9, 0.22, 0.22)
	var beak := Color(1.0, 0.62, 0.15)

	# Tail
	var tail_cols: Array[Color] = [
		Color(0.95, 0.35, 0.25),
		Color(0.98, 0.75, 0.2),
		Color(0.9, 0.45, 0.15),
	]
	for i: int in range(3):
		var ang: float = deg_to_rad(140.0 + float(i) * 26.0)
		var tip: Vector2 = origin + Vector2.from_angle(ang) * 46.0 + Vector2(-10, -8)
		var col: Color = tail_cols[i]
		draw_line(origin + Vector2(-22, -4), tip, col, 7.0 - float(i), true)
		draw_circle(tip, 5.0, col)

	# Body
	_oval(origin, 36, 30, outline)
	_oval(origin, 33, 27, body)
	_oval(origin + Vector2(-2, 8), 16, 12, Color(1.0, 0.97, 0.82))

	# Wing
	var wing_y: float = sin(_time * 3.0) * 3.0
	draw_colored_polygon(
		PackedVector2Array([
			origin + Vector2(-4, 2 + wing_y),
			origin + Vector2(14, 10 + wing_y),
			origin + Vector2(-2, 22 + wing_y),
			origin + Vector2(-18, 12 + wing_y),
		]),
		Color(0.95, 0.78, 0.28)
	)

	# Head
	var head: Vector2 = origin + Vector2(20, -18)
	_oval(head, 20, 18, outline)
	_oval(head, 17, 15, body)

	# Comb
	for i: int in range(3):
		var c: Vector2 = head + Vector2(-8.0 + float(i) * 8.0, -16.0)
		draw_circle(c, 6.0, comb)
		draw_circle(c + Vector2(0, -6), 4.0, comb)

	# Wattle
	draw_circle(head + Vector2(4, 12), 5.0, comb)

	# Beak
	var beak_pts := PackedVector2Array([
		head + Vector2(12, -4),
		head + Vector2(32, 2),
		head + Vector2(12, 8),
	])
	draw_colored_polygon(beak_pts, beak)

	# Eye
	var eye: Vector2 = head + Vector2(4, -4)
	if _blinking:
		draw_line(eye + Vector2(-5, 0), eye + Vector2(5, 0), Color(0.2, 0.15, 0.1), 2.5, true)
	else:
		draw_circle(eye, 5.5, Color.WHITE)
		draw_circle(eye + Vector2(1.5, 0.5), 2.4, Color(0.12, 0.1, 0.08))
		draw_circle(eye + Vector2(0.4, -1.0), 1.0, Color.WHITE)

	# Blush
	draw_circle(head + Vector2(2, 6), 4.0, Color(1.0, 0.55, 0.45, 0.35))


func _oval(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _fill_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	_oval(center, radii.x, radii.y, color)
