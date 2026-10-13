extends Control
## Large expressive title-screen chicken — hero visual, not a tiny icon.

@export var bob_amplitude: float = 8.0
@export var bob_speed: float = 2.0

var _time: float = 0.0
var _blink: float = 2.2
var _blinking: bool = false
var _blink_left: float = 0.0
var _peck: float = 0.0
var _peck_timer: float = 3.5


func _ready() -> void:
	custom_minimum_size = Vector2(280, 280)
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
			_blink = randf_range(1.8, 4.5)

	_peck_timer -= delta
	if _peck_timer <= 0.0:
		_peck = 1.0
		_peck_timer = randf_range(2.8, 5.5)
	_peck = maxf(_peck - delta * 4.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 280.0
	var cx: float = size.x * 0.48
	var cy: float = size.y * 0.52 + sin(_time * bob_speed) * bob_amplitude * s
	var origin := Vector2(cx, cy)
	var peck_nudge := Vector2(_peck * 10.0 * s, -_peck * 4.0 * s)

	# Soft ground shadow
	_fill_ellipse(origin + Vector2(2 * s, 78 * s), Vector2(70 * s, 18 * s), Color(0, 0, 0, 0.28))

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
		var ang: float = deg_to_rad(145.0 + float(i) * 28.0)
		var tip: Vector2 = origin + Vector2.from_angle(ang) * 72.0 * s + Vector2(-14 * s, -10 * s)
		var col: Color = tail_cols[i]
		draw_line(origin + Vector2(-34 * s, -4 * s), tip, col, (11.0 - float(i)) * s, true)
		draw_circle(tip, 7.5 * s, col)

	# Body
	_oval(origin, 58 * s, 48 * s, outline)
	_oval(origin, 53 * s, 44 * s, body)
	_oval(origin + Vector2(-4 * s, 12 * s), 26 * s, 18 * s, Color(1.0, 0.97, 0.82))

	# Wing flap
	var wing_y: float = sin(_time * 3.2) * 5.0 * s
	draw_colored_polygon(
		PackedVector2Array([
			origin + Vector2(-8 * s, 4 * s + wing_y),
			origin + Vector2(22 * s, 14 * s + wing_y),
			origin + Vector2(-4 * s, 34 * s + wing_y),
			origin + Vector2(-28 * s, 18 * s + wing_y),
		]),
		Color(0.95, 0.78, 0.28)
	)

	# Head
	var head: Vector2 = origin + Vector2(32 * s, -28 * s) + peck_nudge
	_oval(head, 32 * s, 28 * s, outline)
	_oval(head, 28 * s, 24 * s, body)

	# Comb
	for i: int in range(3):
		var c: Vector2 = head + Vector2((-12.0 + float(i) * 12.0) * s, -26.0 * s)
		draw_circle(c, 9.0 * s, comb)
		draw_circle(c + Vector2(0, -8 * s), 6.0 * s, comb)

	draw_circle(head + Vector2(6 * s, 18 * s), 7.0 * s, comb)

	# Beak
	var beak_pts := PackedVector2Array([
		head + Vector2(18 * s, -6 * s),
		head + Vector2((48 + _peck * 6.0) * s, 3 * s),
		head + Vector2(18 * s, 12 * s),
	])
	draw_colored_polygon(beak_pts, beak)

	# Eye
	var eye: Vector2 = head + Vector2(6 * s, -6 * s)
	if _blinking:
		draw_line(eye + Vector2(-8 * s, 0), eye + Vector2(8 * s, 0), Color(0.2, 0.15, 0.1), 3.5 * s, true)
	else:
		draw_circle(eye, 8.5 * s, Color.WHITE)
		draw_circle(eye + Vector2(2.2 * s, 0.8 * s), 3.6 * s, Color(0.12, 0.1, 0.08))
		draw_circle(eye + Vector2(0.6 * s, -1.5 * s), 1.6 * s, Color.WHITE)

	draw_circle(head + Vector2(4 * s, 10 * s), 6.0 * s, Color(1.0, 0.55, 0.45, 0.4))


func _oval(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(28):
		var a: float = TAU * float(i) / 28.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _fill_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	_oval(center, radii.x, radii.y, color)
