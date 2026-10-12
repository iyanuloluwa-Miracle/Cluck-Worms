extends Node2D
## Draws a subtle guide along the level Path2D so the chain route is readable.
## Also paints a danger tint near the path terminus.

@export var path: Path2D
@export var guide_color: Color = Color(1.0, 1.0, 1.0, 0.22)
@export var guide_width: float = 4.0
@export var dash_length: float = 18.0
@export var gap_length: float = 12.0
@export var danger_zone_length: float = 120.0
@export var danger_zone_color: Color = Color(1.0, 0.25, 0.2, 0.30)
@export var sample_step: float = 6.0


func _ready() -> void:
	if path == null:
		path = get_parent().get_node_or_null("WormPath") as Path2D
	sample_step = QualitySettings.path_sample_step
	queue_redraw()


func _draw() -> void:
	if path == null or path.curve == null:
		return

	var curve: Curve2D = path.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return

	# Danger zone (near end).
	var danger_start: float = maxf(length - danger_zone_length, 0.0)
	_draw_path_segment(curve, danger_start, length, danger_zone_color, guide_width + 6.0)

	# Full path: solid stroke on low quality, dashed otherwise.
	if QualitySettings.is_low():
		_draw_path_segment(curve, 0.0, length, guide_color, guide_width)
	else:
		var d: float = 0.0
		var drawing: bool = true
		while d < length:
			var seg: float = dash_length if drawing else gap_length
			var d1: float = minf(d + seg, length)
			if drawing:
				_draw_path_segment(curve, d, d1, guide_color, guide_width)
			d = d1
			drawing = not drawing

	# Start / end markers (convert path-local samples into this node's space).
	var start_xf: Transform2D = curve.sample_baked_with_rotation(0.0, false)
	var end_xf: Transform2D = curve.sample_baked_with_rotation(length, false)
	draw_circle(_path_to_local(start_xf.origin), 8.0, Color(0.3, 0.9, 0.4, 0.7))
	draw_circle(_path_to_local(end_xf.origin), 10.0, Color(0.95, 0.25, 0.2, 0.85))


func _path_to_local(path_local_point: Vector2) -> Vector2:
	return to_local(path.to_global(path_local_point))


func _draw_path_segment(
	curve: Curve2D,
	from_dist: float,
	to_dist: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	var d: float = from_dist
	while d <= to_dist:
		var xf: Transform2D = curve.sample_baked_with_rotation(d, false)
		points.append(_path_to_local(xf.origin))
		d += sample_step
	# Ensure final point.
	var end_xf: Transform2D = curve.sample_baked_with_rotation(to_dist, false)
	points.append(_path_to_local(end_xf.origin))
	if points.size() >= 2:
		draw_polyline(points, color, width, true)
