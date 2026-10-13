extends Node
## Automated test runner that executes inside the Godot project tree with full autoload support.

func _ready() -> void:
	print("--- Running Cluck & Worms Core Tests ---")
	var failed: int = 0
	failed += _expect(
		Scoring.match_points(3, 0, 1, false) == 300,
		"base 3-match = 300"
	)
	failed += _expect(
		Scoring.match_points(5, 0, 1, false) > Scoring.match_points(3, 0, 1, false),
		"larger match scores more"
	)
	failed += _expect(
		Scoring.match_points(3, 2, 1, false) > Scoring.match_points(3, 0, 1, false),
		"cascade depth adds score"
	)
	failed += _expect(
		Scoring.match_points(3, 0, 4, false) > Scoring.match_points(3, 0, 1, false),
		"combo multiplies score"
	)
	failed += _expect(
		Scoring.stars_for_level(5000, 40, 3, 2) == 3,
		"high score + lives earns 3 stars"
	)
	failed += _expect(
		Scoring.stars_for_level(100, 40, 1, 0) >= 1,
		"any clear earns at least 1 star"
	)

	var nest := PathFactory.CHICKEN_NEST
	var cleared := PathFactory.ensure_chicken_clearance(
		PackedVector2Array([nest, nest + Vector2(10, 0), nest + Vector2(300, 0)]),
		nest,
		PathFactory.NEST_CLEARANCE
	)
	failed += _expect(
		cleared[0].distance_to(nest) >= PathFactory.NEST_CLEARANCE - 0.1,
		"nest point pushed out"
	)
	failed += _expect(
		cleared[2].distance_to(nest) >= 299.0,
		"far point unchanged"
	)

	var catalog := ProgressionCatalog.build_campaign()
	failed += _expect(catalog.get_stage_count() == 4, "4 stages in campaign")
	failed += _expect(catalog.get_total_level_count() == 18, "18 campaign levels")

	if failed == 0:
		print("Cluck & Worms core tests: ALL PASSED")
		get_tree().quit(0)
	else:
		printerr("Cluck & Worms core tests: %d FAILED" % failed)
		get_tree().quit(1)


func _expect(ok: bool, label: String) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	printerr("  FAIL  ", label)
	return 1
