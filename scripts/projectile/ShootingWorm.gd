class_name ShootingWorm
extends Area2D
## Fast player projectile. Continuous segment tests prevent tunneling at high speed.
## Leaves a short motion trail for readability and punch.

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

## Flight speed in pixels per second.
@export var speed: float = 980.0

## Max lifetime before auto-despawn (seconds).
@export var max_lifetime: float = 2.5

## Collision radius used for chain worm hits.
@export var hit_radius: float = 16.0

## How far ahead of the sprite the hit probe sits (beak-lead feel).
@export var hit_lead: float = 4.0

## Trail point count (higher = longer ghost streak).
@export var trail_point_count: int = 8

## Seconds between trail samples.
@export var trail_sample_interval: float = 0.012

## Trail width at the head.
@export var trail_width: float = 14.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var worm_color: WormColor.Kind = WormColor.Kind.RED
var direction: Vector2 = Vector2.RIGHT
var is_alive: bool = true

var _lifetime: float = 0.0
var _prev_global: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0
var _trail_points: PackedVector2Array = PackedVector2Array()
var _chain: WormChain = null
var _owner_chicken: Chicken = null

@onready var _trail: Line2D = $Trail


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 0  # Manual tests against the chain — no physics-layer lag.
	_prev_global = global_position
	# Keep trail in world space so rotation doesn't corkscrew the streak.
	_trail.top_level = true
	_trail.global_rotation = 0.0
	_trail.clear_points()
	_trail.width = trail_width
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_apply_trail_gradient()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_lifetime += delta
	if _lifetime >= max_lifetime:
		_despawn()
		return

	_prev_global = global_position
	global_position += direction * speed * delta
	rotation = direction.angle()

	_update_trail(delta)
	_test_chain_collision()
	queue_redraw()


func _draw() -> void:
	# Local-space worm silhouette traveling nose-first (+X).
	var fill: Color = WormColor.get_fill(worm_color)
	var outline: Color = WormColor.get_outline(worm_color)
	var highlight: Color = WormColor.get_highlight(worm_color)

	draw_circle(Vector2(-10.0, 0.0), 7.0, outline)
	draw_circle(Vector2(8.0, 0.0), 11.0, outline)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-12.0, -6.0), Vector2(6.0, -9.0), Vector2(10.0, 0.0),
			Vector2(6.0, 9.0), Vector2(-12.0, 6.0),
		]),
		outline
	)

	draw_circle(Vector2(-10.0, 0.0), 5.5, fill)
	draw_circle(Vector2(8.0, 0.0), 9.5, fill)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-10.0, -4.5), Vector2(5.0, -7.0), Vector2(8.0, 0.0),
			Vector2(5.0, 7.0), Vector2(-10.0, 4.5),
		]),
		fill
	)
	draw_circle(Vector2(10.0, -3.0), 3.5, highlight)
	draw_circle(Vector2(11.0, -1.5), 2.2, Color.WHITE)
	draw_circle(Vector2(12.0, -1.5), 1.1, Color(0.1, 0.1, 0.1))


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func launch(
	color: WormColor.Kind,
	origin: Vector2,
	dir: Vector2,
	chain: WormChain,
	chicken: Chicken = null
) -> void:
	worm_color = color
	direction = dir.normalized()
	global_position = origin
	_prev_global = origin
	_chain = chain
	_owner_chicken = chicken
	is_alive = true
	_lifetime = 0.0
	rotation = direction.angle()
	_trail_points.clear()
	_apply_trail_gradient()
	queue_redraw()


# ---------------------------------------------------------------------------
# Collision
# ---------------------------------------------------------------------------

func _test_chain_collision() -> void:
	if _chain == null or not is_instance_valid(_chain):
		return

	var worms: Array[Worm] = _chain.get_worms()
	if worms.is_empty():
		return

	# Swept circle: segment from previous to current position vs each worm.
	var from: Vector2 = _prev_global
	var to: Vector2 = global_position + direction * hit_lead
	var hit_worm: Worm = null
	var hit_point: Vector2 = to
	var best_t: float = INF

	for worm: Worm in worms:
		if not is_instance_valid(worm):
			continue
		if not worm.is_active_in_chain() and worm.state != Worm.State.SPAWNING:
			continue
		var result: Dictionary = _segment_circle_hit(
			from, to, worm.global_position, hit_radius + Worm.HEAD_RADIUS * 0.85
		)
		if result.is_empty():
			continue
		var t: float = result["t"]
		if t < best_t:
			best_t = t
			hit_worm = worm
			hit_point = result["point"]

	if hit_worm == null:
		return

	_on_hit(hit_worm, hit_point)


func _segment_circle_hit(
	from: Vector2,
	to: Vector2,
	center: Vector2,
	radius: float
) -> Dictionary:
	## Returns {t, point} for the earliest intersection, or {} on miss.
	var ab: Vector2 = to - from
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.0001:
		if from.distance_squared_to(center) <= radius * radius:
			return {"t": 0.0, "point": from}
		return {}

	var ac: Vector2 = center - from
	var t: float = clampf(ac.dot(ab) / length_sq, 0.0, 1.0)
	var closest: Vector2 = from + ab * t
	if closest.distance_squared_to(center) <= radius * radius:
		return {"t": t, "point": closest}
	return {}


func _on_hit(hit_worm: Worm, hit_point: Vector2) -> void:
	if not is_alive:
		return
	is_alive = false

	EventBus.projectile_hit_chain.emit(self, hit_worm, _chain)
	if _chain != null and is_instance_valid(_chain):
		_chain.insert_from_projectile(hit_point, worm_color, hit_worm)

	_despawn()


func _despawn() -> void:
	is_alive = false
	queue_free()


# ---------------------------------------------------------------------------
# Trail
# ---------------------------------------------------------------------------

func _update_trail(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < trail_sample_interval:
		_sync_trail_line()
		return
	_trail_timer = 0.0
	_trail_points.insert(0, global_position)
	while _trail_points.size() > trail_point_count:
		_trail_points.remove_at(_trail_points.size() - 1)
	_sync_trail_line()


func _sync_trail_line() -> void:
	_trail.clear_points()
	_trail.global_position = Vector2.ZERO
	_trail.global_rotation = 0.0
	# World-space samples (trail is top_level).
	for i: int in range(_trail_points.size()):
		_trail.add_point(_trail_points[i])
	_trail.add_point(global_position)


func _apply_trail_gradient() -> void:
	var fill: Color = WormColor.get_fill(worm_color)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(fill.r, fill.g, fill.b, 0.55),
		Color(fill.r, fill.g, fill.b, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	_trail.gradient = gradient
	_trail.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_trail.width = trail_width
