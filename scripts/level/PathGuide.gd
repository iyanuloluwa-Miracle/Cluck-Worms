extends Node2D
## 10x Zuma-style carved physical track guide.
## Renders a multi-layered recessed trench carved into the terrain, dual guide rails,
## animated marching directional pearls, an earthen entry burrow, and a woven farmyard nest.

@export var path: Path2D
@export var sample_step: float = 6.0
@export var trench_outer_width: float = 52.0
@export var trench_floor_width: float = 34.0
@export var danger_zone_length: float = 160.0

var _danger_pulse: float = 0.0
var _danger_urgency: float = 0.0
var _anim_time: float = 0.0

# Cached point arrays for performance.
var _cached_curve_version: int = -1
var _cached_full_points: PackedVector2Array = PackedVector2Array()
var _cached_left_rail: PackedVector2Array = PackedVector2Array()
var _cached_right_rail: PackedVector2Array = PackedVector2Array()
var _cached_danger_points: PackedVector2Array = PackedVector2Array()
var _total_length: float = 0.0


func _ready() -> void:
	if path == null:
		path = get_parent().get_node_or_null("WormPath") as Path2D
	sample_step = QualitySettings.path_sample_step
	EventBus.danger_warning.connect(_on_danger)
	_rebuild_cache()
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta
	if _danger_urgency > 0.0:
		_danger_pulse = sin(_anim_time * (5.0 + _danger_urgency * 4.0)) * 0.5 + 0.5
	else:
		if _danger_pulse > 0.0:
			_danger_pulse = maxf(_danger_pulse - delta * 3.0, 0.0)
	queue_redraw()


func _on_danger(urgency: float) -> void:
	_danger_urgency = maxf(urgency, 0.0)
	if urgency <= 0.08:
		_danger_urgency = 0.0


func _rebuild_cache() -> void:
	_cached_full_points.clear()
	_cached_left_rail.clear()
	_cached_right_rail.clear()
	_cached_danger_points.clear()

	if path == null or path.curve == null:
		return

	var curve: Curve2D = path.curve
	_total_length = curve.get_baked_length()
	if _total_length <= 0.0:
		return

	var danger_start: float = maxf(_total_length - danger_zone_length, 0.0)
	var rail_offset: float = trench_floor_width * 0.42

	var d: float = 0.0
	while d <= _total_length:
		var xf: Transform2D = curve.sample_baked_with_rotation(d, false)
		var center_pt: Vector2 = _path_to_local(xf.origin)
		var forward: Vector2 = path.global_transform.basis_xform(xf.x).normalized()
		var normal: Vector2 = Vector2(-forward.y, forward.x)

		_cached_full_points.append(center_pt)
		_cached_left_rail.append(center_pt - normal * rail_offset)
		_cached_right_rail.append(center_pt + normal * rail_offset)

		if d >= danger_start:
			_cached_danger_points.append(center_pt)

		d += sample_step

	# Ensure endpoint is accurately captured.
	var end_xf: Transform2D = curve.sample_baked_with_rotation(_total_length, false)
	var end_pt: Vector2 = _path_to_local(end_xf.origin)
	if _cached_full_points.is_empty() or _cached_full_points[-1].distance_squared_to(end_pt) > 1.0:
		var end_fwd: Vector2 = path.global_transform.basis_xform(end_xf.x).normalized()
		var end_norm: Vector2 = Vector2(-end_fwd.y, end_fwd.x)
		_cached_full_points.append(end_pt)
		_cached_left_rail.append(end_pt - end_norm * rail_offset)
		_cached_right_rail.append(end_pt + end_norm * rail_offset)
		_cached_danger_points.append(end_pt)


