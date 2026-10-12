class_name StageDef
extends Resource
## Ordered collection of levels that form one stage.

@export var id: StringName = &"stage_01"
@export var display_name: String = "Stage 1"
@export var levels: Array[LevelData] = []


func get_level_count() -> int:
	return levels.size()


func get_level(index: int) -> LevelData:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]
