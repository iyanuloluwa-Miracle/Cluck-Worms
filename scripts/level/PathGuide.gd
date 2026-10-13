extends Node2D
## 10x Zuma-style carved physical track guide.
## Renders a multi-layered recessed trench carved into the terrain, dual guide rails,
## animated marching directional pearls, an earthen entry burrow, and a menacing hazard pit.

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
	# 8. LAYER 8: End Landmark (Menacing Hazard Pit / Abyss)
	# =========================================================================
	_draw_hazard_pit(curve, length)


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


func _draw_hazard_pit(curve: Curve2D, length: float) -> void:
	var end_xf: Transform2D = curve.sample_baked_with_rotation(length, false)
	var pt: Vector2 = _path_to_local(end_xf.origin)

	var urgency: float = _danger_urgency
	var pulse: float = _danger_pulse

	# Dynamic outer pulsing danger flare.
	var flare_radius: float = 28.0 + urgency * 8.0 + pulse * urgency * 4.0
	var flare_alpha: float = 0.28 + urgency * 0.40 + pulse * urgency * 0.30
	draw_circle(pt, flare_radius, Color(0.95, 0.15, 0.10, flare_alpha * 0.45))

	# Outer rugged crater ring.
	draw_circle(pt, 22.0 + urgency * 3.0, Color(0.04, 0.02, 0.02, 0.85))
	draw_circle(pt, 18.0, Color(0.18, 0.05, 0.05, 0.95))
	draw_circle(pt, 15.0, Color(0.85, 0.22, 0.12, 0.85 + pulse * 0.15))

	# Deep bottomless pit abyss.
	draw_circle(pt, 11.5, Color(0.03, 0.01, 0.01, 1.0))

	# Hazard teeth / spikes pointing inward.
	var spike_count: int = 6
	var rot_offset: float = _anim_time * (1.2 + urgency * 2.0)
	for i: int in range(spike_count):
		var ang: float = rot_offset + float(i) * (TAU / float(spike_count))
		var outer_v := pt + Vector2.from_angle(ang) * 14.0
		var inner_v := pt + Vector2.from_angle(ang) * 6.5
		var side_v1 := pt + Vector2.from_angle(ang - 0.26) * 13.0
		var side_v2 := pt + Vector2.from_angle(ang + 0.26) * 13.0
		draw_colored_polygon(PackedVector2Array([side_v1, inner_v, side_v2]), Color(1.0, 0.82, 0.35, 0.90))

	# Central vortex molten glow.
	draw_circle(pt, 5.5, Color(1.0, 0.32, 0.15, 0.95))
	draw_circle(pt, 2.5, Color(1.0, 0.92, 0.65, 1.0))

	# Danger crossbar indicator.
	var cross_len: float = 7.0 + urgency * 2.0
	var cross_col := Color(0.08, 0.02, 0.02, 0.90)
	draw_line(pt + Vector2(-cross_len, -cross_len), pt + Vector2(cross_len, cross_len), cross_col, 2.4, true)
	draw_line(pt + Vector2(cross_len, -cross_len), pt + Vector2(-cross_len, cross_len), cross_col, 2.4, true)


func _path_to_local(path_local_point: Vector2) -> Vector2:
	return to_local(path.to_global(path_local_point))
