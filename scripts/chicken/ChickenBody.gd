extends Node2D
## Procedural premium cartoon chicken. Beak faces local +X (aim direction).
## Richer anatomy: rounder body, feather detail, expressive eyes, dynamic comb.

const BODY_RADIUS_X: float = 32.0
const BODY_RADIUS_Y: float = 27.0
const HEAD_RADIUS: float = 19.0
const HEAD_OFFSET: Vector2 = Vector2(24.0, -11.0)
const BEAK_LENGTH: float = 17.0
const COMB_HEIGHT: float = 14.0
const WATTLE_SIZE: float = 7.0
const EYE_RADIUS: float = 5.0
const PUPIL_RADIUS: float = 2.5

var _wing_phase: float = 0.0
var _tail_phase: float = 0.0
var _redraw_accum: float = 0.0


func _process(delta: float) -> void:
	var chicken: Chicken = get_parent().get_parent() as Chicken
	var celebrating: bool = chicken != null and chicken.is_celebrating()
	var flap: float = 9.0 if celebrating else 3.5
	_wing_phase += delta * flap
	_tail_phase += delta * 1.8
	var interval: float = QualitySettings.chicken_redraw_interval
	if interval <= 0.0:
		queue_redraw()
		return
	_redraw_accum += delta
	if _redraw_accum >= interval:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	# Body → AimPivot → Chicken
	var chicken: Chicken = get_parent().get_parent() as Chicken
	var blinking: bool = chicken != null and chicken.is_blinking()
	var peck: float = chicken.get_peck_amount() if chicken else 0.0
	var celebrating: bool = chicken != null and chicken.is_celebrating()

	# --- Ground shadow ---
	_fill_ellipse(Vector2(2.0, 32.0), Vector2(30.0, 9.0), Color(0.0, 0.0, 0.0, 0.20))

	# --- Body gradient (outline + fill + inner highlight) ---
	var body_fill := Color(1.0, 0.92, 0.42)
	var body_highlight := Color(1.0, 0.98, 0.72)
	var body_outline := Color(0.68, 0.42, 0.10)
	var body_shadow := Color(0.88, 0.72, 0.28)

	# Outline
	_draw_oval(Vector2.ZERO, BODY_RADIUS_X + 2.5, BODY_RADIUS_Y + 2.0, body_outline)
	# Base fill
	_draw_oval(Vector2.ZERO, BODY_RADIUS_X, BODY_RADIUS_Y, body_fill)
	# Inner top highlight for roundness.
	_fill_ellipse(Vector2(-6.0, -10.0), Vector2(20.0, 11.0), Color(body_highlight.r, body_highlight.g, body_highlight.b, 0.48))
	# Bottom shading for depth.
	_fill_ellipse(Vector2(0.0, 14.0), Vector2(22.0, 9.0), Color(body_shadow.r, body_shadow.g, body_shadow.b, 0.4))

	# --- Belly patch ---
	_draw_oval(Vector2(-2.0, 8.0), 17.0, 13.0, Color(1.0, 0.98, 0.82))

	# --- Tail feathers (animated bob) ---
	var tail_cols: Array[Color] = [
		Color(0.95, 0.30, 0.22),
		Color(0.98, 0.72, 0.18),
		Color(0.88, 0.42, 0.12),
		Color(0.70, 0.22, 0.55),
	]
	for i: int in range(4):
		var tail_sway: float = sin(_tail_phase + float(i) * 0.7) * 2.5
		var ang: float = deg_to_rad(148.0 + float(i) * 22.0)
		var tip: Vector2 = Vector2.from_angle(ang) * (36.0 + float(i % 2) * 4.0) + Vector2(-10.0, -4.0 + tail_sway)
		var feather_w: float = 7.0 - float(i) * 1.2
		draw_line(Vector2(-20.0, -1.0), tip, tail_cols[i], feather_w, true)
		draw_circle(tip, feather_w * 0.55, tail_cols[i].lightened(0.12))
		# Feather tip shine.
		draw_circle(tip + Vector2(-1.0, -1.0), feather_w * 0.25, Color(1, 1, 1, 0.5))

	# --- Wing (animated flap with feather detail) ---
	var wing_y: float = sin(_wing_phase) * (5.0 if celebrating else 3.5)
	var wing_col := Color(0.96, 0.80, 0.30)
	var wing_outline_col := Color(0.65, 0.40, 0.08)
	var wing_pts := PackedVector2Array([
		Vector2(-8.0, 3.0 + wing_y),
		Vector2(12.0, 9.5 + wing_y),
		Vector2(6.0, 22.0 + wing_y),
		Vector2(-8.0, 20.0 + wing_y),
		Vector2(-18.0, 12.0 + wing_y),
	])
	draw_colored_polygon(wing_pts, wing_col)
	draw_polyline(PackedVector2Array([
		wing_pts[0], wing_pts[1], wing_pts[2], wing_pts[3], wing_pts[4], wing_pts[0],
	]), wing_outline_col, 2.0, true)
	# Wing feather lines.
	for wf: int in range(3):
		var wfp := Vector2(lerpf(-12.0, 6.0, float(wf) / 2.0), 18.0 + wing_y)
		draw_line(wfp, wfp + Vector2(8.0, -10.0), wing_col.darkened(0.15), 1.2, true)

	# --- Head (nudges forward on peck / celebrate bounce) ---
	var head: Vector2 = HEAD_OFFSET + Vector2(peck * 7.0, -peck * 2.5)
	if celebrating:
		head += Vector2(0.0, -3.0)
	# Head outline + fill.
	_draw_oval(head, HEAD_RADIUS + 2.0, HEAD_RADIUS + 1.5, body_outline)
	_draw_oval(head, HEAD_RADIUS, HEAD_RADIUS - 0.5, body_fill)
	# Head top highlight for roundness.
	_fill_ellipse(head + Vector2(-3.0, -7.0), Vector2(10.0, 6.0), Color(body_highlight.r, body_highlight.g, body_highlight.b, 0.52))

	# --- Comb (3 lobes with outline and highlight) ---
	var comb_col := Color(0.92, 0.18, 0.20)
	var comb_outline := Color(0.52, 0.06, 0.08)
	for i: int in range(3):
		var cx: float = head.x - 7.0 + float(i) * 7.5
		var cy: float = head.y - HEAD_RADIUS + 1.5
		var comb_offset: float = sin(_tail_phase * 1.2 + float(i) * 0.8) * (2.0 if celebrating else 0.8)
		# Lobe outline.
		draw_circle(Vector2(cx, cy - COMB_HEIGHT * 0.38 + comb_offset), 6.0, comb_outline)
		draw_circle(Vector2(cx, cy - COMB_HEIGHT * 0.75 + comb_offset), 4.0, comb_outline)
		# Lobe fill.
		draw_circle(Vector2(cx, cy - COMB_HEIGHT * 0.38 + comb_offset), 5.0, comb_col)
		draw_circle(Vector2(cx, cy - COMB_HEIGHT * 0.75 + comb_offset), 3.2, comb_col)
		# Lobe highlight.
		draw_circle(Vector2(cx - 1.5, cy - COMB_HEIGHT * 0.45 + comb_offset), 1.8, Color(1, 0.65, 0.65, 0.70))

	# --- Wattle (double teardrop) ---
	draw_circle(head + Vector2(5.0, 11.0), WATTLE_SIZE * 0.62, comb_outline)
	draw_circle(head + Vector2(3.5, 15.5), WATTLE_SIZE * 0.45, comb_outline)
	draw_circle(head + Vector2(5.0, 11.0), WATTLE_SIZE * 0.52, comb_col)
	draw_circle(head + Vector2(3.5, 15.5), WATTLE_SIZE * 0.36, comb_col)

	# --- Beak (opens on peck, clearly points +X) ---
	var beak_open: float = peck * 4.0
	var beak_base: Vector2 = head + Vector2(HEAD_RADIUS - 1.5, 2.0)
	var beak_col := Color(1.0, 0.65, 0.12)
	var beak_outline := Color(0.70, 0.30, 0.05)
	# Upper jaw.
	var upper_beak := PackedVector2Array([
		beak_base + Vector2(0.0, -7.5 - beak_open * 0.35),
		beak_base + Vector2(BEAK_LENGTH + peck * 2.5, 1.0),
		beak_base + Vector2(0.0, 1.5),
	])
	draw_colored_polygon(upper_beak, beak_outline)
	var upper_inner := PackedVector2Array([
		beak_base + Vector2(0.5, -5.5 - beak_open * 0.3),
		beak_base + Vector2(BEAK_LENGTH - 2.0 + peck * 2.5, 0.8),
		beak_base + Vector2(0.5, 0.8),
	])
	draw_colored_polygon(upper_inner, beak_col)
	# Lower jaw.
	if beak_open > 0.1:
		var lower_beak := PackedVector2Array([
			beak_base + Vector2(0.0, 2.5),
			beak_base + Vector2(BEAK_LENGTH * 0.8 + peck, 2.5 + beak_open),
			beak_base + Vector2(0.0, 8.5 + beak_open),
		])
		draw_colored_polygon(lower_beak, beak_outline)
		var lower_inner := PackedVector2Array([
			beak_base + Vector2(0.5, 3.2),
			beak_base + Vector2(BEAK_LENGTH * 0.75 + peck, 3.2 + beak_open * 0.7),
			beak_base + Vector2(0.5, 7.2 + beak_open * 0.8),
		])
		draw_colored_polygon(lower_inner, beak_col)
	# Beak highlight line.
	draw_line(
		beak_base + Vector2(1.5, -3.0),
		beak_base + Vector2(BEAK_LENGTH - 3.0 + peck * 2.0, -0.5),
		Color(1.0, 0.88, 0.55, 0.75),
		1.8,
		true
	)

	# --- Eyes ---
	var eye_pos: Vector2 = head + Vector2(5.0, -5.0)
	if blinking:
		# Squint line.
		draw_line(eye_pos + Vector2(-6.0, 1.0), eye_pos + Vector2(6.0, -1.0), Color(0.20, 0.14, 0.08), 3.0, true)
	else:
		# Eye socket.
		draw_circle(eye_pos, EYE_RADIUS + 1.5, Color(0.16, 0.10, 0.05))
		# Sclera.
		draw_circle(eye_pos, EYE_RADIUS, Color.WHITE)
		# Iris.
		draw_circle(eye_pos + Vector2(1.2, 0.5), EYE_RADIUS * 0.55, Color(0.22, 0.62, 0.30))
		# Pupil.
		var pupil: Vector2 = eye_pos + Vector2(1.8, 0.5)
		draw_circle(pupil, PUPIL_RADIUS, Color(0.08, 0.08, 0.08))
		# Eye shine (two points for liveliness).
		draw_circle(pupil + Vector2(-1.0, -1.2), 1.1, Color.WHITE)
		draw_circle(pupil + Vector2(1.2, 0.6), 0.6, Color(1, 1, 1, 0.65))

	# --- Cheek blush ---
	var blush_a: float = 0.65 if celebrating else 0.42
	var blush_size: float = 4.5 if celebrating else 3.8
	draw_circle(head + Vector2(1.5, 6.5), blush_size, Color(1.0, 0.52, 0.42, blush_a))

	# --- Celebration sparkle ring ---
	if celebrating:
		for sp: int in range(5):
			var sp_ang: float = _wing_phase * 2.0 + float(sp) * TAU / 5.0
			var sp_pos: Vector2 = head + Vector2.from_angle(sp_ang) * 24.0
			var sp_s: float = 1.8 + sin(_wing_phase * 3.0 + float(sp)) * 0.8
			draw_circle(sp_pos, sp_s, Color(1.0, 0.92, 0.3, 0.85))


func _draw_oval(center: Vector2, radius_x: float, radius_y: float, color: Color, _pad: float = 0.0) -> void:
	var points := PackedVector2Array()
	var segments: int = 28
	for i: int in range(segments):
		var a: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(a) * radius_x, sin(a) * radius_y))
	draw_colored_polygon(points, color)


func _fill_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	_draw_oval(center, radii.x, radii.y, color)
