class_name LevelDef
extends Resource
## Data for a single playable level within a stage.

@export var id: StringName = &"level_01"
@export var display_name: String = "Level 1"
@export var scene_path: String = "res://scenes/level/Level.tscn"

## Passed into the level instance after load (optional overrides).
@export var initial_worm_count: int = 10
@export var march_speed: float = 55.0
@export var spawn_interval: float = 0.72
@export var auto_spawn: bool = true
@export var worm_spacing: float = 40.0
