extends Node2D
## Procedural funny cartoon chicken. Beak faces local +X (aim direction).

const BODY_RADIUS_X: float = 30.0
const BODY_RADIUS_Y: float = 26.0
const HEAD_RADIUS: float = 18.0
const HEAD_OFFSET: Vector2 = Vector2(22.0, -10.0)
const BEAK_LENGTH: float = 16.0
const COMB_HEIGHT: float = 12.0
const WATTLE_SIZE: float = 6.0
const EYE_RADIUS: float = 4.5
const PUPIL_RADIUS: float = 2.2

var _wing_phase: float = 0.0
var _redraw_accum: float = 0.0


func _process(delta: float) -> void:
	var chicken: Chicken = get_parent().get_parent() as Chicken
	var flap: float = 8.0 if (chicken != null and chicken.is_celebrating()) else 3.0
	_wing_phase += delta * flap
	var interval: float = QualitySettings.chicken_redraw_interval
	if interval <= 0.0:
		queue_redraw()
		return
	_redraw_accum += delta
	if _redraw_accum >= interval:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	# Body -> AimPivot -> Chicken
	var chicken: Chicken = get_parent().get_parent() as Chicken
	var blinking: bool = chicken != null and chicken.is_blinking()
	var peck: float = chicken.get_peck_amount() if chicken else 0.0
	var celebrating: bool = chicken != null and chicken.is_celebrating()

	# Shadow
	draw_ellipse(Vector2(2.0, 28.0), Vector2(26.0, 8.0), Color(0.0, 0.0, 0.0, 0.22))

	# Body
	var body_fill := Color(1.0, 0.92, 0.45)
	var body_outline := Color(0.72, 0.48, 0.12)
	_draw_oval(Vector2.ZERO, BODY_RADIUS_X, BODY_RADIUS_Y, body_outline, 3.0)
	_draw_oval(Vector2.ZERO, BODY_RADIUS_X - 1.5, BODY_RADIUS_Y - 1.5, body_fill)

	# Belly
	_draw_oval(Vector2(-2.0, 6.0), 16.0, 12.0, Color(1.0, 0.97, 0.82))

	# Tail feathers
	var tail_cols: Array[Color] = [
		Color(0.95, 0.35, 0.25),
		Color(0.98, 0.75, 0.2),
		Color(0.9, 0.45, 0.15),
	]
	for i: int in range(3):
		var ang: float = deg_to_rad(150.0 + float(i) * 28.0)
		var tip: Vector2 = Vector2.from_angle(ang) * 34.0 + Vector2(-8.0, -4.0)
		draw_line(Vector2(-18.0, -2.0), tip, tail_cols[i], 6.0 - float(i), true)
		draw_circle(tip, 4.0, tail_cols[i])

	# Wing (subtle flap)
	var wing_y: float = sin(_wing_phase) * 3.0
	var wing_col := Color(0.95, 0.78, 0.28)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-6.0, 2.0 + wing_y),
			Vector2(10.0, 8.0 + wing_y),
			Vector2(-4.0, 18.0 + wing_y),
			Vector2(-16.0, 10.0 + wing_y),
		]),
		wing_col
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(-6.0, 2.0 + wing_y),
			Vector2(10.0, 8.0 + wing_y),
			Vector2(-4.0, 18.0 + wing_y),
			Vector2(-16.0, 10.0 + wing_y),
			Vector2(-6.0, 2.0 + wing_y),
		]),
		body_outline,
		2.0,
		true
	)

	# Head (nudges forward on peck / celebrate bounce)
	var head: Vector2 = HEAD_OFFSET + Vector2(peck * 6.0, -peck * 2.0)
	if celebrating:
		head += Vector2(0.0, -2.0)
	_draw_oval(head, HEAD_RADIUS + 1.5, HEAD_RADIUS + 1.0, body_outline)
	_draw_oval(head, HEAD_RADIUS, HEAD_RADIUS - 0.5, body_fill)

	# Comb
	var comb := Color(0.9, 0.2, 0.22)
	for i: int in range(3):
		var cx: float = head.x - 6.0 + float(i) * 7.0
		var cy: float = head.y - HEAD_RADIUS + 2.0
		draw_circle(Vector2(cx, cy - COMB_HEIGHT * 0.35), 5.0, comb)
		draw_circle(Vector2(cx, cy - COMB_HEIGHT * 0.7), 3.5, comb)

	# Wattle
	draw_circle(head + Vector2(4.0, 10.0), WATTLE_SIZE * 0.55, comb)
	draw_circle(head + Vector2(2.0, 14.0), WATTLE_SIZE * 0.4, comb)

	# Beak — clearly marks shoot direction (+X); opens slightly on peck
	var beak_open: float = peck * 3.0
	var beak_base: Vector2 = head + Vector2(HEAD_RADIUS - 2.0, 2.0)
	var beak_col := Color(1.0, 0.62, 0.15)
	var beak_outline := Color(0.75, 0.35, 0.05)
	var beak := PackedVector2Array([
		beak_base + Vector2(0.0, -6.0 - beak_open * 0.3),
		beak_base + Vector2(BEAK_LENGTH + peck * 2.0, 1.0),
		beak_base + Vector2(0.0, 7.0 + beak_open),
	])
	draw_colored_polygon(beak, beak_outline)
	var beak_inner := PackedVector2Array([
		beak_base + Vector2(1.0, -4.5),
		beak_base + Vector2(BEAK_LENGTH - 2.0 + peck * 2.0, 1.0),
		beak_base + Vector2(1.0, 5.5 + beak_open * 0.7),
	])
	draw_colored_polygon(beak_inner, beak_col)
	draw_line(
		beak_base + Vector2(2.0, -1.0),
		beak_base + Vector2(BEAK_LENGTH - 3.0 + peck * 2.0, 0.5),
		Color(1.0, 0.85, 0.45),
		1.5,
		true
	)

	# Eyes
	var eye_pos: Vector2 = head + Vector2(4.0, -4.0)
	if blinking:
		draw_line(
			eye_pos + Vector2(-5.0, 0.0),
			eye_pos + Vector2(5.0, 0.0),
			Color(0.25, 0.18, 0.1),
			2.5,
			true
		)
	else:
		draw_circle(eye_pos, EYE_RADIUS + 1.0, Color(0.2, 0.15, 0.1))
		draw_circle(eye_pos, EYE_RADIUS, Color.WHITE)
		var pupil: Vector2 = eye_pos + Vector2(1.6, 0.4)
		draw_circle(pupil, PUPIL_RADIUS, Color(0.12, 0.1, 0.08))
		draw_circle(pupil + Vector2(-0.8, -0.8), 0.9, Color.WHITE)

	# Cheek blush — brighter when celebrating
	var blush_a: float = 0.55 if celebrating else 0.35
	draw_circle(head + Vector2(2.0, 6.0), 3.5, Color(1.0, 0.55, 0.45, blush_a))


func _draw_oval(center: Vector2, radius_x: float, radius_y: float, color: Color, _pad: float = 0.0) -> void:
	var points := PackedVector2Array()
	var segments: int = 24
	for i: int in range(segments):
		var a: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(a) * radius_x, sin(a) * radius_y))
	draw_colored_polygon(points, color)


func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	_draw_oval(center, radii.x, radii.y, color)
