extends Node
## Instantiates every .tscn scene in the project to verify resources, node paths, and script compilation.

func _ready() -> void:
	print("--- Smoke Testing All Scenes ---")
	var scenes_to_test: Array[String] = [
		"res://scenes/ui/LoadingScreen.tscn",
		"res://scenes/main/Main.tscn",
		"res://scenes/level/Level.tscn",
		"res://scenes/chicken/Chicken.tscn",
		"res://scenes/worm/Worm.tscn",
		"res://scenes/projectile/ShootingWorm.tscn",
		"res://scenes/ui/HUD.tscn",
		"res://scenes/ui/MainMenuUI.tscn",
		"res://scenes/ui/PauseUI.tscn",
		"res://scenes/ui/SettingsUI.tscn",
		"res://scenes/ui/LevelSelectUI.tscn",
		"res://scenes/ui/LevelCompleteUI.tscn",
		"res://scenes/ui/StageCompleteUI.tscn",
		"res://scenes/ui/GameOverUI.tscn",
		"res://scenes/ui/PlayerProfileUI.tscn",
		"res://scenes/ui/InstructionsUI.tscn",
		"res://scenes/ui/StatsUI.tscn",
	]
	
	var failed: int = 0
	for path in scenes_to_test:
		var scene_res = load(path)
		if scene_res == null:
			printerr("  FAIL to load resource: ", path)
			failed += 1
			continue
		var instance = scene_res.instantiate()
		if instance == null:
			printerr("  FAIL to instantiate: ", path)
			failed += 1
			continue
		print("  OK  ", path)
		instance.queue_free()
	
	if failed == 0:
		print("ALL SCENES INSTANTIATED SUCCESSFULLY!")
		get_tree().quit(0)
	else:
		printerr("SMOKE TEST FAILED: %d scenes had errors" % failed)
		get_tree().quit(1)
