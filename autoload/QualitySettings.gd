extends Node
## Runtime quality profile. Scales juice + draw cost for web / mobile browsers.
## HIGH = desktop editor & native; MEDIUM = desktop browsers; LOW = phones.

enum Tier { HIGH, MEDIUM, LOW }

var tier: Tier = Tier.HIGH

## Multiplier applied to particle / burst intensity.
var particle_scale: float = 1.0
## Projectile trail sample count.
var trail_points: int = 12
## Allow Engine.time_scale hit-stop punches.
var enable_hit_stop: bool = true
## Spawn a mini pop for every matched worm (dense but expensive).
var enable_per_worm_pop: bool = true
## Camera trauma / shake.
var enable_camera_shake: bool = true
## Seconds between chicken body redraws (0 = every frame).
var chicken_redraw_interval: float = 0.0
## Path guide sampling step (larger = cheaper).
var path_sample_step: float = 6.0
## Soft cap on simultaneous FX children under Level/FX.
var max_live_fx: int = 28
## Float-text labels for small pops.
var enable_small_float_text: bool = true


func _ready() -> void:
	_detect_and_apply()


func is_web() -> bool:
	return OS.has_feature("web")


func is_low() -> bool:
	return tier == Tier.LOW


func _detect_and_apply() -> void:
	var web: bool = OS.has_feature("web")
	var mobile_os: bool = OS.has_feature("mobile")
	# Touch + web is the hot path (phones / tablets in browser).
	var touch_web: bool = web and DisplayServer.is_touchscreen_available()

	if touch_web or mobile_os:
		tier = Tier.LOW
	elif web:
		tier = Tier.MEDIUM
	else:
		tier = Tier.HIGH

	match tier:
		Tier.HIGH:
			particle_scale = 1.0
			trail_points = 12
			enable_hit_stop = true
			enable_per_worm_pop = true
			enable_camera_shake = true
			chicken_redraw_interval = 0.0
			path_sample_step = 6.0
			max_live_fx = 32
			enable_small_float_text = true
			Engine.max_fps = 0
		Tier.MEDIUM:
			particle_scale = 0.75
			trail_points = 8
			enable_hit_stop = true
			enable_per_worm_pop = false
			enable_camera_shake = true
			chicken_redraw_interval = 0.0
			path_sample_step = 8.0
			max_live_fx = 18
			enable_small_float_text = true
			Engine.max_fps = 60
		Tier.LOW:
			particle_scale = 0.5
			trail_points = 5
			enable_hit_stop = false
			enable_per_worm_pop = false
			enable_camera_shake = true
			chicken_redraw_interval = 1.0 / 30.0
			path_sample_step = 12.0
			max_live_fx = 10
			enable_small_float_text = false
			Engine.max_fps = 60
