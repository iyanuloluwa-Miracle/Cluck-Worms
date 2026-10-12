class_name ProgressionCatalog
extends Resource
## Master list of stages. Edit in the inspector or build via [method build_default].

@export var stages: Array[StageDef] = []


func get_stage_count() -> int:
	return stages.size()


func get_stage(index: int) -> StageDef:
	if index < 0 or index >= stages.size():
		return null
	return stages[index]


func find_stage_index(stage_id: StringName) -> int:
	for i: int in range(stages.size()):
		if stages[i].id == stage_id:
			return i
	return -1


## Ships a playable multi-stage catalog using the current Level scene.
## Swap scenes / tweak params per level as content lands.
static func build_default() -> ProgressionCatalog:
	var catalog := ProgressionCatalog.new()

	var stage1 := StageDef.new()
	stage1.id = &"stage_01"
	stage1.display_name = "Barnyard Beginnings"

	var s1_l1 := LevelDef.new()
	s1_l1.id = &"stage01_level01"
	s1_l1.display_name = "Warm-up Worms"
	s1_l1.initial_worm_count = 8
	s1_l1.march_speed = 48.0
	s1_l1.spawn_interval = 0.85

	var s1_l2 := LevelDef.new()
	s1_l2.id = &"stage01_level02"
	s1_l2.display_name = "Faster Feet"
	s1_l2.initial_worm_count = 12
	s1_l2.march_speed = 58.0
	s1_l2.spawn_interval = 0.70

	stage1.levels = [s1_l1, s1_l2] as Array[LevelDef]

	var stage2 := StageDef.new()
	stage2.id = &"stage_02"
	stage2.display_name = "Coop Chaos"

	var s2_l1 := LevelDef.new()
	s2_l1.id = &"stage02_level01"
	s2_l1.display_name = "Crowded Crawl"
	s2_l1.initial_worm_count = 14
	s2_l1.march_speed = 64.0
	s2_l1.spawn_interval = 0.62

	var s2_l2 := LevelDef.new()
	s2_l2.id = &"stage02_level02"
	s2_l2.display_name = "Final Flutter"
	s2_l2.initial_worm_count = 16
	s2_l2.march_speed = 72.0
	s2_l2.spawn_interval = 0.55

	stage2.levels = [s2_l1, s2_l2] as Array[LevelDef]

	catalog.stages = [stage1, stage2] as Array[StageDef]
	return catalog
