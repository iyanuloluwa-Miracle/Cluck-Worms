extends Control
## Full-bleed title-screen world: meadow sky, winding path, crawling worm beads.

var _time: float = 0.0
var _worm_phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	_worm_phase += delta * 0.22
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 4.0 or h < 4.0:
		return

	# Sky → meadow vertical wash (warm dawn, not flat).
	_draw_sky_gradient(w, h)

	# Soft sun disc + rays.
	var sun: Vector2 = Vector2(w * 0.82, h * 0.18)
	_draw_sun(sun)

	# Distant hill silhouettes.
	_draw_hills(w, h)

	# Winding play-path ribbon with crawling worm beads.
	_draw_path_and_worms(w, h)

	# Foreground grass fringe.
	_draw_grass(w, h)

	# Edge vignette for focus on brand/CTA.
	_draw_vignette(w, h)


func _draw_sky_gradient(w: float, h: float) -> void:
	var bands: int = 18
	for i: int in range(bands):
		var t: float = float(i) / float(bands - 1)
		var y0: float = h * t
		var y1: float = h * (float(i + 1) / float(bands - 1))
		var top := Color(0.45, 0.72, 0.92).lerp(Color(0.18, 0.42, 0.55), t * 0.45)
		var mid := Color(0.55, 0.78, 0.42).lerp(Color(0.12, 0.32, 0.18), t)
		var col: Color = top.lerp(mid, smoothstep(0.25, 0.75, t))
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), col)


func _draw_sun(sun: Vector2) -> void:
	var pulse: float = 1.0 + sin(_time * 1.4) * 0.04
	draw_circle(sun, 90.0 * pulse, Color(1.0, 0.92, 0.45, 0.12))
	draw_circle(sun, 54.0 * pulse, Color(1.0, 0.88, 0.35, 0.28))
	draw_circle(sun, 34.0 * pulse, Color(1.0, 0.95, 0.55, 0.85))
	for i: int in range(10):
		var a: float = _time * 0.15 + float(i) * TAU / 10.0
		var p0: Vector2 = sun + Vector2.from_angle(a) * 42.0
		var p1: Vector2 = sun + Vector2.from_angle(a) * (78.0 + sin(_time * 2.0 + i) * 6.0)
		draw_line(p0, p1, Color(1.0, 0.9, 0.4, 0.18), 3.0, true)


func _draw_hills(w: float, h: float) -> void:
	var hill1 := PackedVector2Array([
		Vector2(0, h * 0.62),
		Vector2(w * 0.18, h * 0.48),
		Vector2(w * 0.42, h * 0.55),
		Vector2(w * 0.7, h * 0.46),
		Vector2(w, h * 0.58),
		Vector2(w, h),
		Vector2(0, h),
	])
	draw_colored_polygon(hill1, Color(0.10, 0.28, 0.16, 0.85))
	var hill2 := PackedVector2Array([
		Vector2(0, h * 0.78),
		Vector2(w * 0.25, h * 0.68),
		Vector2(w * 0.55, h * 0.74),
		Vector2(w * 0.85, h * 0.66),
		Vector2(w, h * 0.72),
		Vector2(w, h),
		Vector2(0, h),
	])
	draw_colored_polygon(hill2, Color(0.08, 0.22, 0.13, 0.92))


func _draw_path_and_worms(w: float, h: float) -> void:
	var pts := PackedVector2Array()
	var samples: int = 48
	for i: int in range(samples + 1):
		var t: float = float(i) / float(samples)
		var x: float = lerpf(-40.0, w + 40.0, t)
		var y: float = h * 0.72 + sin(t * TAU * 1.35 + _time * 0.35) * h * 0.06
		y += cos(t * TAU * 0.7) * h * 0.03
		pts.append(Vector2(x, y))
	# Path bed
	draw_polyline(pts, Color(0.35, 0.22, 0.10, 0.55), 22.0, true)
	draw_polyline(pts, Color(0.55, 0.38, 0.18, 0.75), 14.0, true)
	draw_polyline(pts, Color(0.72, 0.52, 0.28, 0.35), 6.0, true)

	# Crawling worm beads along the path.
	var colors: Array[Color] = [
		Color(0.92, 0.22, 0.28),
		Color(0.20, 0.48, 0.95),
		Color(0.18, 0.78, 0.38),
		Color(0.98, 0.86, 0.16),
		Color(0.98, 0.52, 0.10),
	]
	var count: int = 14
	for i: int in range(count):
		var t: float = fposmod(_worm_phase + float(i) / float(count), 1.0)
		var idx: float = t * float(pts.size() - 1)
		var i0: int = clampi(int(idx), 0, pts.size() - 2)
		var frac: float = idx - float(i0)
		var pos: Vector2 = pts[i0].lerp(pts[i0 + 1], frac)
		var col: Color = colors[i % colors.size()]
		draw_circle(pos, 9.0, Color(0, 0, 0, 0.25))
		draw_circle(pos, 8.0, col.darkened(0.25))
		draw_circle(pos, 6.2, col)
		draw_circle(pos + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.45))


func _draw_grass(w: float, h: float) -> void:
	var base_y: float = h * 0.92
	for i: int in range(int(w / 14.0) + 2):
		var x: float = float(i) * 14.0 + fmod(_time * 8.0, 14.0)
		var sway: float = sin(_time * 2.2 + float(i) * 0.4) * 4.0
		var tip := Vector2(x + sway, base_y - 28.0 - float(i % 3) * 6.0)
		draw_line(Vector2(x, h), tip, Color(0.12, 0.38, 0.18, 0.75), 2.5, true)


func _draw_vignette(w: float, h: float) -> void:
	# Soft gradient darken at edges — keeps eyes on brand + CTA.
	var dark := Color(0.02, 0.05, 0.02, 0.35)
	var clear := Color(0.02, 0.05, 0.02, 0.0)
	var top_h: float = h * 0.14
	var bot_h: float = h * 0.24
	var side_w: float = w * 0.1
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, top_h), Vector2(0, top_h)]),
		PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w, h - bot_h), Vector2(0, h - bot_h)]),
		PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, h), Vector2(side_w, h), Vector2(side_w, 0)]),
		PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - side_w, h), Vector2(w - side_w, 0)]),
		PackedColorArray([dark, dark, clear, clear]))
