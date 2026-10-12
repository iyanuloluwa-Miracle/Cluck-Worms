class_name PopBurst
extends Node2D
## One-shot color pop: shards + sparkles for worm destruction.

const SHARD_COUNT: int = 14
const SPARK_COUNT: int = 8
const LIFETIME: float = 0.45

var _bits: Array[Dictionary] = []
var _age: float = 0.0
var _base_color: Color = Color.WHITE
var _intensity: float = 1.0


func setup(color: Color, intensity: float = 1.0) -> void:
	_base_color = color
	_intensity = clampf(intensity, 0.35, 2.5)
	var rng := GameManager.get_rng()
	var shard_budget: float = float(SHARD_COUNT) * _intensity
	if QualitySettings.is_low():
		shard_budget = minf(shard_budget, 8.0)
	elif QualitySettings.tier == QualitySettings.Tier.MEDIUM:
		shard_budget = minf(shard_budget, 12.0)
	var shards: int = maxi(int(round(shard_budget)), 4)
	for i: int in range(shards):
		var ang: float = rng.randf() * TAU
		var speed: float = rng.randf_range(120.0, 380.0) * _intensity
		_bits.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(ang) * speed,
			"radius": rng.randf_range(2.5, 6.5) * _intensity,
			"color": color.lightened(rng.randf_range(0.0, 0.35)),
			"spin": rng.randf_range(-10.0, 10.0),
			"rot": rng.randf() * TAU,
			"kind": 0,  # shard
		})
	var sparks: int = SPARK_COUNT if not QualitySettings.is_low() else 3
	for i: int in range(sparks):
		var ang2: float = rng.randf() * TAU
		_bits.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(ang2) * rng.randf_range(60.0, 200.0),
			"radius": rng.randf_range(1.2, 2.8),
			"color": Color(1, 1, 1, 1).lerp(color, 0.4),
			"spin": 0.0,
			"rot": 0.0,
			"kind": 1,  # spark
		})
	z_index = 40
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / LIFETIME
	if t >= 1.0:
		queue_free()
		return
	for bit: Dictionary in _bits:
		bit["vel"] = bit["vel"] * (1.0 - delta * 2.8) + Vector2(0, 420.0 * delta)
		bit["pos"] = bit["pos"] + bit["vel"] * delta
		bit["rot"] = float(bit["rot"]) + float(bit["spin"]) * delta
	modulate.a = 1.0 - t * t
	queue_redraw()


func _draw() -> void:
	# Core flash
	var flash_a: float = maxf(1.0 - _age * 8.0, 0.0)
	if flash_a > 0.0:
		draw_circle(Vector2.ZERO, 18.0 * _intensity * flash_a, Color(_base_color, flash_a * 0.55))
		draw_circle(Vector2.ZERO, 8.0 * _intensity, Color(1, 1, 1, flash_a * 0.8))

	for bit: Dictionary in _bits:
		var p: Vector2 = bit["pos"]
		var r: float = bit["radius"]
		var c: Color = bit["color"]
		if int(bit["kind"]) == 0:
			var rot: float = bit["rot"]
			var pts := PackedVector2Array([
				p + Vector2.from_angle(rot) * r,
				p + Vector2.from_angle(rot + 2.3) * r * 0.7,
				p + Vector2.from_angle(rot + 3.8) * r * 0.9,
			])
			draw_colored_polygon(pts, c)
		else:
			draw_circle(p, r, c)