func _draw() -> void:
	if path == null or path.curve == null:
		return

	var curve: Curve2D = path.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return

	if _cached_full_points.is_empty() or absf(_total_length - length) > 5.0:
		_rebuild_cache()

	if _cached_full_points.size() < 2:
		return

	# =========================================================================
	# 1. LAYER 1: Deep Trench Ambient Shadow (Gives 3D depth into ground)
	# =========================================================================
	var trench_shadow_col := Color(0.015, 0.045, 0.02, 0.70)
	draw_polyline(_cached_full_points, trench_shadow_col, trench_outer_width + 8.0, true)

	# =========================================================================
	# 2. LAYER 2: Earthen Berm / Outer Trench Embankment
	# =========================================================================
	var embankment_col := Color(0.065, 0.155, 0.085, 0.88)
	draw_polyline(_cached_full_points, embankment_col, trench_outer_width, true)

	# Soft lip highlight along upper rim.
	var rim_bevel_col := Color(0.12, 0.26, 0.15, 0.45)
	draw_polyline(_cached_full_points, rim_bevel_col, trench_outer_width - 4.0, true)

	# =========================================================================
	# 3. LAYER 3: Carved Trench Floor (Recessed bed where worms crawl)
	# =========================================================================
	var floor_col := Color(0.035, 0.085, 0.045, 0.98)
	draw_polyline(_cached_full_points, floor_col, trench_floor_width, true)

	# =========================================================================
	# 4. LAYER 4: Dual Inner Track Rails (Subtle stone / metallic guide rails)
	# =========================================================================
	if _cached_left_rail.size() >= 2 and _cached_right_rail.size() >= 2:
		var rail_col := Color(0.35, 0.52, 0.32, 0.28)
		draw_polyline(_cached_left_rail, rail_col, 1.8, true)
		draw_polyline(_cached_right_rail, rail_col, 1.8, true)

	# =========================================================================
	# 5. LAYER 5: Animated Directional Marching Pearls / Flow Energy
	# =========================================================================
	_draw_marching_pearls(curve, length)

	# =========================================================================
	# 6. LAYER 6: The Danger Zone (Molten alert trench leading to the pit)
	# =========================================================================
	_draw_danger_zone(curve, length)

	# =========================================================================
	# 7. LAYER 7: Start Landmark (Earthen Burrow / Entrance Tunnel)
	# =========================================================================
	_draw_start_burrow(curve)

	# =========================================================================
	# 8. LAYER 8: End Landmark (Farmyard Nest — protect it!)
	# =========================================================================
	_draw_nest(curve, length)


func _draw_marching_pearls(curve: Curve2D, length: float) -> void:
	var spacing: float = 44.0
	var flow_speed: float = 62.0
	var offset: float = fmod(_anim_time * flow_speed, spacing)

	var d: float = offset
	var danger_start: float = maxf(length - danger_zone_length, 0.0)

	while d < danger_start:
		var xf: Transform2D = curve.sample_baked_with_rotation(d, false)
		var pt: Vector2 = _path_to_local(xf.origin)
		var fwd: Vector2 = path.global_transform.basis_xform(xf.x).normalized()

		# Soft golden-cream flow dot with subtle pulse.
		var dot_pulse: float = sin(_anim_time * 3.0 + d * 0.05) * 0.2 + 0.8
		var alpha: float = 0.38 * dot_pulse
		var halo_color := Color(0.92, 0.96, 0.80, alpha * 0.4)
		var core_color := Color(1.0, 0.96, 0.85, alpha)

		# Outer glow halo.
		draw_circle(pt, 4.0, halo_color)
		# Inner core pearl.
		draw_circle(pt, 2.2, core_color)

		# Subtle directional arrow barb trailing behind pearl.
		var barb_back: Vector2 = pt - fwd * 3.5
		var barb_norm: Vector2 = Vector2(-fwd.y, fwd.x) * 2.2
		draw_line(barb_back - barb_norm, pt, core_color, 1.2, true)
		draw_line(barb_back + barb_norm, pt, core_color, 1.2, true)

		d += spacing


func _draw_danger_zone(curve: Curve2D, length: float) -> void:
	if _cached_danger_points.size() < 2:
		return

	# Base danger tint in the trench.
	var danger_base_alpha: float = 0.35 + _danger_urgency * 0.40 + _danger_pulse * _danger_urgency * 0.25
	var danger_col := Color(0.95, 0.22, 0.15, danger_base_alpha)

	# Wide glowing threat bed.
	if _danger_urgency > 0.15:
		var outer_glow := Color(1.0, 0.30, 0.10, danger_base_alpha * 0.45)
		draw_polyline(_cached_danger_points, outer_glow, trench_outer_width + 12.0 * _danger_urgency, true)

	# Deep crimson trench bed.
	draw_polyline(_cached_danger_points, danger_col, trench_floor_width + 2.0, true)

	# Animated chevron stripes across danger zone.
	var danger_start: float = maxf(length - danger_zone_length, 0.0)
	var stripe_spacing: float = 24.0
	var stripe_offset: float = fmod(_anim_time * 80.0, stripe_spacing)
	var sd: float = danger_start + stripe_offset

	while sd < length - 12.0:
		var xf: Transform2D = curve.sample_baked_with_rotation(sd, false)
		var center_pt: Vector2 = _path_to_local(xf.origin)
		var forward: Vector2 = path.global_transform.basis_xform(xf.x).normalized()
		var normal: Vector2 = Vector2(-forward.y, forward.x)

		var half_w: float = trench_floor_width * 0.45
		var p1: Vector2 = center_pt - normal * half_w - forward * 3.0
		var p2: Vector2 = center_pt + forward * 3.0
		var p3: Vector2 = center_pt + normal * half_w - forward * 3.0

		var stripe_col := Color(1.0, 0.85, 0.30, (0.45 + _danger_pulse * 0.4) * minf(1.0, _danger_urgency + 0.35))
		draw_line(p1, p2, stripe_col, 2.2, true)
		draw_line(p2, p3, stripe_col, 2.2, true)

		sd += stripe_spacing


