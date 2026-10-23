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


## Classic campaign — 3 stages × 5 levels (level 5 of each stage is a boss).
static func build_default() -> ProgressionCatalog:
	return build_campaign()


static func build_campaign() -> ProgressionCatalog:
	var catalog := ProgressionCatalog.new()

	# ------------------------------------------------------------------
	# Stage 1 — The Backyard (core tutorial ramp + Garden Guardian)
	# ------------------------------------------------------------------
	var stage1 := StageDef.new()
	stage1.id = &"stage_01"
	stage1.display_name = "The Backyard"
	stage1.levels = [
		_configure(_level(1, &"s1_l1", "Meadow Lane", PathFactory.path_s1_l1_meadow_lane(),
			3, 42.0, 1.00, 6, 28, 42.0, 0.45, Color(0.14, 0.32, 0.18)),
			LevelObjective.Kind.CLEAR_CHAIN, "Match 3+ worms — the chain reverses to close gaps!"),
		_configure(_level(2, &"s1_l2", "Barn Bend", PathFactory.path_s1_l2_barn_bend(),
			3, 48.0, 0.92, 8, 32, 41.0, 0.44, Color(0.15, 0.30, 0.16)),
			LevelObjective.Kind.CLEAR_CHAIN, "Swap with Right-click / Space. Try Q for Slow Pulse."),
		_configure(_level(3, &"s1_l3", "Coop Curl", PathFactory.path_s1_l3_coop_curl(),
			4, 52.0, 0.85, 10, 36, 40.0, 0.42, Color(0.13, 0.28, 0.17)),
			LevelObjective.Kind.CLEAR_CHAIN, "Clear every worm before the chain reaches the nest!",
			{"bonus_ability_charges": 1}),
		_configure(_level(4, &"s1_l4", "Hay Spiral", PathFactory.path_s1_l4_hay_spiral(),
			4, 56.0, 0.78, 12, 40, 40.0, 0.40, Color(0.16, 0.27, 0.14)),
			LevelObjective.Kind.COMBO_TARGET, "Build a 4× combo using cascades.",
			{"target_combo": 4}),
		_configure(_boss_level(5, &"s1_boss", "Garden Guardian", PathFactory.path_s1_l4_hay_spiral(),
			4, 58.0, 0.74, 14, 50, 39.0, 0.38, Color(0.12, 0.30, 0.14), BossDef.garden_guardian()),
			LevelObjective.Kind.DEFEAT_BOSS, "Match worms to hurt the Guardian — strike hard while it's dizzy after Root Surge!"),
	] as Array[LevelData]

	# ------------------------------------------------------------------
	# Stage 2 — The Wild Garden (specials + Worm Queen)
	# ------------------------------------------------------------------
	var stage2 := StageDef.new()
	stage2.id = &"stage_02"
	stage2.display_name = "The Wild Garden"
	stage2.levels = [
		_configure(_level(6, &"s2_l1", "Fence Zag", PathFactory.path_s2_l5_fence_zag(),
			4, 60.0, 0.72, 12, 44, 39.0, 0.40, Color(0.14, 0.26, 0.20)),
			LevelObjective.Kind.CLEAR_CHAIN, "Specials appear — Bombs clear neighbors!",
			{"accelerating_chain": true}),
		_configure(_level(7, &"s2_l2", "Sprinkler Coil", PathFactory.path_s2_l6_sprinkler_coil(),
			5, 64.0, 0.68, 14, 48, 39.0, 0.38, Color(0.12, 0.24, 0.22)),
			LevelObjective.Kind.SURVIVE_TIME, "Survive the sprinkler surge!",
			{"survive_seconds": 55.0, "speed_multiplier": 1.1}),
		_configure(_level(8, &"s2_l3", "Figure Eight", PathFactory.path_s2_l7_figure_eight(),
			5, 68.0, 0.64, 14, 52, 38.0, 0.38, Color(0.11, 0.22, 0.20)),
			LevelObjective.Kind.LIMITED_SHOTS, "Clear the chain with limited shots.",
			{"shot_limit": 28, "bonus_ability_charges": 1}),
		_configure(_level(9, &"s2_l4", "Hedge Maze", PathFactory.path_s2_l8_hedge_maze(),
			5, 72.0, 0.60, 16, 56, 38.0, 0.36, Color(0.10, 0.22, 0.16)),
			LevelObjective.Kind.SCORE_TARGET, "Big score under pressure.",
			{"target_score": 4500, "tight_palette": true}),
		_configure(_boss_level(10, &"s2_boss", "Worm Queen", PathFactory.path_s2_l8_hedge_maze(),
			5, 74.0, 0.56, 16, 62, 37.0, 0.34, Color(0.16, 0.12, 0.22), BossDef.worm_queen()),
			LevelObjective.Kind.DEFEAT_BOSS, "Match her crest color to shatter the shell, then pile on damage."),
	] as Array[LevelData]

	# ------------------------------------------------------------------
	# Stage 3 — The Forbidden Coop (expert + Golden Rooster)
	# ------------------------------------------------------------------
	var stage3 := StageDef.new()
	stage3.id = &"stage_03"
	stage3.display_name = "The Forbidden Coop"
	stage3.levels = [
		_configure(_level(11, &"s3_l1", "Storm Coil", PathFactory.path_s3_l9_storm_coil(),
			6, 76.0, 0.56, 16, 60, 37.0, 0.36, Color(0.10, 0.18, 0.14)),
			LevelObjective.Kind.CLEAR_CHAIN, "Six colors — plan your swaps.",
			{"accelerating_chain": true, "speed_multiplier": 1.05}),
		_configure(_level(12, &"s3_l2", "Nested Ribbons", PathFactory.path_s3_l10_nested_ribbons(),
			6, 80.0, 0.52, 18, 64, 37.0, 0.34, Color(0.09, 0.16, 0.13)),
			LevelObjective.Kind.COMBO_TARGET, "Reach a 6× combo.",
			{"target_combo": 6, "no_specials": false}),
		_configure(_level(13, &"s3_l3", "Chaos Switch", PathFactory.path_s3_l11_chaos_switch(),
			6, 84.0, 0.50, 18, 68, 36.0, 0.34, Color(0.08, 0.14, 0.12)),
			LevelObjective.Kind.LIMITED_SHOTS, "Precision under fire.",
			{"shot_limit": 34, "color_cap": 5}),
		_configure(_level(14, &"s3_l4", "Apocalypse Spiral", PathFactory.path_s3_l12_apocalypse_spiral(),
			6, 88.0, 0.46, 20, 72, 36.0, 0.32, Color(0.07, 0.12, 0.10)),
			LevelObjective.Kind.SCORE_TARGET, "Final score push before the Rooster.",
			{"target_score": 7000, "accelerating_chain": true}),
		_configure(_boss_level(15, &"s3_boss", "Golden Rooster", PathFactory.path_s3_l12_apocalypse_spiral(),
			6, 92.0, 0.42, 20, 78, 35.0, 0.30, Color(0.18, 0.10, 0.06), BossDef.golden_rooster()),
			LevelObjective.Kind.DEFEAT_BOSS, "Smash golden eggs before they hatch; strike when the Rooster tires."),
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
	data.danger_zone_length = lerpf(140.0, 100.0, float(number - 1) / 14.0)
	data.chicken_position = PathFactory.CHICKEN_NEST
	data.is_boss_level = false
	data.boss = null
	# Specials appear lightly from level 6 (Wild Garden), more often later.
	if number >= 6 and number < 11:
		data.special_spawn_chance = 0.06
	elif number >= 11:
		data.special_spawn_chance = 0.10
	else:
		data.special_spawn_chance = 0.0
	return data


static func _boss_level(
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
	bg: Color,
	boss: BossDef
) -> LevelData:
	var data := _level(
		number, id, display_name, points, colors, speed, interval,
		initial, total, spacing, smooth, bg
	)
	data.is_boss_level = true
	data.boss = boss
	if not boss.arena_path.is_empty():
		data.path_points = boss.arena_path
	data.chicken_position = boss.chicken_position
	data.objective = LevelObjective.Kind.DEFEAT_BOSS
	# Boss arenas lean on specials for readable damage windows.
	data.special_spawn_chance = maxf(data.special_spawn_chance, 0.08)
	return data


static func _configure(
	data: LevelData,
	objective: LevelObjective.Kind,
	tip: String = "",
	opts: Dictionary = {}
) -> LevelData:
	data.objective = objective
	data.intro_tip = tip
	if opts.has("target_score"):
		data.target_score = int(opts["target_score"])
	if opts.has("survive_seconds"):
		data.survive_seconds = float(opts["survive_seconds"])
	if opts.has("shot_limit"):
		data.shot_limit = int(opts["shot_limit"])
	if opts.has("target_combo"):
		data.target_combo = int(opts["target_combo"])
	if opts.has("speed_multiplier"):
		data.speed_multiplier = float(opts["speed_multiplier"])
	if opts.has("accelerating_chain"):
		data.accelerating_chain = bool(opts["accelerating_chain"])
	if opts.has("color_cap"):
		data.color_cap = int(opts["color_cap"])
	if opts.has("no_specials"):
		data.no_specials = bool(opts["no_specials"])
	if opts.has("bonus_ability_charges"):
		data.bonus_ability_charges = int(opts["bonus_ability_charges"])
	if opts.has("tight_palette"):
		data.tight_palette = bool(opts["tight_palette"])
	return data
