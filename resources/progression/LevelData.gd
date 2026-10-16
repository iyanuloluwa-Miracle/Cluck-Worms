class_name LevelData
extends Resource
## Authoring unit for one playable level.
## Add a new level by creating a LevelData (code or .tres) and appending it
## to a StageDef in the campaign catalog — no scene edits required.

@export var id: StringName = &"level_01"
@export var display_name: String = "Level 1"
@export var scene_path: String = "res://scenes/level/Level.tscn"

## Global campaign index (1–N). Used for UI / debugging / unlocks.
@export var level_number: int = 1

@export_group("Boss")
## When set, this level is a stage boss encounter.
@export var boss: BossDef = null
@export var is_boss_level: bool = false

@export_group("Objective")
@export var objective: LevelObjective.Kind = LevelObjective.Kind.CLEAR_CHAIN
## Score goal for SCORE_TARGET levels.
@export var target_score: int = 0
## Survive duration (seconds) for SURVIVE_TIME levels.
@export var survive_seconds: float = 0.0
## Max shots for LIMITED_SHOTS levels (0 = unlimited).
@export var shot_limit: int = 0
## Required peak combo for COMBO_TARGET levels.
@export var target_combo: int = 0
## Short tip shown when the level starts.
@export var intro_tip: String = ""

@export_group("Modifiers")
## Multiplies march speed after base tuning (1 = unchanged).
@export_range(0.5, 2.0, 0.05) var speed_multiplier: float = 1.0
## Gradually increases march speed over the level.
@export var accelerating_chain: bool = false
## Caps available projectile / spawn colors (0 = use color_count).
@export_range(0, 6) var color_cap: int = 0
## Disables special worm spawns for this level.
@export var no_specials: bool = false
## Grants extra ability charges at level start.
@export var bonus_ability_charges: int = 0
## Restricts chicken loadout to fewer random colors mid-level feel.
@export var tight_palette: bool = false

@export_group("Path")
## Waypoints in playfield space (1280×720). Handles are auto-smoothed.
@export var path_points: PackedVector2Array = PackedVector2Array()
## 0 = polyline-ish, 1 = very round. Typical: 0.35–0.55.
@export_range(0.05, 1.0, 0.05) var path_smoothness: float = 0.42

@export_group("Difficulty")
## How many worm colors appear (3–6). More colors = harder matches.
@export_range(3, 6) var color_count: int = 4
@export var march_speed: float = 55.0
@export var spawn_interval: float = 0.72
@export var initial_worm_count: int = 10
## Total worms that will ever enter (initial + later spawns). Enables clearable levels.
@export var total_worms: int = 36
@export var worm_spacing: float = 40.0
@export var auto_spawn: bool = true

@export_group("Specials")
## Chance (0–1) that a rear spawn is a special worm (rainbow/bomb/slow/bonus).
@export_range(0.0, 0.35, 0.01) var special_spawn_chance: float = 0.0

@export_group("Presentation")
@export var chicken_position: Vector2 = Vector2(640, 400)
@export var background_color: Color = Color(0.12, 0.28, 0.16, 1)
@export var danger_zone_length: float = 120.0


func get_remaining_spawns_after_initial() -> int:
	return maxi(total_worms - initial_worm_count, 0)


func build_curve() -> Curve2D:
	var cleared: PackedVector2Array = PathFactory.ensure_chicken_clearance(
		path_points, chicken_position, PathFactory.NEST_CLEARANCE
	)
	# After nest push, pull any top-edge ribbon out from under the stone HUD bar.
	cleared = PathFactory.ensure_hud_clearance(cleared)
	cleared = PathFactory.ensure_chicken_clearance(
		cleared, chicken_position, PathFactory.NEST_CLEARANCE
	)
	return PathFactory.build_smooth_curve(cleared, path_smoothness)
