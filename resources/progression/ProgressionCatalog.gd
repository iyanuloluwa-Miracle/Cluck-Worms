class_name ProgressionCatalog
extends Resource
## Master list of stages. Prefer [method build_campaign] for the full Zuma arc.

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


func get_total_level_count() -> int:
	var total: int = 0
	for stage: StageDef in stages:
		total += stage.get_level_count()
	return total


## Classic 3-stage / 12-level campaign with a fair difficulty ramp.
static func build_default() -> ProgressionCatalog:
	return build_campaign()


static func build_campaign() -> ProgressionCatalog:
	var catalog := ProgressionCatalog.new()

	var stage1 := StageDef.new()
	stage1.id = &"stage_01"
	stage1.display_name = "Farmyard Beginner"
	stage1.levels = [
		_level(1, &"s1_l1", "Meadow Lane", PathFactory.path_s1_l1_meadow_lane(),
			3, 42.0, 1.00, 6, 28, 42.0, 0.45, Color(0.14, 0.32, 0.18)),
		_level(2, &"s1_l2", "Barn Bend", PathFactory.path_s1_l2_barn_bend(),
			3, 48.0, 0.92, 8, 32, 41.0, 0.44, Color(0.15, 0.30, 0.16)),
		_level(3, &"s1_l3", "Coop Curl", PathFactory.path_s1_l3_coop_curl(),
			4, 52.0, 0.85, 10, 36, 40.0, 0.42, Color(0.13, 0.28, 0.17)),
		_level(4, &"s1_l4", "Hay Spiral", PathFactory.path_s1_l4_hay_spiral(),
			4, 56.0, 0.78, 12, 40, 40.0, 0.40, Color(0.16, 0.27, 0.14)),
	] as Array[LevelData]

	var stage2 := StageDef.new()
	stage2.id = &"stage_02"
	stage2.display_name = "Backyard Mayhem"
	stage2.levels = [
		_level(5, &"s2_l5", "Fence Zag", PathFactory.path_s2_l5_fence_zag(),
			4, 60.0, 0.72, 12, 44, 39.0, 0.40, Color(0.14, 0.26, 0.20)),
		_level(6, &"s2_l6", "Sprinkler Coil", PathFactory.path_s2_l6_sprinkler_coil(),
			5, 64.0, 0.68, 14, 48, 39.0, 0.38, Color(0.12, 0.24, 0.22)),
		_level(7, &"s2_l7", "Figure Eight", PathFactory.path_s2_l7_figure_eight(),
			5, 68.0, 0.64, 14, 52, 38.0, 0.38, Color(0.11, 0.22, 0.20)),
		_level(8, &"s2_l8", "Hedge Maze", PathFactory.path_s2_l8_hedge_maze(),
			5, 72.0, 0.60, 16, 56, 38.0, 0.36, Color(0.10, 0.22, 0.16)),
	] as Array[LevelData]

	var stage3 := StageDef.new()
	stage3.id = &"stage_03"
	stage3.display_name = "Chicken Apocalypse"
	stage3.levels = [
		_level(9, &"s3_l9", "Storm Coil", PathFactory.path_s3_l9_storm_coil(),
			6, 76.0, 0.56, 16, 60, 37.0, 0.36, Color(0.10, 0.18, 0.14)),
		_level(10, &"s3_l10", "Nested Ribbons", PathFactory.path_s3_l10_nested_ribbons(),
			6, 80.0, 0.52, 18, 64, 37.0, 0.34, Color(0.09, 0.16, 0.13)),
		_level(11, &"s3_l11", "Chaos Switch", PathFactory.path_s3_l11_chaos_switch(),
			6, 84.0, 0.50, 18, 68, 36.0, 0.34, Color(0.08, 0.14, 0.12)),
		_level(12, &"s3_l12", "Apocalypse Spiral", PathFactory.path_s3_l12_apocalypse_spiral(),
			6, 90.0, 0.46, 20, 72, 36.0, 0.32, Color(0.07, 0.12, 0.10)),
	] as Array[LevelData]

	catalog.stages = [stage1, stage2, stage3] as Array[StageDef]
	return catalog


static func _level(
	number: int,
	id: StringName,
	display_name: String,
	points: PackedVector2Array,
	colors: int,
	speed: float,
	interval: float,
	initial: int,
	total: int,
	spacing: float,
	smooth: float,
	bg: Color
) -> LevelData:
	var data := LevelData.new()
	data.id = id
	data.display_name = display_name
	data.level_number = number
	data.path_points = points
	data.path_smoothness = smooth
	data.color_count = colors
	data.march_speed = speed
	data.spawn_interval = interval
	data.initial_worm_count = initial
	data.total_worms = total
	data.worm_spacing = spacing
	data.auto_spawn = true
	data.background_color = bg
	data.danger_zone_length = lerpf(140.0, 100.0, float(number - 1) / 11.0)
	data.chicken_position = Vector2(640, 380)
	return data