func _draw_start_burrow(curve: Curve2D) -> void:
	var start_xf: Transform2D = curve.sample_baked_with_rotation(0.0, false)
	var pt: Vector2 = _path_to_local(start_xf.origin)

	# Outer dirt mound (earthen rim).
	draw_circle(pt, 24.0, Color(0.02, 0.06, 0.03, 0.60))
	draw_circle(pt, 20.0, Color(0.09, 0.20, 0.11, 0.90))
	draw_circle(pt, 16.5, Color(0.14, 0.30, 0.16, 0.95))

	# Wooden / stone portal ring.
	draw_circle(pt, 13.0, Color(0.24, 0.18, 0.12, 0.95))
	draw_circle(pt, 11.0, Color(0.38, 0.28, 0.18, 0.90))

	# Deep burrow void (black center).
	draw_circle(pt, 8.5, Color(0.02, 0.04, 0.02, 1.0))

	# Emerald emergence aura.
	var aura_pulse: float = sin(_anim_time * 3.5) * 0.25 + 0.75
	draw_circle(pt, 6.0, Color(0.25, 0.85, 0.42, 0.65 * aura_pulse))
	draw_circle(pt, 3.5, Color(0.55, 1.0, 0.68, 0.90 * aura_pulse))
	draw_circle(pt, 1.5, Color(0.95, 1.0, 0.95, 1.0))


func _draw_nest(curve: Curve2D, length: float) -> void:
	var end_xf: Transform2D = curve.sample_baked_with_rotation(length, false)
	var pt: Vector2 = _path_to_local(end_xf.origin)
	var urgency: float = _danger_urgency
	var pulse: float = _danger_pulse
	var breathe: float = 1.0 + sin(_anim_time * 2.2) * 0.02

	# Soft ground contact shadow.
	_fill_ellipse(pt + Vector2(2, 10), Vector2(34 * breathe, 14), Color(0, 0, 0, 0.38))

	# Danger aura when the chain nears.
	if urgency > 0.08:
		var flare_r: float = 42.0 + urgency * 14.0 + pulse * urgency * 8.0
		draw_circle(pt, flare_r, Color(1.0, 0.25, 0.08, 0.12 + urgency * 0.28 + pulse * 0.12))
		draw_circle(pt, flare_r * 0.72, Color(1.0, 0.45, 0.1, 0.1 + urgency * 0.2))

	# Outer woven straw bowl — layered ring strands.
	var outer_r: float = 30.0 * breathe
	_fill_ellipse(pt + Vector2(0, 3), Vector2(outer_r + 2, outer_r * 0.78), Color(0.28, 0.16, 0.06, 0.95))
	_fill_ellipse(pt + Vector2(0, 2), Vector2(outer_r, outer_r * 0.74), Color(0.42, 0.26, 0.10, 0.98))

	# Twig / straw fiber strokes around the rim.
	var fiber_cols: Array[Color] = [
		Color(0.55, 0.36, 0.14, 0.9),
		Color(0.72, 0.52, 0.22, 0.85),
		Color(0.38, 0.22, 0.08, 0.8),
		Color(0.82, 0.64, 0.28, 0.75),
	]
	for ring: int in range(3):
		var rr: float = (outer_r - 2.0) - float(ring) * 3.2
		var fibers: int = 18 + ring * 4
		for i: int in range(fibers):
			var a: float = float(i) / float(fibers) * TAU + float(ring) * 0.35 + _anim_time * 0.05
			var wobble: float = sin(a * 3.0 + float(ring)) * 2.2
			var p0: Vector2 = pt + Vector2(cos(a), sin(a) * 0.74) * (rr - 3.0 + wobble)
			var p1: Vector2 = pt + Vector2(cos(a + 0.18), sin(a + 0.18) * 0.74) * (rr + 1.5 + wobble * 0.5)
			draw_line(p0, p1, fiber_cols[(i + ring) % fiber_cols.size()], 1.6 + float(ring) * 0.3, true)

	# Inner soft nest bed (down / moss).
	_fill_ellipse(pt + Vector2(0, 1), Vector2(18.5, 14.0), Color(0.22, 0.28, 0.12, 0.95))
	_fill_ellipse(pt, Vector2(16.0, 12.0), Color(0.32, 0.40, 0.18, 0.92))
	_fill_ellipse(pt + Vector2(-1, -1), Vector2(12.0, 9.0), Color(0.45, 0.52, 0.28, 0.55))

	# Three eggs nestled in the center.
	_draw_egg(pt + Vector2(-6, 1), 5.2, 6.6, Color(0.96, 0.93, 0.82), urgency)
	_draw_egg(pt + Vector2(5.5, 2), 4.8, 6.1, Color(0.98, 0.95, 0.86), urgency)
	_draw_egg(pt + Vector2(0, -3.5), 5.5, 7.0, Color(1.0, 0.97, 0.88), urgency)

	# Soft feather tufts on the rim.
	for i: int in range(5):
		var a: float = -0.6 + float(i) * 0.45 + sin(_anim_time + float(i)) * 0.05
		var base: Vector2 = pt + Vector2(cos(a), sin(a) * 0.7) * 22.0
		var tip: Vector2 = base + Vector2(cos(a), sin(a) * 0.5) * 7.0 + Vector2(0, -3)
		draw_line(base, tip, Color(0.95, 0.9, 0.75, 0.55), 1.4, true)
		draw_circle(tip, 1.2, Color(0.98, 0.94, 0.82, 0.5))

	# Rim highlight (sun catching straw).
	draw_arc(pt + Vector2(0, -2), 26.0, -2.4, -0.6, 18, Color(0.95, 0.82, 0.45, 0.35), 2.0, true)

	# Threatened state: red stress cracks / heat under eggs.
	if urgency > 0.2:
		var heat: float = urgency * (0.45 + pulse * 0.4)
		draw_circle(pt, 10.0, Color(1.0, 0.3, 0.08, heat * 0.55))
		# Warning chevrons around nest.
		var chev_count: int = 8
		for i: int in range(chev_count):
			var ang: float = _anim_time * (1.5 + urgency) + float(i) * (TAU / float(chev_count))
			var outer_v := pt + Vector2.from_angle(ang) * (34.0 + pulse * 3.0)
			var side := Vector2.from_angle(ang + PI * 0.5) * 4.0
			var tip := pt + Vector2.from_angle(ang) * (28.0 + pulse * 2.0)
			draw_colored_polygon(
				PackedVector2Array([outer_v + side, tip, outer_v - side]),
				Color(1.0, 0.75, 0.2, 0.35 + pulse * 0.35)
			)


func _draw_egg(center: Vector2, rx: float, ry: float, col: Color, urgency: float) -> void:
	# Soft contact shadow under egg.
	_fill_ellipse(center + Vector2(1, ry * 0.55), Vector2(rx * 0.9, ry * 0.28), Color(0, 0, 0, 0.25))
	# Shell body
	_fill_ellipse(center, Vector2(rx, ry), col.darkened(0.08))
	_fill_ellipse(center + Vector2(-rx * 0.08, -ry * 0.08), Vector2(rx * 0.9, ry * 0.88), col)
	# Specular
	_fill_ellipse(center + Vector2(-rx * 0.28, -ry * 0.35), Vector2(rx * 0.28, ry * 0.22), Color(1, 1, 1, 0.45))
	# Speckle
	draw_circle(center + Vector2(rx * 0.25, ry * 0.1), 0.9, col.darkened(0.18))
	draw_circle(center + Vector2(-rx * 0.15, ry * 0.25), 0.7, col.darkened(0.15))
	# Crack when threatened
	if urgency > 0.55:
		var crack := Color(0.35, 0.12, 0.05, 0.55 + _danger_pulse * 0.3)
		draw_line(center + Vector2(-rx * 0.2, -ry * 0.4), center + Vector2(rx * 0.1, ry * 0.15), crack, 1.2, true)
		draw_line(center + Vector2(rx * 0.1, ry * 0.15), center + Vector2(rx * 0.35, -ry * 0.05), crack, 1.0, true)


func _fill_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(28):
		var a: float = float(i) / 28.0 * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _path_to_local(path_local_point: Vector2) -> Vector2:
	return to_local(path.to_global(path_local_point))
